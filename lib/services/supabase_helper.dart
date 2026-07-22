import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/produto.dart';
import '../models/custo_operacional.dart';
import '../models/alerta.dart';
import '../models/aquisicao.dart';

class SupabaseHelper {
  static final supabase = Supabase.instance.client;

  /// 🔒 Retorna o ID do usuário logado (usado como empresa_id para multi-tenant)
  static String get _empresaId => supabase.auth.currentUser!.id;

  // Buscar todo o estoque da nuvem
  static Future<List<Produto>> getEstoque() async {
    try {
      final response = await supabase.from('produtos').select().eq('empresa_id', _empresaId);
      print("Produtos encontrados: ${response.length}"); // DEBUG

      // Mapear o JSON do Supabase para a sua classe Produto
      return (response as List)
          .map(
            (json) => Produto(
              codigo: json['codigo'],
              nome: json['nome'],
              lote: json['lote'] ?? '',
              quantidade: json['quantidade'],
              valorCompra: (json['valor_compra'] as num).toDouble(),
              markup: (json['markup'] as num).toDouble(),
              valorVenda: (json['valor_venda'] as num).toDouble(),
              // AS TRÊS LINHAS NOVAS AQUI:
              origem: json['origem'] ?? 'Revendido',
              dataEntrada: json['data_entrada'] != null
                  ? DateTime.tryParse(json['data_entrada'])
                  : null,
              dataValidade: json['data_validade'] != null
                  ? DateTime.tryParse(json['data_validade'])
                  : null,
              vendidas: json['vendidas'] ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      print("Erro ao buscar estoque: $e");
      return [];
    }
  }

  // Inserir ou Atualizar Produto (Upsert) — 🔒 injeta empresa_id automaticamente
  static Future<void> insertProduto(Produto p) async {
    await supabase.from('produtos').upsert({
      'codigo': p.codigo,
      'nome': p.nome,
      'lote': p.lote,
      'quantidade': p.quantidade,
      'valor_compra': p.valorCompra,
      'markup': p.markup,
      'valor_venda': p.valorVenda,
      'origem': p.origem,
      'data_entrada': p.dataEntrada?.toIso8601String().split('T')[0],
      'data_validade': p.dataValidade?.toIso8601String().split('T')[0],
      'vendidas': p.vendidas,

      'empresa_id': _empresaId, // 🔒 Multi-tenant
    }, onConflict: 'codigo');
  }

  // Registrar uma venda no histórico — 🔒 injeta empresa_id automaticamente
  static Future<void> registrarVenda(
    String codigoProduto,
    int qtdVendida,
    double valorUnid,
  ) async {
    await supabase.from('historico_vendas').insert({
      'produto_codigo': codigoProduto,
      'quantidade_vendida': qtdVendida,
      'valor_unitario': valorUnid,
      'empresa_id': _empresaId, // 🔒 Multi-tenant
    });
  }

  // Recuperar Histórico de Vendas para o DashBoard
  static Future<List<Map<String, dynamic>>> getHistoricoVendas() async {
    try {
      final response = await supabase
          .from('historico_vendas')
          .select()
          .eq('empresa_id', _empresaId)
          .order('data_venda', ascending: true);
      print("Vendas encontradas: ${response.length}"); // DEBUG
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Erro ao buscar vendas: $e");
      return [];
    }
  }

  /// 📦 Registrar uma nova aquisição e atualizar o custo médio ponderado do produto
  static Future<double> registrarAquisicao(Aquisicao aquisicao, {required Produto produto}) async {
    try {
      final jsonAquisicao = aquisicao.toJson();
      jsonAquisicao['empresa_id'] = _empresaId;
      await supabase.from('historico_aquisicoes').insert(jsonAquisicao);

      // Buscar histórico completo para recálculo do custo médio
      final historico = await getHistoricoAquisicoes(aquisicao.produtoCodigo);
      double novoCustoMedio = aquisicao.valorUnitario;
      if (historico.isNotEmpty) {
        novoCustoMedio = Produto.calcularCustoMedioPonderado(historico);
      }

      // Atualizar quantidade total e valor de compra do produto
      int novaQtd = produto.quantidade + aquisicao.quantidade;
      double novoValorVenda = produto.valorVenda;
      if (produto.markup > 0) {
        novoValorVenda = novoCustoMedio * produto.markup;
      }

      await supabase.from('produtos').update({
        'quantidade': novaQtd,
        'valor_compra': novoCustoMedio,
        'valor_venda': novoValorVenda,
      }).eq('codigo', aquisicao.produtoCodigo).eq('empresa_id', _empresaId);

      return novoCustoMedio;
    } catch (e) {
      print("Erro ao registrar aquisição no Supabase: $e");
      rethrow;
    }
  }

  /// 📜 Buscar histórico de aquisições de um produto específico
  static Future<List<Aquisicao>> getHistoricoAquisicoes(String produtoCodigo) async {
    try {
      final response = await supabase
          .from('historico_aquisicoes')
          .select()
          .eq('empresa_id', _empresaId)
          .eq('produto_codigo', produtoCodigo)
          .order('data_aquisicao', ascending: false);

      return (response as List).map((json) => Aquisicao.fromJson(json)).toList();
    } catch (e) {
      print("Erro ao buscar histórico de aquisições: $e");
      return [];
    }
  }

  static Future<void> deleteProduto(String codigo) async {
    await supabase.from('produtos').delete().eq('codigo', codigo).eq('empresa_id', _empresaId);
  }

  // Buscar custos operacionais do Supabase (Multi-tenant via RLS)
  static Future<List<CustoOperacional>> getCustosOperacionais() async {
    try {
      final response = await supabase
          .from('custos_operacionais')
          .select()
          .eq('empresa_id', _empresaId)
          .order('id', ascending: true);
      print("Custos operacionais encontrados: ${response.length}"); // DEBUG
      return (response as List)
          .map((json) => CustoOperacional.fromJson(json))
          .toList();
    } catch (e) {
      print("Erro ao buscar custos operacionais do Supabase: $e");
      return [];
    }
  }

  // Substituir/salvar custos operacionais no Supabase (Multi-tenant via RLS)
  static Future<void> replaceCustosOperacionais(
    List<CustoOperacional> custos,
  ) async {
    // 1. Identificar IDs que ainda existem na nova lista
    final idsExistentes = custos
        .where((c) => c.id != null)
        .map((c) => c.id!)
        .toList();

    // 2. Apagar do banco os custos desta empresa que foram removidos pelo usuário na tela
    if (idsExistentes.isNotEmpty) {
      // UUIDs precisam de aspas no filtro not.in do PostgREST
      final idsFormatados = idsExistentes.map((id) => '"$id"').join(',');
      await supabase
          .from('custos_operacionais')
          .delete()
          .eq('empresa_id', _empresaId)
          .filter('id', 'not.in', '($idsFormatados)');
    } else {
      // Se nenhum item da lista possui ID antigo, limpa todos os custos anteriores desta empresa
      await supabase.from('custos_operacionais').delete().eq('empresa_id', _empresaId);
    }

    // 3. Separar itens para ATUALIZAR vs itens para INSERIR
    final paraAtualizar = custos.where((c) => c.id != null).toList();
    final paraInserir = custos.where((c) => c.id == null).toList();

    if (paraAtualizar.isNotEmpty) {
      final dataUpdate = paraAtualizar.map((c) => <String, dynamic>{
        'id': c.id,
        'nome': c.nome,
        'valor': c.valor,
        'empresa_id': _empresaId, // 🔒 Multi-tenant
      }).toList();
      await supabase.from('custos_operacionais').upsert(dataUpdate);
    }

    if (paraInserir.isNotEmpty) {
      final dataInsert = paraInserir.map((c) => <String, dynamic>{
        'nome': c.nome,
        'valor': c.valor,
        'empresa_id': _empresaId, // 🔒 Multi-tenant
      }).toList();
      await supabase.from('custos_operacionais').insert(dataInsert);
    }
  }


  // ==================== ALERTAS ====================

  /// 🔔 Buscar todos os alertas não lidos do tenant (ordenados por severidade)
  static Future<List<Alerta>> getAlertas({bool apenasNaoLidos = true}) async {
    try {
      var query = supabase
          .from('alertas_sistema')
          .select()
          .eq('empresa_id', _empresaId);
      if (apenasNaoLidos) {
        query = query.eq('lido', false);
      }
      final response = await query.order('criado_em', ascending: false);
      print("Alertas encontrados: ${response.length}"); // DEBUG
      return (response as List)
          .map((json) => Alerta.fromJson(json))
          .toList();
    } catch (e) {
      print("Erro ao buscar alertas: $e");
      return [];
    }
  }

  /// 🚨 Buscar apenas alertas urgentes (CRITICO + ALTO) — para pop-up automático
  static Future<List<Alerta>> getAlertasUrgentes() async {
    try {
      final response = await supabase
          .from('alertas_sistema')
          .select()
          .eq('empresa_id', _empresaId)
          .eq('lido', false)
          .inFilter('severidade', ['CRITICO', 'ALTO'])
          .order('criado_em', ascending: false);
      return (response as List)
          .map((json) => Alerta.fromJson(json))
          .toList();
    } catch (e) {
      print("Erro ao buscar alertas urgentes: $e");
      return [];
    }
  }

  /// 🔢 Contar alertas não lidos (para badge de notificação)
  static Future<int> contarAlertasNaoLidos() async {
    try {
      final response = await supabase
          .from('alertas_sistema')
          .select('id')
          .eq('empresa_id', _empresaId)
          .eq('lido', false);
      return (response as List).length;
    } catch (e) {
      print("Erro ao contar alertas: $e");
      return 0;
    }
  }

  /// ✅ Marcar alerta individual como lido
  static Future<void> marcarAlertaLido(int alertaId) async {
    await supabase
        .from('alertas_sistema')
        .update({'lido': true})
        .eq('id', alertaId)
        .eq('empresa_id', _empresaId);
  }

  /// ✅ Marcar TODOS os alertas como lidos
  static Future<void> marcarTodosAlertasLidos() async {
    await supabase
        .from('alertas_sistema')
        .update({'lido': true})
        .eq('empresa_id', _empresaId)
        .eq('lido', false);
  }

  // ==================== KPIs (DASHBOARD) ====================

  /// 📊 Buscar KPIs de vendas do mês corrente (view materializada)
  static Future<Map<String, dynamic>> getKpisVendasMes() async {
    try {
      final response = await supabase
          .from('vw_kpis_vendas_mes')
          .select()
          .eq('empresa_id', _empresaId)
          .maybeSingle();
      if (response != null) {
        return response;
      }
      return {
        'total_vendas': 0,
        'receita_total': 0.0,
        'ticket_medio': 0.0,
        'lucro_bruto': 0.0,
        'unidades_vendidas': 0,
      };
    } catch (e) {
      print("Erro ao buscar KPIs: $e");
      return {
        'total_vendas': 0,
        'receita_total': 0.0,
        'ticket_medio': 0.0,
        'lucro_bruto': 0.0,
        'unidades_vendidas': 0,
      };
    }
  }

  /// 📈 Buscar faturamento mensal (últimos 12 meses — para gráfico de linha)
  static Future<List<Map<String, dynamic>>> getFaturamentoMensal() async {
    try {
      final response = await supabase
          .from('vw_faturamento_mensal')
          .select()
          .eq('empresa_id', _empresaId)
          .order('mes', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Erro ao buscar faturamento mensal: $e");
      return [];
    }
  }

  /// 🏆 Buscar top 10 produtos mais vendidos no mês
  static Future<List<Map<String, dynamic>>> getTopProdutosMes() async {
    try {
      final response = await supabase
          .from('vw_top_produtos_mes')
          .select()
          .eq('empresa_id', _empresaId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Erro ao buscar top produtos: $e");
      return [];
    }
  }

  // ==================== RELATÓRIOS IA ====================

  /// 🤖 Salvar relatório gerado pela IA no banco
  static Future<void> salvarRelatorioIA({
    required String conteudo,
    String tipo = 'SOB_DEMANDA',
    Map<String, dynamic>? metricas,
  }) async {
    await supabase.from('relatorios_ia').insert({
      'tipo': tipo,
      'conteudo_markdown': conteudo,
      'metricas': metricas,
      'empresa_id': _empresaId,
    });
  }

  /// 📋 Buscar relatórios IA (mais recentes primeiro)
  static Future<List<Map<String, dynamic>>> getRelatoriosIA({int limite = 10}) async {
    try {
      final response = await supabase
          .from('relatorios_ia')
          .select()
          .order('criado_em', ascending: false)
          .limit(limite);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Erro ao buscar relatórios IA: $e");
      return [];
    }
  }

  /// 🔒 Logout: desconecta do Supabase e limpa dados locais do aparelho
  /// Isso impede que o próximo usuário veja custos/dados do anterior.
  static Future<void> signOut() async {
    // 1. Limpa todos os dados locais (SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 2. Desconecta do Supabase Auth (invalida o JWT local)
    await supabase.auth.signOut();
  }
}
