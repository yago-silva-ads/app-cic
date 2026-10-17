import 'package:supabase_flutter/supabase_flutter.dart';

import 'conta.dart';
import 'models.dart';
import '../core/semana_campo.dart';

/// Erro de negócio com mensagem pronta para o usuário.
class ErroCic implements Exception {
  ErroCic(this.mensagem, {this.codigo});
  final String mensagem;
  final String? codigo;
  @override
  String toString() => mensagem;
}

/// Acesso aos dados da loja logada.
///
/// Regras de segurança:
///  * Nenhum método envia `empresa_id`: a loja é sempre a do JWT (`auth.uid()`),
///    imposta pelo banco (RLS + triggers + funções SECURITY INVOKER).
///  * Toda mudança de saldo passa por função SQL que trava a linha. O app
///    nunca calcula nem grava "quantidade - vendidas" por conta própria.
///  * Falha de leitura NÃO vira lista vazia silenciosa: lança [ErroCic], para
///    a tela mostrar o erro em vez de exibir "estoque zerado".
class CicRepository {
  CicRepository([SupabaseClient? client]) : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  String get uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw ErroCic('Sessão expirada. Entre novamente.', codigo: 'SEM_SESSAO');
    return id;
  }

  Future<T> _guard<T>(Future<T> Function() f, {String contexto = 'a operação'}) async {
    try {
      return await f();
    } on PostgrestException catch (e) {
      throw _traduzir(e, contexto);
    } on AuthException catch (e) {
      throw ErroCic(e.message, codigo: 'AUTH');
    } on ErroCic {
      rethrow;
    } catch (e) {
      throw ErroCic('Não foi possível concluir $contexto. Verifique a conexão e tente de novo.');
    }
  }

  ErroCic _traduzir(PostgrestException e, String contexto) {
    final msg = e.message;
    String? parte(int i) {
      final p = msg.split(':');
      return p.length > i ? p[i].trim() : null;
    }

    if (msg.contains('ESTOQUE_INSUFICIENTE')) {
      return ErroCic(
        'Estoque insuficiente para o código ${parte(1)}: saldo atual ${parte(2)}.',
        codigo: 'ESTOQUE_INSUFICIENTE',
      );
    }
    if (msg.contains('PRODUTO_NAO_ENCONTRADO')) {
      return ErroCic('Produto ${parte(1)} não encontrado no seu estoque.', codigo: 'PRODUTO_NAO_ENCONTRADO');
    }
    if (msg.contains('ITENS_VAZIOS')) return ErroCic('Adicione ao menos um item.', codigo: 'ITENS_VAZIOS');
    if (msg.contains('ITEM_INVALIDO')) {
      return ErroCic('Dados inválidos no item ${parte(1) ?? ''}. Revise e tente de novo.', codigo: 'ITEM_INVALIDO');
    }
    if (msg.contains('SEM_SESSAO') || e.code == '42501' || e.code == 'PGRST301') {
      return ErroCic('Sessão expirada ou sem permissão. Entre novamente.', codigo: 'SEM_SESSAO');
    }
    if (e.code == '42883' || e.code == 'PGRST202') {
      return ErroCic(
        'O banco ainda não recebeu a atualização v3 (rode supabase/migracao_v3_estoque_atomico_e_isolamento.sql).',
        codigo: 'MIGRACAO_PENDENTE',
      );
    }
    if (e.code == '23503') {
      return ErroCic('Este produto tem vendas registradas e não pode ser apagado; ele será arquivado.', codigo: 'FK');
    }
    return ErroCic('Falha ao executar $contexto (${e.code ?? 'erro'}).');
  }

  // ===================== PRODUTOS =====================

  Future<List<Produto>> produtos({bool incluirArquivados = false}) => _guard(() async {
    final q = _db.from('produtos').select().eq('empresa_id', uid);
    final rows = await (incluirArquivados ? q : q.or('ativo.is.null,ativo.eq.true')).order('nome');
    return [for (final r in rows) Produto.fromJson(r)];
  }, contexto: 'carregar o estoque');

  /// Cria ou atualiza o produto DESTA loja. [somar] = true soma a quantidade ao
  /// saldo existente; false redefine o saldo para o valor informado.
  Future<int> salvarProduto(Produto p, {bool somar = true, String? documento, String? observacao}) => _guard(() async {
    final r = await _db.rpc('salvar_produto', params: {
      'p_produto': p.toRpc(documento: documento, observacao: observacao),
      'p_modo_quantidade': somar ? 'somar' : 'definir',
    });
    return (r['quantidade'] as num).toInt();
  }, contexto: 'salvar o produto');

  /// Apaga o produto; se houver vendas ligadas a ele, arquiva (some do estoque
  /// mas o histórico e a Curva ABC continuam corretos).
  Future<bool> removerOuArquivarProduto(String codigo) => _guard(() async {
    try {
      await _db.from('produtos').delete().eq('empresa_id', uid).eq('codigo', codigo);
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        await _db.from('produtos').update({'ativo': false}).eq('empresa_id', uid).eq('codigo', codigo);
        return false;
      }
      rethrow;
    }
  }, contexto: 'remover o produto');

  Future<int> ajustarEstoque({
    required String codigo,
    required int delta,
    required String motivo,
    String? documento,
    String? observacao,
    double? valorUnitario,
  }) => _guard(() async {
    final r = await _db.rpc('ajustar_estoque', params: {
      'p_codigo': codigo,
      'p_delta': delta,
      'p_motivo': motivo,
      'p_documento': documento,
      'p_observacao': observacao,
      'p_valor_unitario': valorUnitario,
    });
    return (r as num).toInt();
  }, contexto: 'ajustar o estoque');

  /// Quais destes documentos (ex.: itens de NF-e) já têm movimentação.
  /// Evita dar entrada duas vezes na mesma nota.
  Future<Set<String>> documentosJaLancados(List<String> documentos) => _guard(() async {
    if (documentos.isEmpty) return <String>{};
    final rows = await _db
        .from('movimentacoes_estoque')
        .select('documento')
        .eq('empresa_id', uid)
        .inFilter('documento', documentos);
    return {for (final r in rows) '${r['documento']}'};
  }, contexto: 'conferir notas já importadas');

  // ===================== VENDAS =====================

  /// Venda atômica: baixa de estoque + histórico + movimentação na mesma
  /// transação. Retorna o id da venda.
  Future<String> registrarVenda({
    required List<ItemCarrinho> itens,
    required String formaPagamento,
    String? operador,
    double descontoPct = 0,
  }) => _guard(() async {
    final r = await _db.rpc('registrar_venda', params: {
      'p_itens': [
        for (final i in itens)
          {
            'codigo': i.produto.codigo,
            'quantidade': i.quantidade,
            'valor_unitario': i.produto.valorVenda,
          },
      ],
      'p_forma_pagamento': formaPagamento,
      'p_operador': operador,
      'p_desconto_pct': descontoPct,
    });
    return '${r['venda_id']}';
  }, contexto: 'registrar a venda');

  Future<List<VendaItemHistorico>> vendas({DateTime? desde}) => _guard(() async {
    var q = _db.from('historico_vendas').select().eq('empresa_id', uid);
    if (desde != null) q = q.gte('data_venda', desde.toUtc().toIso8601String());
    final rows = await q.order('data_venda', ascending: false).limit(5000);
    return [for (final r in rows) VendaItemHistorico.fromJson(r)];
  }, contexto: 'carregar as vendas');

  // ===================== MOVIMENTAÇÕES =====================

  Future<List<Movimentacao>> movimentacoes({int limite = 500}) => _guard(() async {
    final rows = await _db
        .from('movimentacoes_estoque')
        .select()
        .eq('empresa_id', uid)
        .order('criado_em', ascending: false)
        .limit(limite);
    return [for (final r in rows) Movimentacao.fromJson(r)];
  }, contexto: 'carregar as movimentações');

  // ===================== CUSTOS =====================

  Future<List<CustoOperacional>> custos() => _guard(() async {
    final rows = await _db.from('custos_operacionais').select().eq('empresa_id', uid).order('nome');
    return [for (final r in rows) CustoOperacional.fromJson(r)];
  }, contexto: 'carregar os custos');

  Future<void> salvarCusto(CustoOperacional c) => _guard(() async {
    final dados = <String, dynamic>{
      'nome': c.nome,
      'valor': c.valor,
      'tipo': c.tipo == TipoCusto.fixo ? 'FIXO' : 'VARIAVEL',
      'categoria': c.categoria,
      'observacao': c.observacao,
    };
    if (c.id == null) {
      await _db.from('custos_operacionais').insert(dados);
    } else {
      await _db.from('custos_operacionais').update(dados).eq('id', c.id!).eq('empresa_id', uid);
    }
  }, contexto: 'salvar o custo');

  Future<void> removerCusto(String id) => _guard(() async {
    await _db.from('custos_operacionais').delete().eq('id', id).eq('empresa_id', uid);
  }, contexto: 'remover o custo');

  // ===================== ALERTAS (gerados pelos triggers do banco) =====================

  Future<List<Alerta>> alertas() => _guard(() async {
    final rows = await _db
        .from('alertas_sistema')
        .select()
        .eq('empresa_id', uid)
        .order('criado_em', ascending: false)
        .limit(300);
    return [for (final r in rows) Alerta.fromJson(r)];
  }, contexto: 'carregar os alertas');

  Future<void> marcarAlertaLido(int id) => _guard(() async {
    await _db.from('alertas_sistema').update({'lido': true}).eq('id', id).eq('empresa_id', uid);
  }, contexto: 'marcar o alerta');

  Future<void> marcarTodosAlertasLidos() => _guard(() async {
    await _db.from('alertas_sistema').update({'lido': true}).eq('empresa_id', uid).eq('lido', false);
  }, contexto: 'marcar os alertas');

  // ===================== RELATÓRIOS IA =====================

  Future<void> salvarRelatorioIa({
    required String conteudo,
    String tipo = 'SOB_DEMANDA',
    Map<String, dynamic>? metricas,
  }) => _guard(() async {
    await _db.from('relatorios_ia').insert({
      'tipo': tipo,
      'conteudo_markdown': conteudo,
      'metricas': metricas,
    });
  }, contexto: 'salvar o relatório');

  Future<List<Map<String, dynamic>>> relatoriosIa({int limite = 20}) => _guard(() async {
    final rows = await _db
        .from('relatorios_ia')
        .select()
        .eq('empresa_id', uid)
        .order('criado_em', ascending: false)
        .limit(limite);
    return List<Map<String, dynamic>>.from(rows);
  }, contexto: 'carregar os relatórios');

  Future<void> excluirRelatorioIa(int id) => _guard(() async {
    await _db.from('relatorios_ia').delete().eq('id', id).eq('empresa_id', uid);
  }, contexto: 'excluir o relatório');

  Future<Map<String, dynamic>> registrarLogisticaReversa({
    required String codigo,
    required int quantidade,
    required String motivo,
    required String destino,
    String? documento,
    String? observacao,
  }) => _guard(() async {
    final r = await _db.rpc('registrar_logistica_reversa', params: {
      'p_codigo': codigo,
      'p_quantidade': quantidade,
      'p_motivo': motivo,
      'p_destino': destino,
      'p_documento': documento,
      'p_observacao': observacao,
    });
    return Map<String, dynamic>.from(r as Map);
  }, contexto: 'registrar a logística reversa');

  // ===================== TESTE DE CAMPO =====================

  Future<void> salvarFeedbackCampo({
    required int nota,
    required List<String> aspectos,
    required String comentario,
    required bool recomendaria,
    String interesseSite = 'nao_agora',
  }) => _guard(() async {
    await _db.from('feedback_campo').insert({
      'semana_inicio': _inicioSemana().toIso8601String().split('T').first,
      'nota': nota.clamp(1, 5),
      'aspectos': aspectos,
      'comentario': comentario.trim(),
      'recomendaria': recomendaria,
      'interesse_site': interesseSite,
    });
  }, contexto: 'enviar o feedback');

  Future<bool> enviouFeedbackNestaSemana() => _guard(() async {
    final r = await _db.from('feedback_campo').select('id')
        .eq('empresa_id', uid)
        .eq('semana_inicio', _inicioSemana().toIso8601String().split('T').first)
        .limit(1);
    return r.isNotEmpty;
  }, contexto: 'verificar o feedback semanal');

  DateTime _inicioSemana() {
    return inicioSemanaCampo(DateTime.now());
  }

  // ===================== CONTA DO ESTABELECIMENTO =====================

  // Documento, telefone, e-mail, Pix e dados bancários ficam cifrados no banco
  // (supabase/criptografia_conta.sql); as RPCs decifram só para a própria loja.
  // Enquanto a migration não estiver aplicada (PGRST202), usa a tabela direto.
  Future<Map<String, dynamic>> conta() => _guard(() async {
    try {
      final r = await _db.rpc('minha_conta');
      return Map<String, dynamic>.from((r as Map?) ?? const {});
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;
      final r = await _db.from('contas_estabelecimento').select('dados').eq('empresa_id', uid).maybeSingle();
      return Map<String, dynamic>.from((r?['dados'] as Map?) ?? const {});
    }
  }, contexto: 'carregar a conta');

  Future<void> salvarConta(Map<String, dynamic> dados) => _guard(() async {
    try {
      await _db.rpc('salvar_minha_conta', params: {'p_dados': dados});
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;
      await _db.from('contas_estabelecimento').upsert({
        'empresa_id': uid,
        'dados': dados,
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'empresa_id');
    }
  }, contexto: 'salvar a conta');

  // ===================== CAIXA (turno) =====================

  /// Turno aberto da loja; abre um novo se não houver.
  Future<SessaoCaixa> sessaoCaixaAtual(ContaEstabelecimento conta) => _guard(() async {
    final r = await _db
        .from('sessoes_caixa')
        .select()
        .eq('empresa_id', uid)
        .eq('status', 'ABERTO')
        .order('aberta_em', ascending: false)
        .limit(1)
        .maybeSingle();
    if (r != null) return SessaoCaixa.fromRow(r);
    return _abrirSessao(conta.operador, conta.fundoTrocoPadrao);
  }, contexto: 'abrir o caixa');

  Future<SessaoCaixa> abrirNovaSessaoCaixa(String operador, double fundoTroco) =>
      _guard(() => _abrirSessao(operador, fundoTroco), contexto: 'abrir o caixa');

  Future<SessaoCaixa> _abrirSessao(String operador, double fundo) async {
    final dados = SessaoCaixa(id: '', abertaEm: DateTime.now(), operador: operador, fundoTroco: fundo).dadosJson();
    final r = await _db.from('sessoes_caixa').insert({'dados': dados, 'status': 'ABERTO'}).select().single();
    return SessaoCaixa.fromRow(r);
  }

  /// Registra sangria/reforço relendo o turno antes (evita sobrescrever o que
  /// outro aparelho gravou no meio tempo).
  Future<SessaoCaixa> registrarMovimentoCaixa(String sessaoId, MovimentoCaixa mov) => _guard(() async {
    final r = await _db.from('sessoes_caixa').select().eq('id', sessaoId).eq('empresa_id', uid).single();
    final atual = SessaoCaixa.fromRow(r);
    if (atual.fechada) throw ErroCic('Este turno já foi fechado.');
    final dados = atual.dadosJson();
    (dados['movimentacoes'] as List).insert(0, mov.toJson());
    final novo = await _db
        .from('sessoes_caixa')
        .update({'dados': dados})
        .eq('id', sessaoId)
        .eq('empresa_id', uid)
        .select()
        .single();
    return SessaoCaixa.fromRow(novo);
  }, contexto: 'registrar a movimentação do caixa');

  Future<void> fecharSessaoCaixa(String sessaoId) => _guard(() async {
    await _db
        .from('sessoes_caixa')
        .update({'status': 'FECHADO', 'fechada_em': DateTime.now().toUtc().toIso8601String()})
        .eq('id', sessaoId)
        .eq('empresa_id', uid);
  }, contexto: 'fechar o caixa');

  Future<ContaEstabelecimento> contaEstabelecimento({String nomeLojaPadrao = ''}) async {
    final j = await conta();
    return ContaEstabelecimento.fromJson(j, nomeLojaPadrao: nomeLojaPadrao);
  }
}
