import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/format.dart';
import '../core/gs1.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../services/analise_mercado.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';

/// Leitor de códigos e cadastro.
///
/// Diferenças deliberadas em relação ao protótipo:
///  * Não inventa custo, lote nem validade: só preenche o que a base de
///    produtos devolve (nome/categoria).
///  * Produto já cadastrado: a quantidade digitada é SOMADA ao saldo (entrada
///    de mercadoria), a menos que se marque "substituir saldo".
class LeitorScreen extends StatefulWidget {
  const LeitorScreen({
    super.key,
    required this.estado,
    this.codigoInicial,
    required this.onAbrirScanner,
    required this.onSalvo,
  });

  final AppState estado;
  final String? codigoInicial;
  final Future<void> Function([ValueChanged<String>? aoLer]) onAbrirScanner;
  final VoidCallback onSalvo;

  @override
  State<LeitorScreen> createState() => _LeitorScreenState();
}

class _LeitorScreenState extends State<LeitorScreen> {
  final _codigo = TextEditingController();
  final _nome = TextEditingController();
  final _categoria = TextEditingController(text: 'Geral');
  final _lote = TextEditingController();
  final _qtd = TextEditingController();
  final _custo = TextEditingController();
  final _markup = TextEditingController(text: '2,00');
  final _venda = TextEditingController();

  DateTime? _validade;
  String _origem = 'Revendido';
  bool _buscando = false;
  bool _salvando = false;
  bool _substituir = false;
  bool _precoMercadoAplicado = false;
  Produto? _existente;
  ({String tipo, String texto})? _msg;
  final List<({String codigo, int qtd})> _insumos = [];

  AppState get e => widget.estado;

  @override
  void initState() {
    super.initState();
    final c = widget.codigoInicial;
    if (c != null && c.isNotEmpty) {
      _codigo.text = c;
      WidgetsBinding.instance.addPostFrameCallback((_) => _consultar(c));
    }
  }

