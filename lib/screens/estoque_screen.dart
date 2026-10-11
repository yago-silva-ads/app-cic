import 'package:cic_domain/cic_domain.dart' as dom;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/shell.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';

/// Inventário (porte de `EstoqueScreen.tsx`). Toda mudança de saldo vai para o
/// banco por função atômica; a tela só mostra o que o banco devolveu.
class EstoqueScreen extends StatefulWidget {
  const EstoqueScreen({super.key, required this.estado, required this.onNavegar});
  final AppState estado;
  final void Function(NavTab, {String? codigo}) onNavegar;

  @override
  State<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends State<EstoqueScreen> {
  final _busca = TextEditingController();
  String _filtro = 'todos';
  final _ocupados = <String>{};

  AppState get e => widget.estado;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  bool _passa(Produto p) {
    final t = _busca.text.trim().toLowerCase();
    if (t.isNotEmpty &&
        !(p.nome.toLowerCase().contains(t) ||
            p.codigo.toLowerCase().contains(t) ||
            p.lote.toLowerCase().contains(t) ||
            p.categoria.toLowerCase().contains(t))) {
      return false;
    }
    return switch (_filtro) {
      'baixo' => p.estoqueBaixo,
      'validade' => (p.diasParaVencer ?? 9999) <= 30,
      'fabricado' => p.origem == 'Fabricado',
      _ => true,
    };
  }

  Future<void> _ajustar(Produto p, int delta) async {
    if (_ocupados.contains(p.codigo)) return;
    setState(() => _ocupados.add(p.codigo));
    try {
      await e.ajustarEstoque(
        codigo: p.codigo,
        delta: delta,
        motivo: 'AJUSTE_ESTOQUE',
        documento: 'AJUSTE-RAPIDO',
        observacao: delta > 0 ? 'Ajuste manual +1 na tela de estoque' : 'Ajuste manual -1 na tela de estoque',
      );
    } on ErroCic catch (er) {
      if (mounted) aviso(context, er.mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _ocupados.remove(p.codigo));
    }
  }

  Future<void> _excluir(Produto p) async {
    final ok = await confirmar(context, 'Excluir produto',
        'Tem certeza que deseja excluir "${p.nome}" do estoque? Se ele já tiver vendas, será arquivado e o histórico é mantido.',
        ok: 'Excluir', perigo: true);
    if (!ok) return;
    try {
      final apagado = await e.removerProduto(p.codigo);
      if (mounted) aviso(context, apagado ? 'Produto excluído.' : 'Produto arquivado (tem vendas no histórico).');
    } on ErroCic catch (er) {
      if (mounted) aviso(context, er.mensagem, erro: true);
    }
  }

  Future<void> _editar(Produto p) async {
    final salvo = await showDialog<bool>(context: context, builder: (_) => _EditarProduto(estado: e, original: p));
    if (salvo == true && mounted) aviso(context, 'Produto atualizado.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final resumo = const dom.EstoqueService().resumir(e.snapshot());
    var custo = 0, venda = 0;
    for (final p in e.estoque) {
      custo += centavos(p.valorCompra) * p.quantidade;
      venda += centavos(p.valorVenda) * p.quantidade;
    }
    final baixos = e.estoque.where((p) => p.estoqueBaixo).length;
    final lista = e.estoque.where(_passa).toList();

    return CicPagina(children: [
      CicGrid(minLargura: 170, espaco: 12, children: [
        _stat(context, 'Total de SKUs', '${resumo.produtosCadastrados}',
            '${resumo.produtosComSaldo} com saldo • ${inteiro(resumo.unidadesDisponiveis)} unidades'),
        _stat(context, 'Valor em Custo', brl(custo / 100), 'Patrimônio imobilizado'),
        _stat(context, 'Potencial de Venda', brl(venda / 100), 'Lucro Bruto: ${brl((venda - custo) / 100)}',
            cor: c.gold, subCor: c.emerald),
        _stat(context, 'Estoque de Atenção', '$baixos', 'Produtos no mínimo ou abaixo',
            cor: baixos > 0 ? c.amber : c.textMuted),
      ]),
      const SizedBox(height: 16),
      CicCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CicCampo(
            controller: _busca,
            dica: 'Buscar por nome, código GS1 ou lote...',
            icone: LucideIcons.search,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _filtroChip(c, 'todos', 'Todos (${e.estoque.length})', c.botao, Colors.black),
            _filtroChip(c, 'baixo', 'Estoque Baixo', const Color(0xFFF59E0B), Colors.black),
            _filtroChip(c, 'validade', 'Validade Crítica', const Color(0xFFEF4444), Colors.white),
            _filtroChip(c, 'fabricado', 'Fabricados', const Color(0xFF2563EB), Colors.white),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            CicBotao('Importar NF-e (XML)', icone: LucideIcons.fileSpreadsheet, secundario: true, compacto: true, onPressed: () => widget.onNavegar(NavTab.xml)),
            CicBotao('Cadastrar Produto', icone: LucideIcons.plus, compacto: true, onPressed: () => widget.onNavegar(NavTab.leitor)),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      if (lista.isEmpty)
        CicCard(
          child: CicVazio(
            icone: LucideIcons.boxes,
            titulo: e.estoque.isEmpty ? 'Seu estoque está vazio' : 'Nenhum produto encontrado',
            texto: e.estoque.isEmpty
                ? 'Cadastre o primeiro produto pelo leitor de código de barras ou importe uma NF-e.'
                : 'Não há produtos com esses filtros.',
          ),
        )
      else
        CicGrid(minLargura: 280, maxColunas: 4, children: [for (final p in lista) _cartao(context, p)]),
    ]);
  }

  Widget _filtroChip(CicPalette c, String id, String texto, Color bg, Color fg) {
    final ativo = _filtro == id;
    return GestureDetector(
      onTap: () => setState(() => _filtro = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: ativo ? bg : c.sub,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ativo ? bg : c.subBorder),
        ),
        child: Text(texto, style: TextStyle(color: ativo ? fg : c.textMuted, fontSize: 12, fontWeight: ativo ? FontWeight.w800 : FontWeight.w500)),
      ),
    );
  }

  Widget _stat(BuildContext context, String t, String v, String s, {Color? cor, Color? subCor}) {
    final c = context.c;
    return CicCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: TextStyle(color: c.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v, style: TextStyle(color: cor ?? c.text, fontSize: 22, fontWeight: FontWeight.w800))),
        const SizedBox(height: 4),
        Text(s, style: TextStyle(color: subCor ?? c.textMuted.withValues(alpha: 0.85), fontSize: 10, fontWeight: subCor != null ? FontWeight.w600 : FontWeight.w400)),
      ]),
    );
  }

  Widget _cartao(BuildContext context, Produto p) {
    final c = context.c;
    final lucro = p.valorVenda - p.valorCompra;
    final critico = p.quantidade <= 2;
    final baixo = p.estoqueBaixo;
    final dias = p.diasParaVencer;
    final ocupado = _ocupados.contains(p.codigo);

    Widget? validade;
    if (dias != null && dias < 0) {
      validade = CicBadge('VENCIDO (${dias.abs()}d)', tom: BadgeTom.vermelho);
    } else if (dias != null && dias <= 7) {
      validade = CicBadge('Vence em ${dias}d', tom: BadgeTom.ambar);
    }

    final borda = critico ? (c.isLight ? const Color(0xFFFCA5A5) : const Color(0x99991B1B)) : baixo ? (c.isLight ? const Color(0xFFFCD34D) : const Color(0x80854D0E)) : null;

    return CicCard(
      borda: borda,
      cor: c.isLight ? Colors.white : const Color(0xFF181818),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              CicBadge(p.categoria.isEmpty ? 'Geral' : p.categoria),
              if (p.origem == 'Fabricado') const CicBadge('Fabricado', tom: BadgeTom.ouro),
              ?validade,
              if (baixo) CicBadge(p.quantidade == 0 ? 'SEM ESTOQUE' : 'BAIXO ESTOQUE', tom: BadgeTom.ambar),
            ]),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Editar produto',
            onPressed: () => _editar(p),
            icon: Icon(LucideIcons.pencil, size: 15, color: c.textMuted),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Excluir produto',
            onPressed: () => _excluir(p),
            icon: Icon(LucideIcons.trash2, size: 15, color: c.textMuted),
          ),
        ]),
        const SizedBox(height: 6),
        Text(p.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w800, height: 1.25)),
        const SizedBox(height: 6),
        Text('EAN: ${p.codigo}  •  Lote: ${p.lote.isEmpty ? 'S/N' : p.lote}', style: fonteMono(context, size: 11, peso: FontWeight.w400, cor: c.textMuted)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.isLight ? const Color(0xFFF8FAFC) : const Color(0xFF121212),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.isLight ? c.cardBorder : const Color(0xFF222222)),
          ),
          child: Row(children: [
            _mini(c, 'Custo', brl(p.valorCompra), c.textSoft),
            _mini(c, 'Markup', '${p.markup.toStringAsFixed(2)}x', c.gold),
            _mini(c, 'Venda', brl(p.valorVenda), c.emerald),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Text('Lucro por unidade:', style: TextStyle(color: c.textMuted, fontSize: 11)),
          const Spacer(),
          Text(
            '${brl(lucro)} (${p.valorCompra > 0 ? (lucro / p.valorCompra * 100).toStringAsFixed(0) : '—'}%)',
            style: TextStyle(color: lucro >= 0 ? c.emerald : c.red, fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ]),
        const SizedBox(height: 12),
        Divider(height: 1, color: c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF242424)),
        const SizedBox(height: 12),
        Row(children: [
          Text('Estoque:', style: TextStyle(color: c.textMuted, fontSize: 12)),
          const SizedBox(width: 6),
          Text('${p.quantidade} un',
              style: fonteMono(context, size: 14, cor: critico ? const Color(0xFFEF4444) : baixo ? const Color(0xFFF59E0B) : c.text)),
          const Spacer(),
          if (ocupado)
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.gold))
          else ...[
            _quad(c, LucideIcons.minus, p.quantidade > 0 ? () => _ajustar(p, -1) : null, c.textSoft),
            const SizedBox(width: 6),
            _quad(c, LucideIcons.plus, () => _ajustar(p, 1), c.gold),
          ],
        ]),
      ]),
    );
  }

  Widget _mini(CicPalette c, String t, String v, Color cor) => Expanded(
    child: Column(children: [
      Text(t, style: TextStyle(color: c.textMuted, fontSize: 10)),
      const SizedBox(height: 2),
      FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w700))),
    ]),
  );

  Widget _quad(CicPalette c, IconData i, VoidCallback? f, Color cor) => Material(
    color: c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF242424),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: f,
      child: SizedBox(width: 30, height: 30, child: Icon(i, size: 14, color: f == null ? c.textMuted.withValues(alpha: 0.4) : cor)),
    ),
  );
}

