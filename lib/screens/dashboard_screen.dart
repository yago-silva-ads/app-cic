import 'package:cic_domain/cic_domain.dart' as dom;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/shell.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';

/// Painel executivo (porte de `DashboardScreen.tsx`). Os totais são calculados
/// em centavos inteiros e a Curva ABC vem do contrato `abc-v1` (cic_domain).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.estado, required this.onNavegar});
  final AppState estado;
  final void Function(NavTab, {String? codigo}) onNavegar;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  dom.PeriodoAbc _periodo = dom.PeriodoAbc.projetado;

  static const _rotulos = {
    dom.PeriodoAbc.projetado: 'Estoque atual (projetado)',
    dom.PeriodoAbc.hoje: 'Hoje',
    dom.PeriodoAbc.seteDias: '7 dias',
    dom.PeriodoAbc.mes: '30 dias',
    dom.PeriodoAbc.todos: 'Todo o período',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final e = widget.estado;
    final estoque = e.estoque;

    // Totais em centavos (sem erro de ponto flutuante).
    var custoEstoque = 0, retorno = 0, unidades = 0;
    for (final p in estoque) {
      custoEstoque += centavos(p.valorCompra) * p.quantidade;
      retorno += centavos(p.valorVenda) * p.quantidade;
      unidades += p.quantidade;
    }
    final lucro = retorno - custoEstoque;
    final margemSobreCusto = custoEstoque > 0 ? lucro * 100 / custoEstoque : 0.0;
    final custosMensais = e.custos.fold<int>(0, (s, k) => s + centavos(k.valor));
    final emRisco = custosMensais > 0 && lucro < custosMensais;
    final margemBruta = retorno > 0 ? lucro / retorno : 0.0;
    final pontoEquilibrio = margemBruta > 0 ? custosMensais / 100 / margemBruta : 0.0;

    final abc = e.estoqueConfiavel ? e.curvaAbc(_periodo) : null;

    // Mix por categoria
    final categorias = <String, (int, int)>{};
    for (final p in estoque) {
      final cat = p.categoria.isEmpty ? 'Geral' : p.categoria;
      final atual = categorias[cat] ?? (0, 0);
      categorias[cat] = (atual.$1 + p.quantidade, atual.$2 + centavos(p.valorVenda) * p.quantidade);
    }

    return CicPagina(children: [
      if (emRisco) ...[
        _alertaPrejuizo(context, lucro, custosMensais),
        const SizedBox(height: 20),
      ],
      CicGrid(minLargura: 215, children: [
        _Kpi(
          titulo: 'Custo do Estoque',
          icone: LucideIcons.boxes,
          valor: brl(custoEstoque / 100),
          rodape: '${inteiro(unidades)} unidades físicas',
        ),
        _Kpi(
          titulo: 'Faturamento Projetado',
          icone: LucideIcons.trendingUp,
          tom: BadgeTom.ouro,
          valor: brl(retorno / 100),
          corValor: c.gold,
          destaque: true,
          rodapeWidget: Row(children: [
            Text('+${margemSobreCusto.toStringAsFixed(1)}%', style: TextStyle(color: c.emerald, fontWeight: FontWeight.w700, fontSize: 11)),
            const SizedBox(width: 6),
            Flexible(child: Text('margem média sobre custo', style: TextStyle(color: c.textMuted, fontSize: 11))),
          ]),
        ),
        _Kpi(
          titulo: 'Lucro Bruto Planejado',
          icone: LucideIcons.dollarSign,
          tom: BadgeTom.verde,
          valor: brl(lucro / 100),
          corValor: lucro >= 0 ? c.emerald : const Color(0xFFEF4444),
          rodape: 'Antes dos custos operacionais',
        ),
        _Kpi(
          titulo: 'Custos Fixos Mensais',
          icone: LucideIcons.target,
          valor: brl(custosMensais / 100),
          rodape: 'Meta Break-Even: ${brl(pontoEquilibrio)}',
        ),
      ]),
      const SizedBox(height: 20),
      LayoutBuilder(builder: (context, box) {
        final duasColunas = box.maxWidth >= 900;
        final abcCard = _cardAbc(context, abc);
        final lateral = Column(children: [
          _cardCategorias(context, categorias, retorno),
          const SizedBox(height: 20),
          _cardConsultor(context),
        ]);
        if (!duasColunas) return Column(children: [abcCard, const SizedBox(height: 20), lateral]);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: abcCard),
            const SizedBox(width: 20),
            Expanded(child: lateral),
          ],
        );
      }),
    ]);
  }

  Widget _alertaPrejuizo(BuildContext context, int lucro, int custos) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.redBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.redBorder, width: 2),
        boxShadow: c.isLight ? null : [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.2), blurRadius: 25)],
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CicIconeCaixa(LucideIcons.shieldAlert, tom: BadgeTom.vermelho, tamanho: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ALERTA DE RISCO OPERACIONAL: Prejuízo Projetado',
                      style: TextStyle(color: c.isLight ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5), fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(style: TextStyle(color: c.isLight ? const Color(0xFFB91C1C) : const Color(0xFFFECACA), fontSize: 12, height: 1.45), children: [
                      const TextSpan(text: 'O lucro bruto potencial do estoque atual ('),
                      TextSpan(text: brl(lucro / 100), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const TextSpan(text: ') não cobre seus custos operacionais mensais ('),
                      TextSpan(text: brl(custos / 100), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const TextSpan(text: '). Faltam '),
                      TextSpan(text: brl((custos - lucro) / 100), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const TextSpan(text: ' para atingir o ponto de equilíbrio. Reajuste o markup ou aumente o volume de vendas.'),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          CicBotao('Consultar IA', perigo: true, compacto: true, onPressed: () => widget.onNavegar(NavTab.inteligencia)),
        ],
      ),
    );
  }

  Widget _cardAbc(BuildContext context, dom.ResultadoCurvaAbc? abc) {
    final c = context.c;
    final itens = abc?.itens ?? const <dom.ItemCurvaAbc>[];
    final resumo = abc?.resumoPorClasse;
    final projetado = _periodo == dom.PeriodoAbc.projetado;
    return CicCard(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CicTitulo(
          'Curva ABC de Estoque (Pareto 80/20)',
          sub: projetado
              ? 'Cenário teórico: estoque atual × preço de venda. Não é venda real.'
              : 'Vendas reais no período (receita líquida, fuso da loja).',
          trailing: CicBadge('${itens.length} itens analisados', tom: BadgeTom.ouro),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final p in _rotulos.keys)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  // softWrap/visible: o rótulo era cortado com degradê ("Hoj", "7 dia") no navegador.
                  label: Text(_rotulos[p]!, softWrap: false, overflow: TextOverflow.visible,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _periodo == p ? Colors.black : c.textSoft)),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                  selected: _periodo == p,
                  selectedColor: c.botao,
                  backgroundColor: c.sub,
                  side: BorderSide(color: _periodo == p ? c.botao : c.subBorder),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _periodo = p),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        if (abc == null)
          CicErroBanner(mensagem: 'Estoque não carregado: a Curva ABC não é calculada com saldo desconhecido.', onTentar: widget.estado.carregar)
        else ...[
          CicGrid(minLargura: 150, espaco: 10, maxColunas: 3, children: [
            _classe(context, 'Classe A', '${resumo?[dom.ClasseAbc.A]?.produtos ?? 0}', 'Top 80% do faturamento. Nunca deixe faltar!', const Color(0xFF10B981)),
            _classe(context, 'Classe B', '${resumo?[dom.ClasseAbc.B]?.produtos ?? 0}', '15% intermediário do faturamento.', const Color(0xFFF59E0B)),
            _classe(context, 'Classe C', '${resumo?[dom.ClasseAbc.C]?.produtos ?? 0}', 'Últimos 5% da receita. Evite imobilizar capital.', const Color(0xFF94A3B8)),
          ]),
          const SizedBox(height: 14),
          if (abc.semMovimento)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CicSub(child: Row(children: [
                Icon(LucideIcons.info, size: 16, color: c.textMuted),
                const SizedBox(width: 10),
                Expanded(child: Text('Sem vendas neste período: todos os produtos ficam na classe C.', style: TextStyle(color: c.textMuted, fontSize: 12))),
              ])),
            ),
          for (final p in abc.problemas.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CicBadge('Dados incompletos: ${p.codigo.name}', tom: BadgeTom.ambar, icone: LucideIcons.triangleAlert),
            ),
          _tabelaAbc(context, itens.take(6).toList(), projetado),
        ],
      ]),
    );
  }

  Widget _classe(BuildContext context, String t, String n, String d, Color cor) {
    final c = context.c;
    return CicSub(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$t ($n)', style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 4),
        Text(d, style: TextStyle(color: c.textMuted, fontSize: 11)),
      ]),
    );
  }

  Widget _tabelaAbc(BuildContext context, List<dom.ItemCurvaAbc> itens, bool projetado) {
    final c = context.c;
    if (itens.isEmpty) {
      return const CicVazio(icone: LucideIcons.boxes, titulo: 'Nenhum produto cadastrado', texto: 'Cadastre produtos no Leitor GS1 ou importe uma NF-e.');
    }
    TextStyle cab() => TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w800);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(children: [
          SizedBox(width: 70, child: Text('CLASSE', style: cab())),
          Expanded(child: Text('PRODUTO', style: cab())),
          SizedBox(width: 56, child: Text(projetado ? 'ESTOQUE' : 'VENDIDO', style: cab())),
          SizedBox(width: 86, child: Text(projetado ? 'POTENCIAL' : 'RECEITA', textAlign: TextAlign.right, style: cab())),
          SizedBox(width: 78, child: Text('LUCRO', textAlign: TextAlign.right, style: cab())),
        ]),
      ),
      Divider(height: 1, color: c.cardBorder),
      for (final i in itens)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.isLight ? const Color(0xFFE2E8F0) : const Color(0xFF202020)))),
          child: Row(children: [
            SizedBox(
              width: 70,
              child: Align(alignment: Alignment.centerLeft, child: _etiquetaClasse(context, i.classe)),
            ),
            Expanded(
              child: Text(i.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            SizedBox(width: 56, child: Text('${i.quantidade} un', style: fonteMono(context, size: 11, peso: FontWeight.w500, cor: c.textSoft))),
            SizedBox(
              width: 86,
              child: Text(brl(i.valorBaseCentavos / 100), textAlign: TextAlign.right, style: fonteMono(context, size: 11, cor: c.gold)),
            ),
            SizedBox(
              width: 78,
              child: Text(
                i.lucroBrutoCentavos == null ? '—' : brl(i.lucroBrutoCentavos! / 100),
                textAlign: TextAlign.right,
                style: fonteMono(context, size: 11, peso: FontWeight.w600, cor: i.lucroBrutoCentavos == null ? c.textMuted : c.emerald),
              ),
            ),
          ]),
        ),
    ]);
  }

  Widget _etiquetaClasse(BuildContext context, dom.ClasseAbc cl) => CicBadge(
    'Classe ${cl.name}',
    tom: switch (cl) {
      dom.ClasseAbc.A => BadgeTom.verde,
      dom.ClasseAbc.B => BadgeTom.ambar,
      dom.ClasseAbc.C => BadgeTom.neutro,
    },
  );

  Widget _cardCategorias(BuildContext context, Map<String, (int, int)> cats, int total) {
    final c = context.c;
    return CicCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CicTitulo('Mix por Categoria', trailing: Icon(LucideIcons.chartPie, size: 16, color: c.textMuted)),
        const SizedBox(height: 14),
        if (cats.isEmpty) Text('Sem produtos.', style: TextStyle(color: c.textMuted, fontSize: 12)),
        for (final en in cats.entries) ...[
          Row(children: [
            Expanded(child: Text(en.key, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSoft, fontSize: 12, fontWeight: FontWeight.w500))),
            Text('${brl(en.value.$2 / 100)} (${total > 0 ? (en.value.$2 * 100 / total).toStringAsFixed(0) : 0}%)',
                style: fonteMono(context, size: 11, peso: FontWeight.w500, cor: c.textMuted)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total > 0 ? (en.value.$2 / total).clamp(0, 1).toDouble() : 0,
              minHeight: 6,
              color: c.gold,
              backgroundColor: c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF252525),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ]),
    );
  }

  Widget _cardConsultor(BuildContext context) {
    final c = context.c;
    return CicCard(
      gradiente: LinearGradient(
        colors: c.isLight ? const [Color(0xFFFEF9EE), Colors.white] : const [Color(0xFF1C1810), Color(0xFF121212)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borda: c.isLight ? const Color(0xFFF3D58C) : c.gold.withValues(alpha: 0.3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(LucideIcons.sparkles, size: 18, color: const Color(0xFFB4821E)),
          const SizedBox(width: 8),
          const Text('CONSULTOR FINANCEIRO CIC', style: TextStyle(color: Color(0xFFB4821E), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        ]),
        const SizedBox(height: 10),
        Text(
          'Perguntas sobre estoque, faturamento e Curva ABC são respondidas direto dos seus números. A IA só explica o que foi calculado: nunca inventa valores.',
          style: TextStyle(color: c.isLight ? const Color(0xFF475569) : const Color(0xFFD4D4D4), fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 14),
        CicBotao('Abrir Diagnóstico com IA', icone: LucideIcons.arrowUpRight, largo: true, onPressed: () => widget.onNavegar(NavTab.inteligencia)),
      ]),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.titulo,
    required this.icone,
    required this.valor,
    this.rodape,
    this.rodapeWidget,
    this.tom = BadgeTom.neutro,
    this.corValor,
    this.destaque = false,
  });

  final String titulo;
  final IconData icone;
  final String valor;
  final String? rodape;
  final Widget? rodapeWidget;
  final BadgeTom tom;
  final Color? corValor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return CicCard(
      destaque: destaque && !c.isLight,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(titulo.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tom == BadgeTom.ouro ? c.gold : c.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          ),
          CicIconeCaixa(icone, tom: tom),
        ]),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(valor, style: fonteMono(context, size: 24, cor: corValor ?? c.text)),
        ),
        const SizedBox(height: 8),
        rodapeWidget ?? Text(rodape ?? '', style: TextStyle(color: c.textMuted, fontSize: 11), overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
