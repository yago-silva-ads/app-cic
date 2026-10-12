import 'dart:async';
import 'dart:convert';

import 'package:cic_domain/cic_domain.dart' as dom;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/format.dart';
import '../data/models.dart';
import '../state/app_state.dart';

String _norm(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const para = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final i = de.indexOf(ch);
    b.write(i >= 0 ? para[i] : ch);
  }
  return b.toString();
}

/// Consultor da loja. Perguntas objetivas são respondidas SEM IA, direto dos
/// números calculados (funcionam mesmo com o Gemini fora do ar). Só análise
/// aberta chama a IA, e a resposta dela é descartada se citar qualquer
/// número, produto ou classe que não esteja nos cálculos (`ContextoAterramento`).
class IaConsultor {
  IaConsultor(this.estado);

  final AppState estado;
  final _det = const dom.RespostasDeterministicas();
  final _estoqueSvc = const dom.EstoqueService();
  final controle = dom.ControleRequisicoes();

  dom.PeriodoAbc _periodoDe(String t) {
    if (t.contains('hoje')) return dom.PeriodoAbc.hoje;
    if (RegExp(r'semana|7 dias|sete dias|ultimos 7').hasMatch(t)) return dom.PeriodoAbc.seteDias;
    if (RegExp(r'sempre|todo o|historico|desde o inicio|no total').hasMatch(t)) return dom.PeriodoAbc.todos;
    return dom.PeriodoAbc.mes;
  }

  dom.RespostaConsultor _local(String texto, {dom.TipoResposta tipo = dom.TipoResposta.objetiva, Map<String, num> metricas = const {}, List<String> fontes = const []}) {
    final snap = estado.snapshot();
    return dom.RespostaConsultor(
      resposta: texto,
      tipo: tipo,
      origem: dom.OrigemResposta.deterministica,
      snapshotVersion: snap.versao,
      atualizadoEm: snap.atualizadoEm,
      metricas: metricas,
      fontes: fontes,
    );
  }

  static const _vazias = {
    'tem', 'tenho', 'temos', 'quanto', 'quantos', 'quanta', 'quantas', 'estoque', 'produto', 'produtos', 'unidade',
    'unidades', 'ainda', 'agora', 'loja', 'meu', 'minha', 'meus', 'minhas', 'qual', 'quais', 'que', 'saldo', 'resta',
    'sobrou', 'sobra', 'para', 'pra', 'voce', 'esta', 'estao', 'aqui', 'algum', 'alguma', 'mais', 'menos', 'com',
    'sem', 'dos', 'das', 'nos', 'nas', 'uma', 'uns', 'umas', 'del', 'por', 'vende', 'vendo', 'vendemos', 'preco',
  };

