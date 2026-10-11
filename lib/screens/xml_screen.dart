import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/format.dart';
import '../core/nfe_parser.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';

class _Linha {
  _Linha(this.item, double markup, Produto? existente)
    : selecionado = item.avisos.every((a) => !a.startsWith('Item incompleto')) && item.quantidadeInteira,
      codigo = TextEditingController(text: item.codigoBarras),
      qtd = TextEditingController(text: item.quantidadeInteira ? item.quantidade.toInt().toString() : ''),
      custo = TextEditingController(text: _fmt(item.valorUnitario)),
      venda = TextEditingController(text: _fmt(existente?.valorVenda ?? item.valorUnitario * markup));

  final ItemNfe item;
  bool selecionado;
  final TextEditingController codigo, qtd, custo, venda;

  static String _fmt(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  void dispose() {
    for (final c in [codigo, qtd, custo, venda]) {
      c.dispose();
    }
  }
}

/// Importador de XML de NF-e (porte de `XmlScreen.tsx`). Cada item vira uma
/// entrada de estoque identificada pelo documento da nota: a mesma nota não
/// entra duas vezes, mesmo que a importação seja refeita após uma falha.
class XmlScreen extends StatefulWidget {
  const XmlScreen({super.key, required this.estado, required this.onConcluido});
  final AppState estado;
  final VoidCallback onConcluido;

  @override
  State<XmlScreen> createState() => _XmlScreenState();
}

class _XmlScreenState extends State<XmlScreen> {
  NotaFiscal? _nota;
  List<_Linha> _linhas = [];
  String? _erro;
  String? _resultado;
  double _markup = 1.6;
  bool _atualizarPrecos = false;
  bool _importando = false;
  bool _colar = false;
  bool _copiada = false;
  final _texto = TextEditingController();

  AppState get e => widget.estado;

  @override
  void dispose() {
    _texto.dispose();
    for (final l in _linhas) {
      l.dispose();
    }
    super.dispose();
  }

  Produto? _existente(String codigo) => e.estoque.where((p) => p.codigo == codigo.trim()).firstOrNull;

  void _processar(String xml) {
    for (final l in _linhas) {
      l.dispose();
    }
    setState(() {
      _erro = null;
      _resultado = null;
    });
    try {
      final nota = interpretarNfe(xml);
      setState(() {
        _nota = nota;
        _linhas = [for (final i in nota.itens) _Linha(i, _markup, _existente(i.codigoBarras))];
      });
    } on ErroNfe catch (er) {
      setState(() {
        _nota = null;
        _linhas = [];
        _erro = er.mensagem;
      });
    }
  }

