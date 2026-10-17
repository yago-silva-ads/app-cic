import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';

class LogisticaReversaScreen extends StatefulWidget {
  const LogisticaReversaScreen({super.key, required this.estado});
  final AppState estado;

  @override
  State<LogisticaReversaScreen> createState() => _LogisticaReversaScreenState();
}

class _LogisticaReversaScreenState extends State<LogisticaReversaScreen> {
  Produto? _produto;
  String _motivo = 'Devolução ao fornecedor';
  String _destino = 'Fornecedor';
  final _quantidade = TextEditingController(text: '1');
  final _documento = TextEditingController();
  final _observacao = TextEditingController();
  bool _salvando = false;

  AppState get e => widget.estado;

  @override
  void initState() {
    super.initState();
    if (e.estoque.isNotEmpty) _produto = e.estoque.first;
  }

  @override
  void dispose() {
    _quantidade.dispose();
    _documento.dispose();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final p = _produto;
    final qtd = lerInteiro(_quantidade.text);
    if (p == null) return aviso(context, 'Escolha um produto.', erro: true);
    if (qtd == null || qtd <= 0) return aviso(context, 'Informe uma quantidade válida.', erro: true);
    if (qtd > p.quantidade) return aviso(context, 'A quantidade excede o saldo disponível (${p.quantidade}).', erro: true);
    setState(() => _salvando = true);
    try {
      await e.registrarLogisticaReversa(codigo: p.codigo, quantidade: qtd, motivo: _motivo, destino: _destino, documento: _documento.text.trim().isEmpty ? null : _documento.text.trim(), observacao: _observacao.text.trim().isEmpty ? null : _observacao.text.trim());
      if (mounted) { aviso(context, 'Saída reversa registrada e estoque atualizado.'); _quantidade.text = '1'; _documento.clear(); _observacao.clear(); }
    } on ErroCic catch (err) {
      if (mounted) aviso(context, err.mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (e.estoque.isEmpty) {
      return CicPagina(children: [CicVazio(icone: LucideIcons.refreshCw, titulo: 'Nenhum produto disponível', texto: 'Cadastre um produto antes de registrar uma devolução ou avaria.')]);
    }
    return CicPagina(children: [
      Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CicCard(padding: const EdgeInsets.all(22), gradiente: LinearGradient(colors: c.isLight ? const [Color(0xFFEFF6FF), Colors.white] : const [Color(0xFF111827), Color(0xFF141414)]), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CicIconeCaixa(LucideIcons.refreshCw, tom: BadgeTom.ouro, tamanho: 46),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Logística reversa', style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Retire produtos do estoque com motivo, destino e documento. O movimento fica no histórico para conferência com fornecedor, cliente ou transportadora.', style: TextStyle(color: c.textMuted, fontSize: 12, height: 1.45)),
          ])),
        ])),
        const SizedBox(height: 16),
        CicCard(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _seletor(c, 'Produto', DropdownButton<Produto>(value: _produto, isExpanded: true, underline: const SizedBox.shrink(), items: [for (final p in e.estoque) DropdownMenuItem(value: p, child: Text('${p.nome} • ${p.quantidade} ${p.unidade}'))], onChanged: (p) => setState(() => _produto = p))),
          const SizedBox(height: 14),
          _seletor(c, 'Motivo', DropdownButton<String>(value: _motivo, isExpanded: true, underline: const SizedBox.shrink(), items: const [DropdownMenuItem(value: 'Devolução ao fornecedor', child: Text('Devolução ao fornecedor')), DropdownMenuItem(value: 'Produto avariado', child: Text('Produto avariado')), DropdownMenuItem(value: 'Produto vencido', child: Text('Produto vencido')), DropdownMenuItem(value: 'Recall', child: Text('Recall'))], onChanged: (v) => setState(() => _motivo = v ?? _motivo))),
          const SizedBox(height: 14),
          _seletor(c, 'Destino', DropdownButton<String>(value: _destino, isExpanded: true, underline: const SizedBox.shrink(), items: const [DropdownMenuItem(value: 'Fornecedor', child: Text('Fornecedor')), DropdownMenuItem(value: 'Descarte', child: Text('Descarte')), DropdownMenuItem(value: 'Assistência técnica', child: Text('Assistência técnica')), DropdownMenuItem(value: 'Transportadora', child: Text('Transportadora'))], onChanged: (v) => setState(() => _destino = v ?? _destino))),
          const SizedBox(height: 14),
          CicCampo(rotulo: 'Quantidade', controller: _quantidade, teclado: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly]),
          const SizedBox(height: 14),
          CicCampo(rotulo: 'Documento ou protocolo (opcional)', controller: _documento, dica: 'Ex.: NF de devolução, RMA ou protocolo'),
          const SizedBox(height: 14),
          CicCampo(rotulo: 'Observação (opcional)', controller: _observacao, maxLines: 3, dica: 'Descreva o motivo, lote ou condição do produto'),
          const SizedBox(height: 16),
          CicBotao(_salvando ? 'Registrando...' : 'Registrar saída reversa', icone: LucideIcons.check, largo: true, carregando: _salvando, onPressed: _salvando ? null : _salvar),
        ])),
        const SizedBox(height: 16),
        CicSub(child: Text('A operação reduz o saldo de forma atômica e cria uma movimentação de saída. Para devolução de cliente, registre também o documento fiscal conforme a rotina do seu estabelecimento.', style: TextStyle(color: c.textMuted, fontSize: 11.5, height: 1.4))),
      ]))),
    ]);
  }

  Widget _seletor(CicPalette c, String rotulo, Widget campo) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(rotulo.toUpperCase(), style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)), const SizedBox(height: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: c.input, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.inputBorder)), child: campo)]);
}
