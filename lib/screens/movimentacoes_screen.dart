import 'package:cic_domain/cic_domain.dart' as dom;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';

const _motivos = {
  'COMPRA_FORNECEDOR': 'Compra de Fornecedor',
  'VENDA_PDV': 'Venda no Caixa (PDV)',
  'AJUSTE_ESTOQUE': 'Ajuste de Inventário',
  'PERDA_AVARIA': 'Perda / Avaria / Quebra',
  'DEVOLUCAO': 'Devolução de Cliente',
  'PRODUCAO_COMBO': 'Produção de Combo/Kit',
};

/// Histórico de entradas e saídas (porte de `MovimentacoesScreen.tsx`). Os
/// períodos usam o fuso da loja (mesmo contrato da Curva ABC).
class MovimentacoesScreen extends StatefulWidget {
  const MovimentacoesScreen({super.key, required this.estado});
  final AppState estado;

  @override
  State<MovimentacoesScreen> createState() => _MovimentacoesScreenState();
}

class _MovimentacoesScreenState extends State<MovimentacoesScreen> {
  dom.PeriodoAbc _periodo = dom.PeriodoAbc.todos;
  String _tipo = 'TODOS';
  final _busca = TextEditingController();

  AppState get e => widget.estado;

  static const _rotulos = {
    dom.PeriodoAbc.hoje: 'Hoje',
    dom.PeriodoAbc.seteDias: 'Últimos 7 dias',
    dom.PeriodoAbc.mes: 'Últimos 30 dias',
    dom.PeriodoAbc.todos: 'Todo o Histórico',
  };

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  List<Movimentacao> _filtradas() {
    final janela = dom.JanelaPeriodo.resolver(periodo: _periodo, fuso: e.fusoLoja, relogio: const dom.RelogioSistema());
    final t = _busca.text.trim().toLowerCase();
    return e.movimentacoes.where((m) {
      final ini = janela.inicioUtc;
      final dt = m.dataHora.toUtc();
      if (ini != null && dt.isBefore(ini)) return false;
      if (dt.isAfter(janela.fimUtc)) return false;
      if (_tipo != 'TODOS' && m.tipo != _tipo) return false;
      if (t.isNotEmpty) {
        final ok = m.produtoNome.toLowerCase().contains(t) ||
            m.produtoCodigo.toLowerCase().contains(t) ||
            (m.documento ?? '').toLowerCase().contains(t) ||
            (m.observacao ?? '').toLowerCase().contains(t);
        if (!ok) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _registrar() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => _NovaMovimentacao(estado: e));
    if (ok == true && mounted) aviso(context, 'Movimentação registrada e saldo atualizado.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lista = _filtradas();
    var qEnt = 0, vEnt = 0, qSai = 0, vSai = 0;
    for (final m in lista) {
      if (m.entrada) {
        qEnt += m.quantidade;
        vEnt += centavos(m.valorTotal);
      } else {
        qSai += m.quantidade;
        vSai += centavos(m.valorTotal);
      }
    }
    final saldo = vSai - vEnt;
    final rotulo = _rotulos[_periodo]!;

    return CicPagina(children: [
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.arrowDownUp, size: 22, color: c.gold),
                  const SizedBox(width: 10),
                  Text('Histórico de Entradas & Saídas', style: TextStyle(color: c.text, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                ]),
                const SizedBox(height: 2),
                Text('Rastreabilidade de movimentações, compras e vendas por período', style: TextStyle(color: c.textMuted, fontSize: 11.5)),
              ]),
              CicBotao('Registrar Movimentação Manual', icone: LucideIcons.plus, onPressed: _registrar),
            ]),
            const SizedBox(height: 18),
            CicGrid(children: [
              _kpi(c, 'Entradas ($rotulo)', '+${inteiro(qEnt)} un', 'Investimento: ${brl(vEnt / 100)}', LucideIcons.arrowDownRight, BadgeTom.verde, c.emerald),
              _kpi(c, 'Saídas ($rotulo)', '-${inteiro(qSai)} un', 'Faturamento: ${brl(vSai / 100)}', LucideIcons.arrowUpRight, BadgeTom.neutro, const Color(0xFF60A5FA)),
              _kpi(c, 'Fluxo Movimentado', brl(saldo / 100), 'Diferença bruta no período', LucideIcons.trendingUp, saldo >= 0 ? BadgeTom.ouro : BadgeTom.vermelho, saldo >= 0 ? c.gold : c.red),
              _kpi(c, 'Total de Registros', '${lista.length} ops', 'Filtrados com precisão', LucideIcons.clock, BadgeTom.neutro, c.text),
            ]),
            const SizedBox(height: 16),
            CicCard(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(LucideIcons.calendar, size: 14, color: c.gold),
                  const SizedBox(width: 6),
                  Text('Filtrar por periodicidade:', style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in _rotulos.keys)
                    GestureDetector(
                      onTap: () => setState(() => _periodo = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _periodo == p ? c.botao : c.input,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _periodo == p ? c.botao : c.inputBorder),
                        ),
                        child: Text(_rotulos[p]!, style: TextStyle(color: _periodo == p ? Colors.black : c.textSoft, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ]),
                const SizedBox(height: 14),
                Divider(height: 1, color: c.cardBorder),
                const SizedBox(height: 14),
                Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: c.sub, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.subBorder)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _tab(c, 'TODOS', 'Todas', c.textSoft),
                      _tab(c, 'ENTRADA', 'Entradas', c.emerald),
                      _tab(c, 'SAIDA', 'Saídas', const Color(0xFF60A5FA)),
                    ]),
                  ),
                  SizedBox(
                    width: 320,
                    child: CicCampo(controller: _busca, dica: 'Buscar produto, código, documento...', icone: LucideIcons.search, onChanged: (_) => setState(() {})),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            if (e.erros.containsKey('movimentações'))
              CicErroBanner(mensagem: e.erros['movimentações']!, onTentar: e.carregar)
            else if (lista.isEmpty)
              const CicCard(child: CicVazio(icone: LucideIcons.fileText, titulo: 'Nenhuma movimentação', texto: 'Não há registros neste período/filtro.'))
            else
              CicCard(
                padding: EdgeInsets.zero,
                child: Column(children: [for (final m in lista.take(300)) _linha(c, m)]),
              ),
          ]),
        ),
      ),
    ]);
  }

  Widget _kpi(CicPalette c, String t, String v, String s, IconData i, BadgeTom tom, Color cor) => CicCard(
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(t.toUpperCase(), maxLines: 2, style: TextStyle(color: c.textMuted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4))),
        CicIconeCaixa(i, tom: tom),
      ]),
      const SizedBox(height: 10),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v, style: fonteMono(context, size: 22, cor: cor))),
      const SizedBox(height: 6),
      Text(s, style: TextStyle(color: c.textMuted, fontSize: 11)),
    ]),
  );

  Widget _tab(CicPalette c, String id, String t, Color cor) {
    final ativo = _tipo == id;
    return GestureDetector(
      onTap: () => setState(() => _tipo = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: ativo ? cor.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ativo ? cor.withValues(alpha: 0.35) : Colors.transparent),
        ),
        child: Text(t, style: TextStyle(color: ativo ? cor : c.textMuted, fontSize: 12, fontWeight: ativo ? FontWeight.w800 : FontWeight.w500)),
      ),
    );
  }

  Widget _linha(CicPalette c, Movimentacao m) {
    final cor = m.entrada ? c.emerald : const Color(0xFF60A5FA);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.isLight ? const Color(0xFFE2E8F0) : const Color(0xFF222222)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: cor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(m.entrada ? LucideIcons.arrowDownRight : LucideIcons.arrowUpRight, size: 17, color: cor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.produtoNome, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Wrap(spacing: 8, runSpacing: 2, children: [
              Text(_motivos[m.motivo] ?? m.motivo, style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w700)),
              Text(dataHora(m.dataHora), style: fonteMono(context, size: 10.5, peso: FontWeight.w400, cor: c.textMuted)),
              if ((m.documento ?? '').isNotEmpty) Text('Doc: ${m.documento}', style: fonteMono(context, size: 10.5, peso: FontWeight.w400, cor: c.textMuted)),
            ]),
            if ((m.observacao ?? '').isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 3), child: Text(m.observacao!, style: TextStyle(color: c.textMuted, fontSize: 11, fontStyle: FontStyle.italic))),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${m.entrada ? '+' : '-'}${m.quantidade} un', style: fonteMono(context, size: 13, cor: cor)),
          Text(brl(m.valorTotal), style: fonteMono(context, size: 11, peso: FontWeight.w400, cor: c.textMuted)),
        ]),
      ]),
    );
  }
}