/// Modal "Editar Produto". O saldo informado REDEFINE o estoque (com
/// movimentação de ajuste registrada no banco).
class _EditarProduto extends StatefulWidget {
  const _EditarProduto({required this.estado, required this.original});
  final AppState estado;
  final Produto original;

  @override
  State<_EditarProduto> createState() => _EditarProdutoState();
}

class _EditarProdutoState extends State<_EditarProduto> {
  late final TextEditingController _nome, _qtd, _lote, _custo, _markup, _venda;
  DateTime? _validade;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final p = widget.original;
    _nome = TextEditingController(text: p.nome);
    _qtd = TextEditingController(text: '${p.quantidade}');
    _lote = TextEditingController(text: p.lote);
    _custo = TextEditingController(text: p.valorCompra.toStringAsFixed(2).replaceAll('.', ','));
    _markup = TextEditingController(text: p.markup.toStringAsFixed(2).replaceAll('.', ','));
    _venda = TextEditingController(text: p.valorVenda.toStringAsFixed(2).replaceAll('.', ','));
    _validade = p.dataValidade;
  }

  @override
  void dispose() {
    for (final c in [_nome, _qtd, _lote, _custo, _markup, _venda]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  void _custoMudou(String _) {
    final cu = lerDecimal(_custo.text) ?? 0;
    final mk = lerDecimal(_markup.text) ?? 1;
    _venda.text = _fmt((cu * mk * 100).round() / 100);
  }

  void _markupMudou(String _) {
    final cu = lerDecimal(_custo.text) ?? 0;
    final mk = lerDecimal(_markup.text) ?? 1;
    _venda.text = _fmt((cu * mk * 100).round() / 100);
  }

  void _vendaMudou(String _) {
    final cu = lerDecimal(_custo.text) ?? 0;
    final v = lerDecimal(_venda.text) ?? 0;
    if (cu > 0) _markup.text = _fmt(v / cu);
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    final qtd = lerInteiro(_qtd.text);
    final custo = lerDecimal(_custo.text);
    final mk = lerDecimal(_markup.text);
    final venda = lerDecimal(_venda.text);
    if (nome.isEmpty) return setState(() => _erro = 'Informe o nome do produto.');
    if (qtd == null || qtd < 0) return setState(() => _erro = 'Quantidade inválida.');
    if (custo == null || custo < 0 || venda == null || venda < 0 || mk == null || mk <= 0) {
      return setState(() => _erro = 'Revise custo, markup e preço de venda.');
    }
    final p = widget.original;
    final novo = Produto(
      codigo: p.codigo,
      nome: nome,
      lote: _lote.text.trim(),
      quantidade: qtd,
      valorCompra: custo,
      markup: mk,
      valorVenda: venda,
      origem: p.origem,
      categoria: p.categoria,
      dataEntrada: p.dataEntrada,
      dataValidade: _validade,
      estoqueMinimo: p.estoqueMinimo,
      unidade: p.unidade,
    );
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await widget.estado.salvarProduto(novo, somar: false);
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
    return Dialog(
      backgroundColor: c.isLight ? Colors.white : const Color(0xFF181818),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.isLight ? c.cardBorder : const Color(0xFF2E2E2E))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Editar Produto', style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('EAN ${widget.original.codigo}', style: fonteMono(context, size: 11, peso: FontWeight.w400, cor: c.textMuted)),
            const SizedBox(height: 16),
            if (_erro != null) ...[CicErroBanner(mensagem: _erro!), const SizedBox(height: 12)],
            CicCampo(rotulo: 'Nome', controller: _nome),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: CicCampo(rotulo: 'Saldo em estoque', controller: _qtd, teclado: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: CicCampo(rotulo: 'Lote', controller: _lote)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: CicCampo(rotulo: 'Custo (R\$)', controller: _custo, teclado: const TextInputType.numberWithOptions(decimal: true), onChanged: _custoMudou)),
              const SizedBox(width: 10),
              Expanded(child: CicCampo(rotulo: 'Markup', controller: _markup, teclado: const TextInputType.numberWithOptions(decimal: true), onChanged: _markupMudou)),
              const SizedBox(width: 10),
              Expanded(child: CicCampo(rotulo: 'Venda (R\$)', controller: _venda, teclado: const TextInputType.numberWithOptions(decimal: true), onChanged: _vendaMudou)),
            ]),
            const SizedBox(height: 12),
            Text('DATA DE VALIDADE', style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _validade ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _validade = d);
                  },
                  icon: Icon(LucideIcons.calendar, size: 15, color: c.gold),
                  label: Text(_validade == null ? 'Sem validade' : dataCurta(_validade), style: TextStyle(color: c.text)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: c.inputBorder), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              if (_validade != null) IconButton(onPressed: () => setState(() => _validade = null), icon: Icon(LucideIcons.x, size: 16, color: c.textMuted)),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: CicBotao('Cancelar', secundario: true, onPressed: _salvando ? null : () => Navigator.pop(context, false))),
              const SizedBox(width: 10),
              Expanded(child: CicBotao('Salvar Alterações', carregando: _salvando, onPressed: _salvar)),
            ]),
          ]),
        ),
      ),
    );
  }
}
