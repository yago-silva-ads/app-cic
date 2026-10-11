import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/auth_service.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';

const _categorias = {
  'Geral': 'Geral',
  'Imóvel': 'Imóvel / Ponto Comercial',
  'Utilidades': 'Utilidades (Luz, Água, Gás)',
  'Telecom': 'Telecom & Internet',
  'Financeiro': 'Taxas Financeiras / Maquininha',
  'Embalagens': 'Embalagens & Sacolas',
  'Logística': 'Frete & Logística',
  'Serviços': 'Honorários e Contabilidade',
  'Impostos': 'Impostos / DAS MEI',
};

/// Custos & despesas (porte de `CustosScreen.tsx`), gravados por loja no banco.
class CustosScreen extends StatefulWidget {
  const CustosScreen({super.key, required this.estado});
  final AppState estado;

  @override
  State<CustosScreen> createState() => _CustosScreenState();
}

class _CustosScreenState extends State<CustosScreen> {
  final _nome = TextEditingController();
  final _valor = TextEditingController();
  final _obs = TextEditingController();
  TipoCusto _tipo = TipoCusto.fixo;
  String _categoria = 'Geral';
  String? _editandoId;
  String _aba = 'TODOS';
  bool _salvando = false;

  AppState get e => widget.estado;

  @override
  void dispose() {
    _nome.dispose();
    _valor.dispose();
    _obs.dispose();
    super.dispose();
  }

  void _limpar() {
    _nome.clear();
    _valor.clear();
    _obs.clear();
    _tipo = TipoCusto.fixo;
    _categoria = 'Geral';
    _editandoId = null;
  }