  List<String> _termos(String t) => [
    for (final w in t.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').split(' '))
      if (w.length >= 3 && !_vazias.contains(w)) w,
  ];

  /// Produtos cujo nome ou código contém os termos significativos da pergunta.
  List<Produto> _buscarProdutos(String t) {
    final termos = _termos(t);
    if (termos.isEmpty) return const [];
    var melhor = 0;
    final pontuados = <(Produto, int)>[];
    for (final p in estado.estoque) {
      final nome = _norm('${p.nome} ${p.categoria}');
      var pts = 0;
      for (final w in termos) {
        if (p.codigo == w) pts += 10;
        if (RegExp(r'\b' + RegExp.escape(w)).hasMatch(nome)) pts += 2;
      }
      if (pts > 0) pontuados.add((p, pts));
      if (pts > melhor) melhor = pts;
    }
    // Exige que a pergunta cite o produto de forma clara (nome ou código).
    if (melhor < 2) return const [];
    return [for (final e in pontuados) if (e.$2 == melhor) e.$1];
  }

  /// Resposta calculada (sem IA) ou null se a pergunta é aberta.
  dom.RespostaConsultor? _objetiva(String pergunta) {
    final t = _norm(pergunta);
    final snap = estado.snapshot();
    final resumo = _estoqueSvc.resumir(snap);

    if (!estado.estoqueConfiavel) {
      return _local('Não consegui ler o seu estoque agora, então não vou informar números que possam estar errados. Puxe a tela para atualizar e tente de novo.',
          tipo: dom.TipoResposta.indisponivel);
    }

    if (RegExp(r'vencer|vencimento|validade|vencid').hasMatch(t)) {
      final lista = estado.estoque.where((p) => p.dataValidade != null && (p.diasParaVencer ?? 9999) <= 30).toList()
        ..sort((a, b) => a.dataValidade!.compareTo(b.dataValidade!));
      if (lista.isEmpty) return _local('Nenhum produto vence nos próximos 30 dias nem está vencido.');
      final linhas = [
        for (final p in lista.take(8))
          '- ${p.nome}: ${(p.diasParaVencer! < 0) ? 'VENCIDO há ${p.diasParaVencer!.abs()} dia(s)' : 'vence em ${p.diasParaVencer} dia(s)'} (${dataCurta(p.dataValidade)}), ${p.quantidade} un.',
      ];
      return _local('Produtos com validade crítica (${lista.length}):\n${linhas.join('\n')}', tipo: dom.TipoResposta.lista, fontes: [for (final p in lista.take(8)) p.codigo]);
    }

    if (RegExp(r'em falta|faltando|zerad|sem estoque|esgotad|acabou|nao tem mais|o que nao tenho|o que (nao|não) tem').hasMatch(t)) {
      final zerados = estado.estoque.where((p) => p.quantidade <= 0).toList();
      if (zerados.isEmpty) return _local('Nenhum produto está zerado: todos os ${estado.estoque.length} cadastrados têm saldo.');
      final linhas = [for (final p in zerados.take(10)) '- ${p.nome} (código ${p.codigo}): 0 un.'];
      final resto = zerados.length > 10 ? '\nE mais ${zerados.length - 10}.' : '';
      return _local('Produtos sem estoque (${zerados.length}):\n${linhas.join('\n')}$resto',
          tipo: dom.TipoResposta.lista, fontes: [for (final p in zerados.take(10)) p.codigo]);
    }

    final achados = _buscarProdutos(t);
    if (achados.isNotEmpty) {
      final linhas = [
        for (final p in achados.take(6))
          '- ${p.nome}: ${p.quantidade <= 0 ? 'SEM ESTOQUE (0 un)' : '${p.quantidade} un em estoque'}, vende a ${brl(p.valorVenda)}'
              '${p.dataValidade != null ? ', validade ${dataCurta(p.dataValidade)}' : ''}.',
      ];
      final cab = achados.length == 1
          ? (achados.first.quantidade > 0 ? 'Sim, você tem:' : 'Você tem o produto cadastrado, mas está sem estoque:')
          : 'Encontrei ${achados.length} produtos:';
      return _local('$cab\n${linhas.join('\n')}', tipo: dom.TipoResposta.lista, fontes: [for (final p in achados.take(6)) p.codigo]);
    }


    if (RegExp(r'acabando|acaba|estoque baixo|baixo estoque|falta|ruptura|repor|reposicao|esgotando|zerad').hasMatch(t)) {
      final baixos = estado.estoque.where((p) => p.estoqueBaixo).toList()..sort((a, b) => a.quantidade.compareTo(b.quantidade));
      if (baixos.isEmpty) return _local('Nenhum produto está no estoque mínimo ou abaixo.');
      final linhas = [for (final p in baixos.take(8)) '- ${p.nome}: ${p.quantidade} un (mínimo ${p.estoqueMinimo}).'];
      return _local('Produtos para repor (${baixos.length}):\n${linhas.join('\n')}', tipo: dom.TipoResposta.lista, fontes: [for (final p in baixos.take(8)) p.codigo]);
    }

    if (RegExp(r'markup|margem baixa|prejuizo|abaixo de 1').hasMatch(t) && !t.contains('equilibrio')) {
      final ruins = estado.estoque.where((p) => p.markup < 1.3).toList();
      if (ruins.isEmpty) return _local('Nenhum produto está com markup abaixo de 1,30x.');
      final linhas = [for (final p in ruins.take(8)) '- ${p.nome}: markup ${p.markup.toStringAsFixed(2)}x (custo ${brl(p.valorCompra)}, venda ${brl(p.valorVenda)}).'];
      return _local('Produtos com markup abaixo de 1,30x (${ruins.length}):\n${linhas.join('\n')}', tipo: dom.TipoResposta.lista, fontes: [for (final p in ruins.take(8)) p.codigo]);
    }

    if (t.contains('equilibrio')) {
      var custo = 0, retorno = 0;
      for (final p in estado.estoque) {
        custo += centavos(p.valorCompra) * p.quantidade;
        retorno += centavos(p.valorVenda) * p.quantidade;
      }
      final lucro = retorno - custo;
      final fixos = estado.custos.fold<int>(0, (s, k) => s + centavos(k.valor));
      if (fixos == 0) return _local('Você ainda não cadastrou custos. Cadastre em "Custos & Despesas" para eu calcular o ponto de equilíbrio.');
      if (retorno == 0 || lucro <= 0) return _local('Com o estoque atual não há lucro projetado para cobrir os custos de ${brl(fixos / 100)} por mês.');
      final margem = lucro / retorno;
      final meta = fixos / 100 / margem;
      return _local(
        'Seus custos mensais somam ${brl(fixos / 100)}. Com a margem bruta projetada do estoque (${(margem * 100).toStringAsFixed(1)}%), '
        'você precisa vender ${brl(meta)} por mês para empatar.',
      );
    }

    final per = _periodoDe(t);
    if (RegExp(r'mais vend|campeao|lider|que mais saiu|mais sai|top ').hasMatch(t)) {
      return _det.maisVendido(estado.curvaAbc(per == dom.PeriodoAbc.projetado ? dom.PeriodoAbc.mes : per));
    }
    if (RegExp(r'fatur|receita|vendi|quanto vendeu|quanto entrou|total de vendas').hasMatch(t)) {
      return _det.faturamento(estado.curvaAbc(per));
    }
    if (RegExp(r'\babc\b|classe a|curva').hasMatch(t)) {
      final r = t.contains('projet') || t.contains('potencial') ? dom.PeriodoAbc.projetado : per;
      return _det.resumoAbc(estado.curvaAbc(r));
    }
    if (RegExp(r'o que (eu )?tenho|quantos produtos|quantas unidades|meu estoque|tenho no estoque|estoque agora|em estoque').hasMatch(t)) {
      return _det.estoqueAtual(resumo);
    }
    if (RegExp(r'\btem\b|quanto(s|as)? .*(tem|resta|sobr)|estoque de|saldo de').hasMatch(t) &&
        !RegExp(r'o que (eu )?tenho|meu estoque|estoque agora|quantos produtos|quantas unidades').hasMatch(t)) {
      final termo = _termos(t).join(' ');
      if (termo.isNotEmpty) {
        return _local('Não encontrei "$termo" no seu estoque. Se você vende esse produto, cadastre-o no Leitor GS1 para eu acompanhar.');
      }
    }

    return null;
  }

  /// Fallback seguro: o que de fato foi calculado, sem IA.
  dom.RespostaConsultor _fallback(dom.ResultadoCurvaAbc abc) {
    final resumo = _estoqueSvc.resumir(estado.snapshot());
    final e = _det.estoqueAtual(resumo);
    final a = _det.resumoAbc(abc);
    return dom.RespostaConsultor(
      resposta: '${e.resposta}\n${a.resposta}',
      tipo: dom.TipoResposta.objetiva,
      origem: dom.OrigemResposta.deterministica,
      snapshotVersion: abc.snapshotVersion,
      atualizadoEm: abc.atualizadoEm,
      periodo: abc.periodo.codigo,
    );
  }

  /// Responde uma pergunta do chat. Nunca lança: erro vira resposta com aviso.
  Future<dom.RespostaConsultor?> perguntar(String pergunta) async {
    final token = controle.iniciar();
    final direta = _objetiva(pergunta);
    if (direta != null) return controle.ehAtual(token) ? direta : null;

    if (!estado.estoqueConfiavel) return _objetiva('estoque');
    final per = _periodoDe(_norm(pergunta));
    final abc = estado.curvaAbc(per);
    final resumo = _estoqueSvc.resumir(estado.snapshot());
    final contexto = dom.ContextoAterramento.de(
      snapshotVersion: abc.snapshotVersion,
      estoque: resumo,
      abc: [abc],
      fuso: estado.fusoLoja,
    );
    final consulta = dom.ConsultaIa(
      pergunta: pergunta,
      periodo: per,
      fuso: estado.fusoLoja.nome,
      snapshotVersion: abc.snapshotVersion,
      atualizadoEm: abc.atualizadoEm,
      demonstracao: false,
      estoque: resumo,
      abc: abc,
    );

    // No máximo 2 tentativas de 18 s: se o Gemini falhar, a resposta
    // calculada aparece logo, sem o lojista ficar esperando.
    final resposta = await const dom.ConsultorSeguro(
      politica: dom.PoliticaRetentativa(maxTentativas: 2, timeoutPorTentativa: Duration(seconds: 18)),
    ).responder(
      requestId: 'req-$token',
      chamarIa: () => _chamarServidor(consulta),
      contexto: contexto,
      fallback: _fallback(abc),
    );
    return controle.ehAtual(token) ? resposta : null;
  }

  Future<Object?> _chamarServidor(dom.ConsultaIa consulta) async {
    final sessao = Supabase.instance.client.auth.currentSession;
    if (sessao == null) throw const dom.ProvedorIndisponivelIa('sem sessão', retentavel: false);
    final http.Response r;
    try {
      r = await http.post(
        Uri.parse(Config.iaFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${sessao.accessToken}',
          'apikey': Config.supabaseAnonKey,
        },
        // Sem tenantId: o servidor usa a loja do JWT.
        body: jsonEncode(consulta.toJson()),
      );
    } on TimeoutException {
      throw const dom.TempoEsgotadoIa('timeout http');
    } catch (_) {
      throw const dom.SemConexaoIa('falha de rede');
    }
    if (r.statusCode != 200) {
      final ra = int.tryParse(r.headers['retry-after'] ?? '');
      throw dom.ErroIa.deStatusHttp(r.statusCode, retryAfter: ra == null ? null : Duration(seconds: ra));
    }
    try {
      return jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw const dom.RespostaInvalidaIa('corpo não é JSON');
    }
  }

  /// Tenta um comentário de IA sobre a auditoria já calculada. Opcional.
  Future<dom.RespostaConsultor> comentarioSobreAuditoria() async {
    final r = await perguntar('Faça uma análise estratégica do meu negócio com base nos dados calculados.');
    return r ?? _fallback(estado.curvaAbc(dom.PeriodoAbc.mes));
  }
}

/// Auditoria completa e determinística (sem IA): tudo vem dos dados reais.
String montarAuditoria(AppState e) {
  final estoque = e.estoque;
  final b = StringBuffer();
  var custo = 0, retorno = 0, unidades = 0;
  for (final p in estoque) {
    custo += centavos(p.valorCompra) * p.quantidade;
    retorno += centavos(p.valorVenda) * p.quantidade;
    unidades += p.quantidade;
  }
  final lucro = retorno - custo;
  final fixos = e.custos.where((k) => k.tipo == TipoCusto.fixo).fold<int>(0, (s, k) => s + centavos(k.valor));
  final variaveis = e.custos.where((k) => k.tipo == TipoCusto.variavel).fold<int>(0, (s, k) => s + centavos(k.valor));
  final totalCustos = fixos + variaveis;

  b.writeln('## 1. Panorama do estoque');
  b.writeln('- Produtos cadastrados: ${estoque.length} (${inteiro(unidades)} unidades em estoque).');
  b.writeln('- Custo do estoque: ${brl(custo / 100)} | Faturamento projetado: ${brl(retorno / 100)} | Lucro bruto projetado: ${brl(lucro / 100)}.');

  b.writeln('\n## 2. Custos e ponto de equilíbrio');
  if (totalCustos == 0) {
    b.writeln('- Nenhum custo cadastrado. Cadastre aluguel, energia e taxas em "Custos & Despesas" para calcular o equilíbrio.');
  } else {
    b.writeln('- Custos mensais: ${brl(totalCustos / 100)} (fixos ${brl(fixos / 100)}, variáveis ${brl(variaveis / 100)}).');
    if (retorno > 0 && lucro > 0) {
      final margem = lucro / retorno;
      b.writeln('- Margem bruta projetada: ${(margem * 100).toStringAsFixed(1)}%. Meta de vendas para empatar: ${brl(totalCustos / 100 / margem)} por mês.');
    }
    if (lucro < totalCustos) {
      b.writeln('- ALERTA: o lucro bruto projetado do estoque (${brl(lucro / 100)}) não cobre os custos mensais. Faltam ${brl((totalCustos - lucro) / 100)}.');
    } else {
      b.writeln('- O lucro bruto projetado cobre os custos mensais, sobrando ${brl((lucro - totalCustos) / 100)}.');
    }
  }

  b.writeln('\n## 3. Riscos imediatos');
  final vencidos = estoque.where((p) => (p.diasParaVencer ?? 9999) < 0).toList();
  final vencendo = estoque.where((p) => (p.diasParaVencer ?? 9999) >= 0 && (p.diasParaVencer ?? 9999) <= 30).toList();
  final baixos = estoque.where((p) => p.estoqueBaixo).toList();
  final margemBaixa = estoque.where((p) => p.markup < 1.3).toList();
  if (vencidos.isEmpty && vencendo.isEmpty && baixos.isEmpty && margemBaixa.isEmpty) {
    b.writeln('- Nenhum risco imediato: validades, saldos mínimos e margens em ordem.');
  }
  for (final p in vencidos.take(5)) {
    b.writeln('- VENCIDO: ${p.nome} (${p.quantidade} un). Retire do ponto de venda.');
  }
  for (final p in vencendo.take(5)) {
    b.writeln('- Vence em ${p.diasParaVencer} dia(s): ${p.nome} (${p.quantidade} un). Faça promoção ou queima.');
  }
  for (final p in baixos.take(5)) {
    b.writeln('- Estoque baixo: ${p.nome} com ${p.quantidade} un (mínimo ${p.estoqueMinimo}).');
  }
  for (final p in margemBaixa.take(5)) {
    b.writeln('- Margem baixa: ${p.nome} com markup ${p.markup.toStringAsFixed(2)}x (abaixo de 1,30x).');
  }

  b.writeln('\n## 4. Curva ABC (vendas dos últimos 30 dias)');
  if (!e.estoqueConfiavel) {
    b.writeln('- Indisponível: o estoque não foi lido.');
  } else {
    final abc = e.curvaAbc(dom.PeriodoAbc.mes);
    final resumo = abc.resumoPorClasse;
    if (abc.semMovimento) {
      b.writeln('- Sem vendas nos últimos 30 dias: todos os produtos ficam na classe C.');
    } else {
      b.writeln('- Faturamento líquido: ${dom.formatarCentavos(abc.valorLiquidoTotalCentavos)} em ${inteiro(abc.quantidadeTotal)} unidades.');
      b.writeln('- Classe A: ${resumo[dom.ClasseAbc.A]!.produtos} | B: ${resumo[dom.ClasseAbc.B]!.produtos} | C: ${resumo[dom.ClasseAbc.C]!.produtos}.');
      for (final i in abc.itens.where((i) => i.classe == dom.ClasseAbc.A).take(5)) {
        b.writeln('- Classe A: ${i.nome} (${dom.formatarCentavos(i.valorBaseCentavos)}, estoque ${i.estoqueDisponivel ?? 'desconhecido'}).');
      }
      for (final a in abc.alertas.take(5)) {
        b.writeln('- ${a.acao}');
      }
    }
    for (final p in abc.problemas.take(3)) {
      b.writeln('- Dado incompleto (${p.codigo.name}): os valores acima podem estar subestimados.');
    }
  }
  return b.toString().trim();
}