  Future<void> _escolherArquivo() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['xml'], withData: true);
      final bytes = r?.files.single.bytes;
      if (bytes == null) return;
      _processar(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      setState(() => _erro = 'Não foi possível ler o arquivo selecionado.');
    }
  }

  void _novoMarkup(double m) {
    setState(() {
      _markup = m;
      for (final l in _linhas) {
        if (_existente(l.codigo.text) == null || _atualizarPrecos) {
          final cu = lerDecimal(l.custo.text) ?? 0;
          l.venda.text = _Linha._fmt((cu * m * 100).round() / 100);
        }
      }
    });
  }

  Future<void> _confirmar() async {
    final nota = _nota;
    if (nota == null) return;
    final sel = _linhas.where((l) => l.selecionado).toList();
    if (sel.isEmpty) return setState(() => _erro = 'Selecione ao menos um item da nota.');

    // Valida tudo ANTES de gravar qualquer item.
    final problemas = <String>[];
    for (final l in sel) {
      final q = lerInteiro(l.qtd.text);
      final cu = lerDecimal(l.custo.text);
      final v = lerDecimal(l.venda.text);
      final cod = l.codigo.text.trim();
      if (cod.isEmpty) problemas.add('Item ${l.item.numero}: informe o código.');
      if (q == null || q <= 0) problemas.add('Item ${l.item.numero}: quantidade em unidades inteiras.');
      if (cu == null || cu < 0) problemas.add('Item ${l.item.numero}: custo inválido.');
      if (v == null || v < 0) problemas.add('Item ${l.item.numero}: preço de venda inválido.');
    }
    final dup = <String>{};
    for (final l in sel) {
      if (!dup.add(l.codigo.text.trim())) problemas.add('Código ${l.codigo.text.trim()} repetido na seleção: some as quantidades em um só item.');
    }
    if (problemas.isNotEmpty) return setState(() => _erro = problemas.take(4).join('\n'));

    setState(() {
      _importando = true;
      _erro = null;
      _resultado = null;
    });

    try {
      final docDe = {for (final l in sel) l: 'NF-e ${nota.idDocumento}#${l.item.numero}'};
      final jaLancados = await e.repo.documentosJaLancados(docDe.values.toList());
      var novos = 0, atualizados = 0, pulados = 0;
      final falhas = <String>[];
      for (final l in sel) {
        final doc = docDe[l]!;
        if (jaLancados.contains(doc)) {
          pulados++;
          continue;
        }
        final cod = l.codigo.text.trim();
        final existente = _existente(cod);
        final custo = lerDecimal(l.custo.text)!;
        var venda = lerDecimal(l.venda.text)!;
        if (existente != null && !_atualizarPrecos) venda = existente.valorVenda;
        final p = Produto(
          codigo: cod,
          nome: existente?.nome ?? l.item.descricao,
          lote: l.item.lote.isEmpty ? 'NF-${nota.numero}' : l.item.lote,
          quantidade: lerInteiro(l.qtd.text)!,
          valorCompra: custo,
          markup: custo > 0 ? venda / custo : _markup,
          valorVenda: venda,
          categoria: existente?.categoria ?? _categoria(l.item.descricao),
          dataEntrada: DateTime.now(),
          dataValidade: l.item.validade ?? existente?.dataValidade,
          estoqueMinimo: existente?.estoqueMinimo ?? 5,
        );
        try {
          await e.repo.salvarProduto(
            p,
            somar: true,
            documento: doc,
            observacao: 'Entrada via XML NF-e ${nota.numero} (${nota.emitenteNome})',
          );
          if (existente == null) {
            novos++;
          } else {
            atualizados++;
          }
        } on ErroCic catch (er) {
          falhas.add('Item ${l.item.numero}: ${er.mensagem}');
        }
      }
      await e.carregar();
      if (!mounted) return;
      setState(() {
        _importando = false;
        _resultado = 'Entrada concluída: $novos novo(s), $atualizados atualizado(s)'
            '${pulados > 0 ? ', $pulados já importado(s) antes (ignorados)' : ''}.';
        if (falhas.isNotEmpty) _erro = 'Alguns itens falharam (os demais já entraram):\n${falhas.take(4).join('\n')}\nPode repetir a importação: os itens já lançados são ignorados.';
      });
    } on ErroCic catch (er) {
      if (mounted) {
        setState(() {
          _importando = false;
          _erro = er.mensagem;
        });
      }
    }
  }

  String _categoria(String desc) {
    final d = desc.toLowerCase();
    if (RegExp(r'cerveja|agua|água|refrigerante|suco').hasMatch(d)) return 'Bebidas';
    if (RegExp(r'sabonete|shampoo|creme').hasMatch(d)) return 'Higiene';
    if (RegExp(r'comprimido|dorflex|glifage').hasMatch(d)) return 'Medicamentos';
    return 'Mercearia';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final nota = _nota;
    return CicPagina(children: [
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CicCard(
              padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 14, runSpacing: 12, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    CicIconeCaixa(LucideIcons.fileSpreadsheet, tom: BadgeTom.ouro, tamanho: 42),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text('Importador de XML de NF-e / NFC-e', style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w800)),
                        const CicBadge('Padrão SEFAZ', tom: BadgeTom.ouro),
                      ]),
                      Text('Dê entrada no estoque com custos, GTIN, lote e validade do XML', style: TextStyle(color: c.textMuted, fontSize: 11.5)),
                    ]),
                  ]),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    CicBotao('Carregar arquivo .XML', icone: LucideIcons.cloudUpload, onPressed: _escolherArquivo),
                    CicBotao(_colar ? 'Ocultar caixa' : 'Colar texto XML', secundario: true, onPressed: () => setState(() => _colar = !_colar)),
                  ]),
                ]),
                if (_colar) ...[
                  const SizedBox(height: 16),
                  CicCampo(rotulo: 'Cole o conteúdo completo do XML', controller: _texto, maxLines: 5, dica: '<nfeProc xmlns=...><NFe>...'),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: CicBotao('Processar XML colado', compacto: true, onPressed: () {
                    if (_texto.text.trim().isNotEmpty) _processar(_texto.text);
                  })),
                ],
                if (_erro != null) ...[const SizedBox(height: 16), CicErroBanner(mensagem: _erro!)],
                if (_resultado != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: c.emeraldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.emeraldBorder)),
                    child: Row(children: [
                      Icon(LucideIcons.circleCheck, size: 20, color: c.emerald),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_resultado!, style: TextStyle(color: c.emerald, fontSize: 12.5, fontWeight: FontWeight.w600))),
                      CicBotao('Ver no estoque', icone: LucideIcons.boxes, compacto: true, onPressed: widget.onConcluido),
                    ]),
                  ),
                ],
              ]),
            ),
            if (nota != null) ...[
              const SizedBox(height: 18),
              CicGrid(minLargura: 230, espaco: 12, children: [
                _info(c, LucideIcons.building2, 'Fornecedor / emitente', nota.emitenteNome.isEmpty ? '—' : nota.emitenteNome, 'CNPJ: ${nota.emitenteCnpj}'),
                _info(c, LucideIcons.fileText, 'Identificação da NF', 'NF nº ${nota.numero} • Série ${nota.serie}', 'Emissão: ${nota.emissao} • ${nota.naturezaOperacao}'),
                _info(c, LucideIcons.dollarSign, 'Valor da NF-e', brl(nota.valorTotal), '${nota.itens.length} item(ns) faturados'),
                CicCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(LucideIcons.percent, size: 14, color: c.gold),
                      const SizedBox(width: 6),
                      Text('Markup padrão', style: TextStyle(color: c.textMuted, fontSize: 12)),
                      const Spacer(),
                      Text('${((_markup - 1) * 100).toStringAsFixed(0)}% margem', style: TextStyle(color: c.gold, fontSize: 11, fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      for (final m in [1.4, 1.6, 1.8, 2.0])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => _novoMarkup(m),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: _markup == m ? c.botao : c.sub, borderRadius: BorderRadius.circular(8)),
                                child: Text('${((m - 1) * 100).toStringAsFixed(0)}%', style: TextStyle(color: _markup == m ? Colors.black : c.textSoft, fontSize: 12, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              CicCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Text('Chave de acesso:', style: TextStyle(color: c.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(child: SelectableText(nota.chave ?? '(não consta no XML)', style: fonteMono(context, size: 11, peso: FontWeight.w400, cor: c.textSoft), maxLines: 1)),
                  if (nota.chave != null)
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: nota.chave!));
                        setState(() => _copiada = true);
                        Future.delayed(const Duration(seconds: 2), () => mounted ? setState(() => _copiada = false) : null);
                      },
                      icon: Icon(_copiada ? LucideIcons.check : LucideIcons.copy, size: 13, color: _copiada ? c.emerald : c.textMuted),
                      label: Text(_copiada ? 'Copiada' : 'Copiar', style: TextStyle(color: _copiada ? c.emerald : c.textMuted, fontSize: 11)),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              CicCard(
                padding: const EdgeInsets.all(8),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  dense: true,
                  value: _atualizarPrecos,
                  activeThumbColor: c.gold,
                  onChanged: (v) => setState(() => _atualizarPrecos = v),
                  title: Text('Atualizar também o preço de venda dos produtos que já existem', style: TextStyle(color: c.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  subtitle: Text('Desligado: o preço atual é mantido e só o custo e o saldo mudam.', style: TextStyle(color: c.textMuted, fontSize: 11)),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: Text('${_linhas.where((l) => l.selecionado).length} de ${_linhas.length} itens selecionados', style: TextStyle(color: c.textSoft, fontSize: 12.5, fontWeight: FontWeight.w700))),
                TextButton(onPressed: () => setState(() => [for (final l in _linhas) l.selecionado = true]), child: Text('Marcar todos', style: TextStyle(color: c.gold, fontSize: 12))),
                TextButton(onPressed: () => setState(() => [for (final l in _linhas) l.selecionado = false]), child: Text('Desmarcar', style: TextStyle(color: c.textMuted, fontSize: 12))),
              ]),
              const SizedBox(height: 6),
              for (final l in _linhas) Padding(padding: const EdgeInsets.only(bottom: 12), child: _cartaoItem(c, l)),
              const SizedBox(height: 8),
              CicBotao(
                'Confirmar Entrada no Estoque',
                icone: LucideIcons.packageCheck,
                largo: true,
                carregando: _importando,
                onPressed: _confirmar,
              ),
              const SizedBox(height: 6),
              Text('As entradas são registradas com o documento da NF-e ${nota.numero}. Importar a mesma nota de novo não duplica o estoque.',
                  textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, fontSize: 11)),
            ],
          ]),
        ),
      ),
    ]);
  }

  Widget _info(CicPalette c, IconData i, String t, String v, String s) => CicCard(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(i, size: 14, color: c.gold), const SizedBox(width: 6), Text(t, style: TextStyle(color: c.textMuted, fontSize: 12))]),
      const SizedBox(height: 6),
      Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(s, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textMuted, fontSize: 11)),
    ]),
  );

  Widget _cartaoItem(CicPalette c, _Linha l) {
    final existente = _existente(l.codigo.text);
    return Opacity(
      opacity: l.selecionado ? 1 : 0.55,
      child: CicCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(value: l.selecionado, activeColor: c.gold, checkColor: Colors.black, onChanged: (v) => setState(() => l.selecionado = v ?? false)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.item.descricao.isEmpty ? '(sem descrição)' : l.item.descricao, style: TextStyle(color: c.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Wrap(spacing: 10, children: [
                  Text('Item ${l.item.numero}', style: TextStyle(color: c.textMuted, fontSize: 11)),
                  Text('Un: ${l.item.unidade.isEmpty ? '—' : l.item.unidade}', style: TextStyle(color: c.textMuted, fontSize: 11)),
                  Text('Total NF: ${brl(l.item.valorTotal)}', style: TextStyle(color: c.textMuted, fontSize: 11)),
                  if (l.item.lote.isNotEmpty) Text('Lote ${l.item.lote}', style: fonteMono(context, size: 11, peso: FontWeight.w400, cor: c.textMuted)),
                  if (l.item.validade != null) Text('Val: ${dataCurta(l.item.validade)}', style: TextStyle(color: c.amber, fontSize: 11)),
                ]),
              ]),
            ),
            existente != null ? CicBadge('Atualizar (${existente.quantidade} un)', tom: BadgeTom.ouro) : const CicBadge('Novo produto', tom: BadgeTom.verde),
          ]),
          for (final a in l.item.avisos)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(LucideIcons.triangleAlert, size: 13, color: c.amber),
                const SizedBox(width: 6),
                Expanded(child: Text(a, style: TextStyle(color: c.amber, fontSize: 11, height: 1.3))),
              ]),
            ),
          const SizedBox(height: 12),
          CicGrid(minLargura: 130, espaco: 10, maxColunas: 4, children: [
            CicCampo(rotulo: 'Código / EAN', controller: l.codigo, onChanged: (_) => setState(() {})),
            CicCampo(rotulo: 'Qtd (unidades)', controller: l.qtd, teclado: TextInputType.number),
            CicCampo(
              rotulo: 'Custo unit. (R\$)',
              controller: l.custo,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                if (existente == null || _atualizarPrecos) {
                  final cu = lerDecimal(l.custo.text) ?? 0;
                  l.venda.text = _Linha._fmt((cu * _markup * 100).round() / 100);
                }
              },
            ),
            CicCampo(rotulo: 'Venda (R\$)', controller: l.venda, teclado: const TextInputType.numberWithOptions(decimal: true)),
          ]),
        ]),
      ),
    );
  }
}