class _NovaMovimentacao extends StatefulWidget {
  const _NovaMovimentacao({required this.estado});
  final AppState estado;

  @override
  State<_NovaMovimentacao> createState() => _NovaMovimentacaoState();
}

class _NovaMovimentacaoState extends State<_NovaMovimentacao> {
  String _tipo = 'ENTRADA';
  String _motivo = 'COMPRA_FORNECEDOR';
  String? _codigo;
  final _qtd = TextEditingController();
  final _valor = TextEditingController();
  final _doc = TextEditingController();
  final _obs = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    for (final c in [_qtd, _valor, _doc, _obs]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _motivosDoTipo => _tipo == 'ENTRADA'
      ? ['COMPRA_FORNECEDOR', 'AJUSTE_ESTOQUE', 'DEVOLUCAO']
      : ['PERDA_AVARIA', 'AJUSTE_ESTOQUE'];

  void _selecionar(String? cod) {
    setState(() => _codigo = cod);
    final p = widget.estado.estoque.where((x) => x.codigo == cod).firstOrNull;
    if (p != null) _valor.text = (_tipo == 'ENTRADA' ? p.valorCompra : p.valorVenda).toStringAsFixed(2).replaceAll('.', ',');
  }

  Future<void> _salvar() async {
    final qtd = lerInteiro(_qtd.text);
    final p = widget.estado.estoque.where((x) => x.codigo == _codigo).firstOrNull;
    if (p == null) return setState(() => _erro = 'Selecione o produto.');
    if (qtd == null || qtd <= 0) return setState(() => _erro = 'Informe uma quantidade maior que zero.');
    if (_tipo == 'SAIDA' && qtd > p.quantidade) return setState(() => _erro = 'Saída maior que o saldo (${p.quantidade} un).');
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await widget.estado.ajustarEstoque(
        codigo: p.codigo,
        delta: _tipo == 'ENTRADA' ? qtd : -qtd,
        motivo: _motivo,
        documento: _doc.text.trim().isEmpty ? null : _doc.text.trim(),
        observacao: _obs.text.trim().isEmpty ? null : _obs.text.trim(),
        valorUnitario: lerDecimal(_valor.text),
      );
      if (mounted) Navigator.pop(context, true);
    } on ErroCic catch (er) {
      if (mounted) {
        setState(() {
          _erro = er.mensagem;
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final produtos = widget.estado.estoque;
    return Dialog(
      backgroundColor: c.isLight ? Colors.white : const Color(0xFF181818),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.cardBorder)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Registrar movimentação manual', style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w800))),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(LucideIcons.x, size: 18, color: c.textMuted)),
            ]),
            const SizedBox(height: 12),
            if (_erro != null) ...[CicErroBanner(mensagem: _erro!), const SizedBox(height: 12)],
            Row(children: [
              for (final t in ['ENTRADA', 'SAIDA'])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: t == 'ENTRADA' ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _tipo = t;
                        _motivo = _motivosDoTipo.first;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _tipo == t ? c.goldBg : c.input,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _tipo == t ? c.gold : c.inputBorder),
                        ),
                        child: Text(t == 'ENTRADA' ? 'Entrada' : 'Saída', style: TextStyle(color: _tipo == t ? c.gold : c.textMuted, fontWeight: FontWeight.w800, fontSize: 12.5)),
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            Text('MOTIVO', style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: ValueKey('motivo-$_tipo'),
              initialValue: _motivo,
              isExpanded: true,
              dropdownColor: c.card,
              style: TextStyle(color: c.text, fontSize: 13),
              decoration: const InputDecoration(),
              items: [for (final m in _motivosDoTipo) DropdownMenuItem(value: m, child: Text(_motivos[m] ?? m))],
              onChanged: (v) => setState(() => _motivo = v ?? _motivo),
            ),
            const SizedBox(height: 12),
            Text('PRODUTO', style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _codigo,
              isExpanded: true,
              dropdownColor: c.card,
              hint: Text('Selecione o produto...', style: TextStyle(color: c.textMuted, fontSize: 13)),
              style: TextStyle(color: c.text, fontSize: 13),
              decoration: const InputDecoration(),
              items: [for (final p in produtos) DropdownMenuItem(value: p.codigo, child: Text('${p.nome} (${p.quantidade} un)', overflow: TextOverflow.ellipsis))],
              onChanged: _selecionar,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: CicCampo(rotulo: 'Quantidade *', controller: _qtd, teclado: TextInputType.number, dica: '0')),
              const SizedBox(width: 12),
              Expanded(child: CicCampo(rotulo: 'Valor unitário (R\$)', controller: _valor, teclado: const TextInputType.numberWithOptions(decimal: true), dica: '0,00')),
            ]),
            const SizedBox(height: 12),
            CicCampo(rotulo: 'Documento (NF, cupom, lote)', controller: _doc),
            const SizedBox(height: 12),
            CicCampo(rotulo: 'Observação', controller: _obs),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: CicBotao('Cancelar', secundario: true, onPressed: _salvando ? null : () => Navigator.pop(context))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: CicBotao('Registrar', icone: LucideIcons.check, carregando: _salvando, onPressed: _salvar)),
            ]),
          ]),
        ),
      ),
    );
  }
}
