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

  /// Previsão de demanda: média móvel dos últimos 30 dias de vendas reais.
  dom.ResultadoPrevisao _previsao() => const dom.PrevisaoDemanda().calcular(estado.curvaAbc(dom.PeriodoAbc.mes));

  static String _un(double v) {
    final s = v.toStringAsFixed(1).replaceAll('.', ',');
    return s.endsWith(',0') ? s.substring(0, s.length - 2) : s;
  }

  static final _reNegocio = RegExp(
      r'estoq|produt|vend|fatur|lucr|margem|markup|preco|custo|despes|caixa|client|compr|repor|reposic|fornec|promoc|descont|'
      r'valid|venc|abc|curva|ticket|loja|negoc|comerc|mercad|item|itens|unidade|saldo|falt|acab|giro|pedido|receita|dinheiro|'
      r'ganh|gast|pagar|conta|equilibrio|meta|cresc|aument|atencao|prioridad|previs|demanda|parad|encalh|semana|mes|hoje|ontem');
  static final _reForaDoEscopo = RegExp(
      r'piada|futebol|jogo d|clima|previsao do tempo|quem (e|foi|ganhou)|capital d|politic|eleic|filme|serie|musica|namor|'
      r'horoscopo|signo|traduz|poema|redacao|escreva um|receita de (bolo|comida)|programa(r|cao)|codigo|bitcoin|cripto');

  /// Só recusa o que é claramente outro assunto; o resto segue (a IA também tem a regra).
  bool _foraDoEscopo(String t) => !_reNegocio.hasMatch(t) && _reForaDoEscopo.hasMatch(t);

  /// "O que precisa de atenção": tudo que é urgente, do mais grave ao mais leve, com a ação.
  dom.RespostaConsultor _atencao(dom.ResultadoPrevisao prev) {
    final linhas = <String>[], fontes = <String>[];
    void add(String id, String linha) {
      if (linhas.length < 6 && !fontes.contains(id)) {
        linhas.add(linha);
        fontes.add(id);
      }
    }

    for (final i in prev.de(dom.SituacaoPrevisao.ruptura)) {
      add(i.produtoId, '- ${i.nome}: ZERADO e vendia ${_un(i.mediaDiaria)} un/dia. Reponha já (${i.reposicaoSugerida} un para ${prev.diasAlvo} dias).');
    }
    for (final p in estado.estoque.where((p) => (p.diasParaVencer ?? 9999) < 0)) {
      add(p.codigo, '- ${p.nome}: VENCIDO (${p.quantidade} un). Retire do ponto de venda.');
    }
    for (final i in prev.de(dom.SituacaoPrevisao.critico)) {
      add(i.produtoId, '- ${i.nome}: acaba em ${i.coberturaDias} dia(s) no ritmo atual. Compre ${i.reposicaoSugerida} un.');
    }
    for (final p in estado.estoque.where((p) => (p.diasParaVencer ?? 9999) >= 0 && (p.diasParaVencer ?? 9999) <= 7)) {
      add(p.codigo, '- ${p.nome}: vence em ${p.diasParaVencer} dia(s) (${p.quantidade} un). Faça promoção.');
    }
    for (final p in estado.estoque.where((p) => p.estoqueBaixo && p.quantidade > 0)) {
      add(p.codigo, '- ${p.nome}: ${p.quantidade} un, abaixo do mínimo de ${p.estoqueMinimo}.');
    }
    final parados = prev.de(dom.SituacaoPrevisao.parado).toList()..sort((a, b) => (b.estoque ?? 0).compareTo(a.estoque ?? 0));
    for (final i in parados.take(2)) {
      add(i.produtoId, '- ${i.nome}: ${i.estoque} un paradas, sem venda em ${prev.diasJanela} dias. Faça combo ou promoção.');
    }
    for (final p in estado.estoque.where((p) => p.markup < 1.3 && p.quantidade > 0)) {
      add(p.codigo, '- ${p.nome}: margem baixa (markup ${p.markup.toStringAsFixed(2).replaceAll('.', ',')}x). Revise o preço.');
    }
    if (linhas.isEmpty) {
      return _local('Nada urgente agora: nenhum produto zerado, vencendo, acabando ou abaixo do mínimo.');
    }
    return _local('O que precisa da sua atenção agora:\n${linhas.join('\n')}', tipo: dom.TipoResposta.lista, fontes: fontes);
  }

  /// "Quando acaba / quanto comprar": cobertura em dias e reposição para o horizonte.
  dom.RespostaConsultor _reposicao(dom.ResultadoPrevisao prev, List<Produto> citados) {
    final ids = {for (final p in citados) p.codigo};
    if (ids.isNotEmpty) {
      final linhas = <String>[];
      for (final i in prev.itens.where((i) => ids.contains(i.produtoId))) {
        linhas.add(switch (i.situacao) {
          dom.SituacaoPrevisao.semDados => '- ${i.nome}: não sei o saldo atual, então não dá para prever.',
          dom.SituacaoPrevisao.parado => '- ${i.nome}: ${i.estoque} un e nenhuma venda em ${prev.diasJanela} dias; não precisa comprar.',
          dom.SituacaoPrevisao.ruptura => '- ${i.nome}: zerado; vende ${_un(i.mediaDiaria)} un/dia. Compre ${i.reposicaoSugerida} un para ${prev.diasAlvo} dias.',
          _ when i.vendidosNoPeriodo == 0 => '- ${i.nome}: sem vendas em ${prev.diasJanela} dias.',
          _ => '- ${i.nome}: acaba em ${i.coberturaDias} dia(s) (vende ${_un(i.mediaDiaria)} un/dia). '
              '${i.reposicaoSugerida > 0 ? 'Compre ${i.reposicaoSugerida} un para ${prev.diasAlvo} dias.' : 'Não precisa comprar agora.'}',
        });
      }
      if (linhas.isNotEmpty) {
        return _local(linhas.join('\n'), tipo: dom.TipoResposta.lista, fontes: ids.toList());
      }
    }
    final comprar = prev.itens.where((i) => i.reposicaoSugerida > 0).take(8).toList();
    if (comprar.isEmpty) {
      return _local('Pelo ritmo de vendas dos últimos ${prev.diasJanela} dias, nenhum produto precisa de reposição para os próximos ${prev.diasAlvo} dias.');
    }
    final linhas = [
      for (final i in comprar)
        '- ${i.nome}: ${i.situacao == dom.SituacaoPrevisao.ruptura ? 'zerado' : 'acaba em ${i.coberturaDias} dia(s)'}; compre ${i.reposicaoSugerida} un.',
    ];
    return _local('Lista de compras para ${prev.diasAlvo} dias (pelo ritmo dos últimos ${prev.diasJanela}):\n${linhas.join('\n')}',
        tipo: dom.TipoResposta.lista, fontes: [for (final i in comprar) i.produtoId]);
  }

  dom.RespostaConsultor _parados(dom.ResultadoPrevisao prev) {
    final lista = prev.de(dom.SituacaoPrevisao.parado).toList()..sort((a, b) => (b.estoque ?? 0).compareTo(a.estoque ?? 0));
    if (lista.isEmpty) return _local('Nenhum produto com saldo ficou sem vender nos últimos ${prev.diasJanela} dias.');
    final linhas = [for (final i in lista.take(8)) '- ${i.nome}: ${i.estoque} un sem venda.'];
    return _local('Produtos parados há ${prev.diasJanela} dias (${lista.length}):\n${linhas.join('\n')}\nFaça combo, promoção ou pare de comprar.',
        tipo: dom.TipoResposta.lista, fontes: [for (final i in lista.take(8)) i.produtoId]);
  }

  /// "Estou ganhando dinheiro?": lucro bruto das vendas do mês menos os custos cadastrados da loja.
  dom.RespostaConsultor _ganhando() {
    final abc = estado.curvaAbc(dom.PeriodoAbc.mes);
    final fat = abc.valorLiquidoTotalCentavos;
    final lucro = abc.lucroBrutoTotalCentavos;
    if (fat <= 0) return _local('Ainda não há vendas registradas este mês para eu dizer se você está ganhando dinheiro.');
    if (lucro == null) {
      return _local('Você vendeu ${brl(fat / 100)} este mês, mas falta o custo de compra de alguns produtos. '
          'Cadastre o custo deles para eu calcular o lucro.');
    }
    final custos = estado.custos.fold<int>(0, (s, k) => s + centavos(k.valor));
    final base = 'Este mês você vendeu ${brl(fat / 100)} e o lucro bruto (venda menos o custo dos produtos) foi ${brl(lucro / 100)}';
    if (custos == 0) {
      return _local('$base. Cadastre aluguel, energia e outras despesas em "Custos & Despesas" para eu dizer se sobra dinheiro no fim do mês.');
    }
    final sobra = lucro - custos;
    return _local(sobra >= 0
        ? '$base. Tirando as despesas da loja (${brl(custos / 100)}), sobram ${brl(sobra / 100)}: sim, você está ganhando dinheiro.'
        : '$base. As despesas da loja somam ${brl(custos / 100)}, então ainda faltam ${brl(-sobra / 100)} para cobrir tudo. '
            'Foque nos produtos de maior retorno e evite estoque parado.');
  }

  /// "Como está o retorno": por produto citado (custo, venda, lucro por unidade) ou o ranking do mês.
  dom.RespostaConsultor _retorno(String t, List<Produto> citados) {
    if (citados.isNotEmpty) {
      final linhas = [
        for (final p in citados.take(4))
          '- ${p.nome}: custa ${brl(p.valorCompra)}, vende a ${brl(p.valorVenda)}, lucro de ${brl(p.lucroUnitario)} por unidade '
              '(markup ${p.markup.toStringAsFixed(2).replaceAll('.', ',')}x)${p.markup < 1.3 ? '. Margem baixa: revise o preço' : ''}.',
      ];
      return _local(linhas.join('\n'), tipo: dom.TipoResposta.lista, fontes: [for (final p in citados.take(4)) p.codigo]);
    }
    final top = estado.curvaAbc(dom.PeriodoAbc.mes).itens.where((i) => (i.lucroBrutoCentavos ?? 0) > 0).toList()
      ..sort((a, b) => b.lucroBrutoCentavos!.compareTo(a.lucroBrutoCentavos!));
    if (top.isEmpty) return _local('Ainda não há vendas com custo cadastrado neste mês para comparar o retorno dos produtos.');
    final linhas = [for (final i in top.take(5)) '- ${i.nome}: lucro bruto de ${brl(i.lucroBrutoCentavos! / 100)} em ${i.quantidade} un vendidas.'];
    final pediuUm = RegExp(r'deste|desse|daquele|este produto|esse produto').hasMatch(t);
    return _local('${pediuUm ? 'Me diga o nome do produto para eu detalhar. ' : ''}Produtos que mais deram retorno este mês:\n${linhas.join('\n')}',
        tipo: dom.TipoResposta.lista, fontes: [for (final i in top.take(5)) i.produtoId]);
  }

  dom.RespostaConsultor _baixos() {
    final baixos = estado.estoque.where((p) => p.estoqueBaixo).toList()..sort((a, b) => a.quantidade.compareTo(b.quantidade));
    if (baixos.isEmpty) return _local('Nenhum produto está no estoque mínimo ou abaixo.');
    final linhas = [for (final p in baixos.take(8)) '- ${p.nome}: ${p.quantidade} un (mínimo ${p.estoqueMinimo}).'];
    return _local('Produtos com poucas unidades (${baixos.length}):\n${linhas.join('\n')}',
        tipo: dom.TipoResposta.lista, fontes: [for (final p in baixos.take(8)) p.codigo]);
  }

  /// Resposta calculada (sem IA) ou null se a pergunta é aberta.
  dom.RespostaConsultor? _objetiva(String pergunta) {
    final t = _norm(pergunta);
    final snap = estado.snapshot();
    final resumo = _estoqueSvc.resumir(snap);

    if (_foraDoEscopo(t)) {
      return _local('Posso ajudar só com o seu negócio: estoque, vendas, custos e preços. Ex.: "o que precisa de atenção agora?"',
          tipo: dom.TipoResposta.foraDoEscopo);
    }

    if (!estado.estoqueConfiavel) {
      return _local('Não consegui ler o seu estoque agora, então não vou informar números que possam estar errados. Puxe a tela para atualizar e tente de novo.',
          tipo: dom.TipoResposta.indisponivel);
    }

    // Pergunta composta ("o que dá mais retorno e o que devo repor?"): responde as duas partes.
    final querRetorno = RegExp(r'retorno|margem|lucr|rende|rentab').hasMatch(t);
    if (querRetorno && RegExp(r'repor|reposic|comprar|pedir').hasMatch(t)) {
      final a = _retorno(t, const []), b = _reposicao(_previsao(), const []);
      return _local('${a.resposta}\n\n${b.resposta}', tipo: dom.TipoResposta.lista, fontes: {...a.fontes, ...b.fontes}.toList());
    }
    if (RegExp(r'ganhando|tendo lucro|dando lucro|lucrando|sobra dinheiro|perdendo dinheiro|no prejuizo|no vermelho|'
            r'(meu|o) lucro( total| do mes| deste mes| este mes| esse mes)?( foi| e)?$|quanto (eu )?lucrei')
        .hasMatch(t.replaceAll(RegExp(r'[?!. ]+$'), ''))) {
      return _ganhando();
    }
    if (RegExp(r'poucas? unidades|pouco estoque|pouca quantidade|estoque baixo|baixo estoque|quase (acabando|no fim)').hasMatch(t)) {
      return _baixos();
    }
    if (RegExp(r'atencao|prioridad|priorizar|preocup|urgent|cuidado|risco|problema|o que (eu )?(devo|preciso) (fazer|olhar|resolver|ver)|'
            r'o que (eu )?faco|por onde comec|proximo passo|cuidar (melhor )?d|'
            r'resumo do dia|como (esta|anda) (a loja|meu estoque|o estoque)')
        .hasMatch(t)) {
      return _atencao(_previsao());
    }
    if (RegExp(r'quando (acaba|vai acabar|termina)|vai acabar|quantos dias|cobertura|dura (ate|quanto)|quanto (devo |preciso )?(comprar|repor|pedir)|'
            r'lista de compra|pedido de compra|previs|demanda')
        .hasMatch(t)) {
      return _reposicao(_previsao(), _buscarProdutos(t));
    }
    if (RegExp(r'parad|encalh|nao vende|nao sai|sem giro|giro baixo|dinheiro parado').hasMatch(t)) {
      return _parados(_previsao());
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
    final cobrirCustos = t.contains('equilibrio') ||
        RegExp(r'cobrir (os |meus |minhas |as )?(custos|gastos|despesas|contas)|pagar (as |minhas )?(contas|despesas)|empatar').hasMatch(t);
    if (querRetorno && !cobrirCustos && !RegExp(r'margem baixa|markup').hasMatch(t)) return _retorno(t, achados);
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


    if (RegExp(r'acabando|acaba|falta|ruptura|repor|reposicao|esgotando|zerad').hasMatch(t)) {
      return _baixos();
    }

    if (RegExp(r'markup|margem baixa|prejuizo|abaixo de 1').hasMatch(t) && !cobrirCustos) {
      final ruins = estado.estoque.where((p) => p.markup < 1.3).toList();
      if (ruins.isEmpty) return _local('Nenhum produto está com markup abaixo de 1,30x.');
      final linhas = [for (final p in ruins.take(8)) '- ${p.nome}: markup ${p.markup.toStringAsFixed(2).replaceAll('.', ',')}x (custo ${brl(p.valorCompra)}, venda ${brl(p.valorVenda)}).'];
      return _local('Produtos com markup abaixo de 1,30x (${ruins.length}):\n${linhas.join('\n')}', tipo: dom.TipoResposta.lista, fontes: [for (final p in ruins.take(8)) p.codigo]);
    }

    if (cobrirCustos) {
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
        'Seus custos mensais somam ${brl(fixos / 100)}. Com a margem bruta projetada do estoque (${(margem * 100).toStringAsFixed(1).replaceAll('.', ',')}%), '
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
    final previsao = _previsao();
    final contexto = dom.ContextoAterramento.de(
      snapshotVersion: abc.snapshotVersion,
      estoque: resumo,
      abc: [abc],
      fuso: estado.fusoLoja,
      previsao: previsao,
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
      previsao: previsao,
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
    // Na demonstração não há login: a função aceita a chave pública (com o limite por minuto dela).
    final token = Supabase.instance.client.auth.currentSession?.accessToken ?? (Config.demo ? Config.supabaseAnonKey : null);
    if (token == null) throw const dom.ProvedorIndisponivelIa('sem sessão', retentavel: false);
    final http.Response r;
    try {
      r = await http.post(
        Uri.parse(Config.iaFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
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
      b.writeln('- Margem bruta projetada: ${(margem * 100).toStringAsFixed(1).replaceAll('.', ',')}%. Meta de vendas para empatar: ${brl(totalCustos / 100 / margem)} por mês.');
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
    b.writeln('- Margem baixa: ${p.nome} com markup ${p.markup.toStringAsFixed(2).replaceAll('.', ',')}x (abaixo de 1,30x).');
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