  @override
  void dispose() {
    for (final c in [_codigo, _nome, _categoria, _lote, _qtd, _custo, _markup, _venda]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  double get _markupNum => lerDecimal(_markup.text) ?? 0;
  bool get _margemBaixa => _markupNum > 0 && _markupNum < 1.3;

  void _recalcularVenda() {
    final cu = lerDecimal(_custo.text) ?? 0;
    final mk = lerDecimal(_markup.text) ?? 0;
    if (cu > 0 && mk > 0 && !_precoMercadoAplicado) _venda.text = _fmt((cu * mk * 100).round() / 100);
    setState(() {});
  }

  void _custoMudou() {
    if (_precoMercadoAplicado) {
      final cu = lerDecimal(_custo.text) ?? 0;
      final v = lerDecimal(_venda.text) ?? 0;
      if (cu > 0 && v > 0) _markup.text = _fmt(v / cu);
      setState(() {});
      return;
    }
    _recalcularVenda();
  }

  void _vendaMudou() {
    _precoMercadoAplicado = false;
    final cu = lerDecimal(_custo.text) ?? 0;
    final v = lerDecimal(_venda.text) ?? 0;
    if (cu > 0 && v > 0) _markup.text = _fmt(v / cu);
    setState(() {});
  }

  void _recalcularCustoInsumos() {
    var total = 0.0;
    for (final i in _insumos) {
      final p = e.estoque.where((x) => x.codigo == i.codigo).firstOrNull;
      if (p != null) total += p.valorCompra * i.qtd;
    }
    if (total > 0) {
      _custo.text = _fmt(total);
      _recalcularVenda();
    }
  }

  Future<void> _consultar(String bruto) async {
    final cod = bruto.trim();
    if (cod.isEmpty) return;

    final existente = e.estoque.where((p) => p.codigo == cod).firstOrNull;
    if (existente != null) {
      setState(() {
        _existente = existente;
        _nome.text = existente.nome;
        _categoria.text = existente.categoria;
        _lote.text = existente.lote;
        _qtd.text = '';
        _custo.text = _fmt(existente.valorCompra);
        _markup.text = _fmt(existente.markup);
        _venda.text = _fmt(existente.valorVenda);
        _origem = existente.origem == 'Fabricado' ? 'Fabricado' : 'Revendido';
        _validade = existente.dataValidade;
        _precoMercadoAplicado = false;
        _substituir = false;
        _msg = (tipo: 'info', texto: 'Produto já cadastrado: saldo atual de ${existente.quantidade} un. Informe a quantidade que está ENTRANDO para somar ao saldo.');
      });
      return;
    }

    setState(() {
      _existente = null;
      _buscando = true;
      _msg = null;
    });
    final r = await consultarGs1(cod);
    if (!mounted) return;
    setState(() {
      _buscando = false;
      if (r.encontrado) {
        _nome.text = r.nome ?? '';
        if ((r.categoria ?? '').isNotEmpty) _categoria.text = r.categoria!;
        _msg = (tipo: 'sucesso', texto: 'Produto identificado via ${r.origem}: "${r.nome}". Confira o nome e informe custo, quantidade e validade.');
      } else {
        _msg = (tipo: 'info', texto: r.mensagem ?? 'Código lido. Preencha o nome do produto.');
      }
      if (!gtinValido(cod) && RegExp(r'^\d+$').hasMatch(cod)) {
        _msg = (tipo: 'info', texto: 'Atenção: o dígito verificador do código $cod não confere com o padrão GS1. Confira se digitou certo.');
      }
    });
    if (r.encontrado && (r.nome ?? '').isNotEmpty) {
      try {
        final consulta = await AnaliseMercadoService().buscarOfertas(nome: r.nome!, codigo: cod);
        final precos = consulta.ofertas.map((o) => o.precoCentavos).where((v) => v > 0).toList()..sort();
        if (precos.length >= 2 && mounted) {
          final mediana = precos.length.isOdd ? precos[precos.length ~/ 2] : (precos[precos.length ~/ 2 - 1] + precos[precos.length ~/ 2]) ~/ 2;
          setState(() {
            _venda.text = _fmt(mediana / 100);
            _precoMercadoAplicado = true;
            _msg = (tipo: 'sucesso', texto: 'Produto identificado. Preço sugerido pela mediana de ${precos.length} ofertas públicas: ${brl(mediana / 100)}. Confira custo, margem e validade do lote antes de salvar.');
          });
        }
      } catch (_) {
        // O cadastro segue funcionando mesmo quando a pesquisa externa falha.
      }
    }
  }

  Future<void> _abrirCamera() => widget.onAbrirScanner((c) {
    setState(() => _codigo.text = c);
    _consultar(c);
  });

  void _limpar() {
    setState(() {
      for (final c in [_codigo, _nome, _lote, _qtd, _custo, _venda]) {
        c.clear();
      }
      _categoria.text = 'Geral';
      _markup.text = '2,00';
      _validade = null;
      _origem = 'Revendido';
      _existente = null;
      _precoMercadoAplicado = false;
      _substituir = false;
      _insumos.clear();
      _msg = null;
    });
  }

  Future<void> _salvar() async {
    final cod = _codigo.text.trim();
    if (cod.isEmpty) return setState(() => _msg = (tipo: 'erro', texto: 'Informe ou bipe o código de barras do produto.'));
    if (_nome.text.trim().isEmpty) return setState(() => _msg = (tipo: 'erro', texto: 'Informe o nome/descrição do produto.'));
    final qtd = lerInteiro(_qtd.text);
    if (qtd == null || qtd < 0) return setState(() => _msg = (tipo: 'erro', texto: 'Informe a quantidade (número inteiro, 0 ou mais).'));
    final custo = lerDecimal(_custo.text);
    if (custo == null || custo < 0) return setState(() => _msg = (tipo: 'erro', texto: 'Informe o custo unitário.'));
    final mk = lerDecimal(_markup.text) ?? 1.3;
    final venda = lerDecimal(_venda.text) ?? custo * mk;
    if (venda < 0) return setState(() => _msg = (tipo: 'erro', texto: 'Preço de venda inválido.'));

    final p = Produto(
      codigo: cod,
      nome: _nome.text.trim(),
      lote: _lote.text.trim(),
      quantidade: qtd,
      valorCompra: custo,
      markup: mk,
      valorVenda: venda,
      origem: _origem,
      categoria: _categoria.text.trim().isEmpty ? 'Geral' : _categoria.text.trim(),
      dataEntrada: DateTime.now(),
      dataValidade: _validade,
      estoqueMinimo: _existente?.estoqueMinimo ?? 5,
    );

    setState(() {
      _salvando = true;
      _msg = null;
    });
    try {
      final saldo = await e.salvarProduto(p, somar: _existente != null ? !_substituir : true);
      if (!mounted) return;
      aviso(context, 'Produto "${p.nome}" salvo. Saldo atual: $saldo un.');
      widget.onSalvo();
    } on ErroCic catch (er) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _msg = (tipo: 'erro', texto: er.mensagem);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final revendidos = e.estoque.where((p) => p.origem != 'Fabricado').toList();
    return CicPagina(children: [
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: CicCard(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  CicIconeCaixa(LucideIcons.camera, tom: BadgeTom.ouro, tamanho: 42),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Captura de Código de Barras GS1', style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('Aponte a câmera para o GTIN/EAN ou digite o código', style: TextStyle(color: c.textMuted, fontSize: 11.5)),
                  ]),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  CicBotao('Abrir câmera / bipador', icone: LucideIcons.camera, compacto: true, onPressed: _abrirCamera),
                  const SizedBox(width: 8),
                  CicBotao('Limpar', secundario: true, compacto: true, onPressed: _limpar),
                ]),
              ]),
              const SizedBox(height: 14),
              Divider(color: c.cardBorder),
              if (_msg != null) ...[const SizedBox(height: 12), _banner(c, _msg!)],
              const SizedBox(height: 16),
              _linha([
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: CicCampo(
                        rotulo: 'Código de barras (GTIN-13 / EAN-13) *',
                        controller: _codigo,
                        dica: 'Ex: 7891721201806',
                        teclado: TextInputType.number,
                        onSubmitted: _consultar,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: CicBotao(_buscando ? '...' : 'Consultar', icone: LucideIcons.search, secundario: true, onPressed: _buscando ? null : () => _consultar(_codigo.text)),
                    ),
                  ]),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TIPO DO PRODUTO', style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: _tipoBtn(c, 'Revendido')),
                    const SizedBox(width: 8),
                    Expanded(child: _tipoBtn(c, 'Fabricado')),
                  ]),
                ]),
              ], pesos: const [2, 1]),
              _linha([
                CicCampo(rotulo: 'Nome / descrição do produto *', controller: _nome, dica: 'Ex: GLIFAGE XR 500MG TAB RM (30)'),
                CicCampo(rotulo: 'Categoria', controller: _categoria, dica: 'Ex: Medicamentos, Bebidas'),
              ], pesos: const [2, 1]),
              _linha([
                CicCampo(rotulo: 'Número do lote', controller: _lote, dica: 'Ex: L-2026A'),
                CicCampo(
                  rotulo: _existente == null ? 'Quantidade em estoque *' : 'Quantidade que está entrando *',
                  controller: _qtd,
                  teclado: TextInputType.number,
                  dica: '0',
                  onChanged: (_) => setState(() {}),
                ),
                _campoValidade(c),
              ]),
              if (_existente != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: c.sub, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.subBorder)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _substituir,
                      activeThumbColor: c.gold,
                      onChanged: (v) => setState(() => _substituir = v),
                      title: Text('Substituir o saldo (contagem de inventário)', style: TextStyle(color: c.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                    Text(
                      () {
                        final q = lerInteiro(_qtd.text);
                        final atual = _existente!.quantidade;
                        if (q == null) return 'Saldo atual: $atual un.';
                        return _substituir ? 'Saldo ficará em $q un (era $atual).' : 'Saldo ficará em ${atual + q} un ($atual + $q).';
                      }(),
                      style: TextStyle(color: c.gold, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
              ],
              if (_origem == 'Fabricado') _blocoInsumos(c, revendidos),
              _blocoPreco(c),
              const SizedBox(height: 16),
              CicBotao(
                _margemBaixa ? 'ATENÇÃO: salvar com risco de margem baixa' : 'Salvar no estoque',
                icone: _margemBaixa ? LucideIcons.triangleAlert : LucideIcons.circleCheck,
                perigo: _margemBaixa,
                largo: true,
                carregando: _salvando,
                onPressed: _salvar,
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _linha(List<Widget> filhos, {List<int>? pesos}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: LayoutBuilder(builder: (context, b) {
      if (b.maxWidth < 560) {
        return Column(children: [for (final f in filhos) Padding(padding: const EdgeInsets.only(bottom: 14), child: f)]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < filhos.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(flex: pesos?[i] ?? 1, child: filhos[i]),
        ],
      ]);
    }),
  );

  Widget _tipoBtn(CicPalette c, String t) {
    final ativo = _origem == t;
    return GestureDetector(
      onTap: () => setState(() => _origem = t),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ativo ? c.goldBg : c.input,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ativo ? c.gold : c.inputBorder),
        ),
        child: Text(t, style: TextStyle(color: ativo ? c.gold : c.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _campoValidade(CicPalette c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('DATA DE VALIDADE (FIFO)', style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
    const SizedBox(height: 6),
    Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _validade ?? DateTime.now().add(const Duration(days: 90)),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null) setState(() => _validade = d);
          },
          icon: Icon(LucideIcons.calendar, size: 15, color: c.gold),
          label: Text(_validade == null ? 'Sem validade' : dataCurta(_validade), style: TextStyle(color: c.text, fontSize: 13)),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            side: BorderSide(color: c.inputBorder),
            backgroundColor: c.input,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      if (_validade != null) IconButton(onPressed: () => setState(() => _validade = null), icon: Icon(LucideIcons.x, size: 16, color: c.textMuted)),
    ]),
  ]);

  Widget _banner(CicPalette c, ({String tipo, String texto}) m) {
    final (cor, icone) = switch (m.tipo) {
      'sucesso' => (c.emerald, LucideIcons.circleCheck),
      'erro' => (c.red, LucideIcons.triangleAlert),
      _ => (const Color(0xFF60A5FA), LucideIcons.sparkles),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: cor.withValues(alpha: 0.4))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone, size: 16, color: cor),
        const SizedBox(width: 10),
        Expanded(child: Text(m.texto, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600, height: 1.35))),
      ]),
    );
  }

  Widget _blocoInsumos(CicPalette c, List<Produto> revendidos) {
    final disponiveis = revendidos.where((p) => !_insumos.any((i) => i.codigo == p.codigo)).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.sub, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.amberBorder.withValues(alpha: 0.6))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(LucideIcons.layers, size: 15, color: c.amber),
          const SizedBox(width: 8),
          Expanded(child: Text('Insumos do combo fabricado', style: TextStyle(color: c.amber, fontSize: 12, fontWeight: FontWeight.w800))),
          Text('Custo = soma dos insumos', style: TextStyle(color: c.textMuted, fontSize: 10.5)),
        ]),
        const SizedBox(height: 10),
        if (revendidos.isEmpty)
          Text('Cadastre produtos revendidos primeiro para compor os insumos.', style: TextStyle(color: c.textMuted, fontSize: 12))
        else ...[
          DropdownButtonFormField<String>(
            key: ValueKey('insumo-${_insumos.length}'),
            initialValue: null,
            isExpanded: true,
            dropdownColor: c.card,
            hint: Text('Adicionar insumo do estoque...', style: TextStyle(color: c.textMuted, fontSize: 12.5)),
            style: TextStyle(color: c.text, fontSize: 12.5),
            decoration: const InputDecoration(),
            items: [for (final p in disponiveis) DropdownMenuItem(value: p.codigo, child: Text('${p.nome} (custo ${brl(p.valorCompra)})', overflow: TextOverflow.ellipsis))],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _insumos.add((codigo: v, qtd: 1)));
              _recalcularCustoInsumos();
            },
          ),
          for (var i = 0; i < _insumos.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Expanded(child: Text(e.estoque.where((x) => x.codigo == _insumos[i].codigo).firstOrNull?.nome ?? _insumos[i].codigo, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontSize: 12))),
                IconButton(visualDensity: VisualDensity.compact, onPressed: _insumos[i].qtd > 1 ? () { setState(() => _insumos[i] = (codigo: _insumos[i].codigo, qtd: _insumos[i].qtd - 1)); _recalcularCustoInsumos(); } : null, icon: Icon(LucideIcons.minus, size: 14, color: c.textSoft)),
                Text('${_insumos[i].qtd}', style: fonteMono(context, size: 12)),
                IconButton(visualDensity: VisualDensity.compact, onPressed: () { setState(() => _insumos[i] = (codigo: _insumos[i].codigo, qtd: _insumos[i].qtd + 1)); _recalcularCustoInsumos(); }, icon: Icon(LucideIcons.plus, size: 14, color: c.gold)),
                IconButton(visualDensity: VisualDensity.compact, onPressed: () { setState(() => _insumos.removeAt(i)); _recalcularCustoInsumos(); }, icon: Icon(LucideIcons.x, size: 14, color: c.red)),
              ]),
            ),
        ],
      ]),
    );
  }

  Widget _blocoPreco(CicPalette c) {
    final risco = _margemBaixa;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: risco ? c.redBg : c.sub,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: risco ? c.redBorder : c.subBorder),
        boxShadow: risco && !c.isLight ? [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.15), blurRadius: 15)] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('PRECIFICAÇÃO & MARGEM ANTI-FALÊNCIA', style: TextStyle(color: risco ? c.red : c.gold, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
        ]),
        const SizedBox(height: 4),
        Text('Fórmula: Venda = Custo × Markup', style: TextStyle(color: c.textMuted, fontSize: 11)),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, b) {
          final campos = [
            CicCampo(rotulo: 'Custo unitário (R\$) *', controller: _custo, teclado: const TextInputType.numberWithOptions(decimal: true), dica: '0,00', onChanged: (_) => _custoMudou()),
            CicCampo(rotulo: 'Markup (multiplicador)', controller: _markup, teclado: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) { _precoMercadoAplicado = false; _recalcularVenda(); }),
            CicCampo(rotulo: 'Preço de venda (R\$)', controller: _venda, teclado: const TextInputType.numberWithOptions(decimal: true), dica: '0,00', onChanged: (_) => _vendaMudou()),
          ];
          if (b.maxWidth < 560) return Column(children: [for (final f in campos) Padding(padding: const EdgeInsets.only(bottom: 12), child: f)]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < campos.length; i++) ...[if (i > 0) const SizedBox(width: 14), Expanded(child: campos[i])],
          ]);
        }),
        Text('Ex: 2,00 = 100% de lucro sobre o custo', style: TextStyle(color: c.textMuted, fontSize: 10.5)),
        if (risco)
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.redBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.redBorder)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(LucideIcons.triangleAlert, size: 16, color: c.red),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(TextSpan(style: TextStyle(color: c.red, fontSize: 12, height: 1.4), children: const [
                  TextSpan(text: 'Risco de prejuízo (limitador anti-falência). ', style: TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: 'Markup abaixo de 1,30x (margem menor que 30%) dificilmente cobre os custos fixos (aluguel, luz, taxas de cartão). Recomendamos no mínimo 1,50x ou 2,00x.'),
                ])),
              ),
            ]),
          ),
      ]),
    );
  }
}