  Future<void> _salvar() async {
    final nome = AuthService.limpar(_nome.text, 120);
    final valor = lerDecimal(_valor.text);
    if (nome.isEmpty || valor == null || valor <= 0) {
      aviso(context, 'Informe a descrição e um valor maior que zero.', erro: true);
      return;
    }
    setState(() => _salvando = true);
    try {
      await e.salvarCusto(CustoOperacional(
        id: _editandoId,
        nome: nome,
        valor: valor,
        tipo: _tipo,
        categoria: _categoria,
        observacao: _obs.text.trim().isEmpty ? null : AuthService.limpar(_obs.text, 200),
      ));
      if (mounted) {
        setState(_limpar);
        aviso(context, 'Despesa salva.');
      }
    } on ErroCic catch (er) {
      if (mounted) aviso(context, er.mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluir(CustoOperacional k) async {
    if (k.id == null) return;
    final ok = await confirmar(context, 'Excluir despesa', 'Remover "${k.nome}"?', ok: 'Excluir', perigo: true);
    if (!ok) return;
    try {
      await e.removerCusto(k.id!);
    } on ErroCic catch (er) {
      if (mounted) aviso(context, er.mensagem, erro: true);
    }
  }

  IconData _icone(String nome, String? cat) {
    final t = '$nome ${cat ?? ''}'.toLowerCase();
    if (t.contains('cartão') || t.contains('maquininha') || t.contains('taxa')) return LucideIcons.creditCard;
    if (t.contains('embalagem') || t.contains('sacola') || t.contains('caixa')) return LucideIcons.package;
    if (t.contains('frete') || t.contains('entrega') || t.contains('delivery')) return LucideIcons.truck;
    if (t.contains('aluguel') || t.contains('condomínio') || t.contains('imóvel')) return LucideIcons.building;
    if (t.contains('energia') || t.contains('luz')) return LucideIcons.zap;
    if (t.contains('internet') || t.contains('fibra') || t.contains('telefone')) return LucideIcons.wifi;
    if (t.contains('salário') || t.contains('funcionário') || t.contains('comissão')) return LucideIcons.users;
    return LucideIcons.dollarSign;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    var fixos = 0, variaveis = 0;
    for (final k in e.custos) {
      if (k.tipo == TipoCusto.variavel) {
        variaveis += centavos(k.valor);
      } else {
        fixos += centavos(k.valor);
      }
    }
    final total = fixos + variaveis;
    final lista = e.custos.where((k) {
      if (_aba == 'TODOS') return true;
      return (_aba == 'FIXO') == (k.tipo == TipoCusto.fixo);
    }).toList();
    const roxo = Color(0xFFA855F7);
    const azul = Color(0xFF3B82F6);

    return CicPagina(children: [
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CicGrid(children: [
              _kpi(c, 'Custos Fixos Mensais', brl(fixos / 100), 'Aluguel, luz, salários e contas fixas', LucideIcons.trendingDown, BadgeTom.vermelho, c.text),
              _kpi(c, 'Despesas Variáveis', brl(variaveis / 100), 'Taxas de cartão, sacolas e fretes', LucideIcons.percent, BadgeTom.neutro, roxo),
              _kpi(c, 'Total Operacional', brl(total / 100), 'Fixos + despesas variáveis estimadas', LucideIcons.dollarSign, BadgeTom.ouro, c.gold),
              _kpi(c, 'Meta Diária de Sobrevivência', '${brl(fixos / 100 / 30)}/dia', 'Lucro diário mínimo para não ter prejuízo', LucideIcons.zap, BadgeTom.ambar, c.amber),
            ]),
            const SizedBox(height: 20),
            CicCard(
              padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(LucideIcons.plus, size: 16, color: c.gold),
                  const SizedBox(width: 8),
                  Text(_editandoId != null ? 'EDITAR DESPESA OPERACIONAL' : 'CADASTRAR NOVA DESPESA (FIXA OU VARIÁVEL)', style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                ]),
                const SizedBox(height: 16),
                Text('CLASSIFICAÇÃO DA DESPESA *', style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                const SizedBox(height: 8),
                CicGrid(minLargura: 260, espaco: 12, maxColunas: 2, children: [
                  _tipoCard(c, TipoCusto.fixo, 'Custo Fixo (Estrutura)', 'Todo mês, independente das vendas (aluguel, luz, internet, salários).', LucideIcons.building, azul),
                  _tipoCard(c, TipoCusto.variavel, 'Despesa Variável (Giro)', 'Cresce com as vendas (taxas de maquininha, embalagens, fretes).', LucideIcons.percent, roxo),
                ]),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (context, b) {
                  final nome = CicCampo(rotulo: 'Descrição da despesa *', controller: _nome, dica: _tipo == TipoCusto.fixo ? 'Ex: Aluguel da loja' : 'Ex: Taxas de maquininha e cartão');
                  final valor = CicCampo(rotulo: 'Valor médio mensal (R\$) *', controller: _valor, dica: '0,00', teclado: const TextInputType.numberWithOptions(decimal: true));
                  if (b.maxWidth < 560) return Column(children: [nome, const SizedBox(height: 14), valor]);
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: nome), const SizedBox(width: 14), Expanded(child: valor)]);
                }),
                const SizedBox(height: 14),
                LayoutBuilder(builder: (context, b) {
                  final cat = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('CATEGORIA DA DESPESA', style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _categorias.containsKey(_categoria) ? _categoria : 'Geral',
                      isExpanded: true,
                      dropdownColor: c.card,
                      style: TextStyle(color: c.text, fontSize: 13),
                      decoration: const InputDecoration(),
                      items: [for (final en in _categorias.entries) DropdownMenuItem(value: en.key, child: Text(en.value))],
                      onChanged: (v) => setState(() => _categoria = v ?? 'Geral'),
                    ),
                  ]);
                  final obs = CicCampo(rotulo: 'Observação / detalhe', controller: _obs, dica: 'Ex: média de 2,5% sobre o faturamento');
                  if (b.maxWidth < 560) return Column(children: [cat, const SizedBox(height: 14), obs]);
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: cat), const SizedBox(width: 14), Expanded(child: obs)]);
                }),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (_editandoId != null) ...[
                    CicBotao('Cancelar', secundario: true, compacto: true, onPressed: () => setState(_limpar)),
                    const SizedBox(width: 8),
                  ],
                  CicBotao(_editandoId != null ? 'Atualizar Despesa' : 'Salvar Despesa', icone: LucideIcons.plus, carregando: _salvando, onPressed: _salvar),
                ]),
              ]),
            ),
            const SizedBox(height: 20),
            CicCard(
              padding: EdgeInsets.zero,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('QUADRO DE CUSTOS E DESPESAS', style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w800)),
                      Text('${lista.length} contas cadastradas', style: TextStyle(color: c.textMuted, fontSize: 11.5)),
                    ]),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: c.sub, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.subBorder)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        _filtro(c, 'TODOS', 'Todas (${e.custos.length})', c.textSoft),
                        _filtro(c, 'FIXO', 'Fixos (${e.custos.where((k) => k.tipo == TipoCusto.fixo).length})', azul),
                        _filtro(c, 'VARIAVEL', 'Variáveis (${e.custos.where((k) => k.tipo == TipoCusto.variavel).length})', roxo),
                      ]),
                    ),
                  ]),
                ),
                Divider(height: 1, color: c.cardBorder),
                if (lista.isEmpty)
                  const CicVazio(icone: LucideIcons.receipt, titulo: 'Nenhuma despesa', texto: 'Use o formulário acima para cadastrar.')
                else
                  for (final k in lista) _linhaCusto(c, k, roxo, azul),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _kpi(CicPalette c, String t, String v, String s, IconData i, BadgeTom tom, Color cor) => CicCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(t.toUpperCase(), style: TextStyle(color: c.textMuted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
        CicIconeCaixa(i, tom: tom),
      ]),
      const SizedBox(height: 10),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v, style: fonteMono(context, size: 22, cor: cor))),
      const SizedBox(height: 6),
      Text(s, style: TextStyle(color: c.textMuted, fontSize: 11)),
    ]),
  );

  Widget _tipoCard(CicPalette c, TipoCusto t, String titulo, String desc, IconData i, Color cor) {
    final ativo = _tipo == t;
    return GestureDetector(
      onTap: () => setState(() => _tipo = t),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ativo ? cor.withValues(alpha: 0.10) : c.input,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ativo ? cor : c.inputBorder),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: ativo ? cor : c.sub, borderRadius: BorderRadius.circular(9)),
            child: Icon(i, size: 16, color: ativo ? Colors.white : c.textMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(desc, style: TextStyle(color: c.textMuted, fontSize: 11, height: 1.3)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _filtro(CicPalette c, String id, String t, Color cor) {
    final ativo = _aba == id;
    return GestureDetector(
      onTap: () => setState(() => _aba = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: ativo ? cor.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ativo ? cor.withValues(alpha: 0.35) : Colors.transparent),
        ),
        child: Text(t, style: TextStyle(color: ativo ? cor : c.textMuted, fontSize: 11.5, fontWeight: ativo ? FontWeight.w800 : FontWeight.w500)),
      ),
    );
  }

  Widget _linhaCusto(CicPalette c, CustoOperacional k, Color roxo, Color azul) {
    final variavel = k.tipo == TipoCusto.variavel;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.isLight ? const Color(0xFFE2E8F0) : const Color(0xFF222222)))),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: variavel ? roxo.withValues(alpha: 0.15) : (c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF222222)),
            borderRadius: BorderRadius.circular(12),
            border: variavel ? Border.all(color: roxo.withValues(alpha: 0.3)) : null,
          ),
          child: Icon(_icone(k.nome, k.categoria), size: 16, color: variavel ? roxo : c.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(k.nome, style: TextStyle(color: c.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
              _tag(variavel ? 'VARIÁVEL' : 'FIXO', variavel ? roxo : azul),
              if ((k.categoria ?? '').isNotEmpty) Text(k.categoria!, style: TextStyle(color: c.textMuted, fontSize: 10)),
            ]),
            const SizedBox(height: 3),
            Text('${brl(k.valor / 30)} por dia (base mensal)${(k.observacao ?? '').isNotEmpty ? ' • ${k.observacao}' : ''}',
                style: TextStyle(color: c.textMuted, fontSize: 11)),
          ]),
        ),
        Text(brl(k.valor), style: fonteMono(context, size: 13)),
        IconButton(
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() {
            _editandoId = k.id;
            _nome.text = k.nome;
            _valor.text = k.valor.toStringAsFixed(2).replaceAll('.', ',');
            _obs.text = k.observacao ?? '';
            _tipo = k.tipo;
            _categoria = _categorias.containsKey(k.categoria) ? k.categoria! : 'Geral';
          }),
          icon: Icon(LucideIcons.pencil, size: 15, color: c.textMuted),
        ),
        IconButton(tooltip: 'Excluir', visualDensity: VisualDensity.compact, onPressed: () => _excluir(k), icon: Icon(LucideIcons.trash2, size: 15, color: c.textMuted)),
      ]),
    );
  }

  Widget _tag(String t, Color cor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: cor.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6), border: Border.all(color: cor.withValues(alpha: 0.3))),
    child: Text(t, style: TextStyle(color: cor, fontSize: 10, fontWeight: FontWeight.w800)),
  );
}
