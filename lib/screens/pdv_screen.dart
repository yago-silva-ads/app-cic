import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/pix.dart';
import '../core/theme.dart';
import '../data/conta.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';
import 'conta_modal.dart';

enum _Forma {
  pix('PIX', 'PIX Direto', LucideIcons.qrCode),
  dinheiro('DINHEIRO', 'Dinheiro (Troco)', LucideIcons.banknote),
  debito('CARTAO_DEBITO', 'Cartão Débito', LucideIcons.creditCard),
  credito('CARTAO_CREDITO', 'Cartão Crédito', LucideIcons.creditCard);

  const _Forma(this.codigo, this.rotulo, this.icone);
  final String codigo;
  final String rotulo;
  final IconData icone;
  bool get cartao => this == debito || this == credito;
}

class _Cupom {
  _Cupom({
    required this.id,
    required this.data,
    required this.itens,
    required this.totalCent,
    required this.forma,
    required this.recebidoCent,
    required this.trocoCent,
    required this.operador,
    this.maquininha,
    this.nsu,
    this.chavePix,
  });
  final String id;
  final DateTime data;
  final List<(String nome, int qtd, int subCent)> itens;
  final int totalCent;
  final _Forma forma;
  final int recebidoCent;
  final int trocoCent;
  final String operador;
  final String? maquininha;
  final String? nsu;
  final String? chavePix;
}

/// Frente de Caixa (porte de `VendedorScreen.tsx`). A venda é gravada por
/// `registrar_venda` (atômica no banco): se faltar estoque, nada é gravado.
class PdvScreen extends StatefulWidget {
  const PdvScreen({super.key, required this.estado, required this.onAbrirScanner});
  final AppState estado;
  final Future<void> Function([ValueChanged<String>? aoLer]) onAbrirScanner;

  @override
  State<PdvScreen> createState() => _PdvScreenState();
}

class _PdvScreenState extends State<PdvScreen> {
  final _busca = TextEditingController();
  final _recebido = TextEditingController();
  final _nsu = TextEditingController();
  final _checkoutKey = GlobalKey();
  final _rolagem = ScrollController();

  /// Leva até o pagamento. A lista é preguiçosa: se o checkout ainda não foi
  /// construído (lista longa), rola até o fim e depois ajusta a posição.
  Future<void> _irParaPagamento() async {
    if (!_rolagem.hasClients) return;
    final ctx = _checkoutKey.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      return;
    }
    await _rolagem.animateTo(_rolagem.position.maxScrollExtent, duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
    if (!mounted) return;
    final ctx2 = _checkoutKey.currentContext;
    if (ctx2 != null && ctx2.mounted) {
      await Scrollable.ensureVisible(ctx2, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  String _categoria = 'TODOS';
  final List<ItemCarrinho> _carrinho = [];
  _Forma _forma = _Forma.pix;
  String? _maquininhaId;
  bool _aprovado = false;
  bool _finalizando = false;
  bool _ajuda = false;
  bool _pixCopiado = false;
  SessaoCaixa? _sessao;
  String? _erroSessao;
  String _pixTxid = 'CIC${DateTime.now().millisecondsSinceEpoch % 1000000}';

  AppState get e => widget.estado;
  ContaEstabelecimento get conta => e.conta;

  @override
  void initState() {
    super.initState();
    _carregarSessao();
  }

  @override
  void dispose() {
    _busca.dispose();
    _recebido.dispose();
    _nsu.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _carregarSessao() async {
    try {
      final s = await e.repo.sessaoCaixaAtual(conta);
      if (mounted) setState(() => _sessao = s);
    } on ErroCic catch (er) {
      if (mounted) setState(() => _erroSessao = er.mensagem);
    }
  }

  // ---------- Totais ----------
  int get _totalCent => _carrinho.fold(0, (s, i) => s + i.subtotalCentavos);
  int get _unidades => _carrinho.fold(0, (s, i) => s + i.quantidade);
  int get _recebidoCent => ((lerDecimal(_recebido.text) ?? 0) * 100).round();
  int get _trocoCent => _forma == _Forma.dinheiro ? (_recebidoCent - _totalCent).clamp(0, 1 << 40) : 0;

  Maquininha? get _maquina {
    if (conta.maquininhas.isEmpty) return null;
    return conta.maquininhas.firstWhere((m) => m.id == _maquininhaId, orElse: () => conta.maquininhas.first);
  }

  double get _taxaPct => _maquina == null ? 0 : (_forma == _Forma.debito ? _maquina!.taxaDebito : _maquina!.taxaCredito);
  int get _taxaCent => (_totalCent * _taxaPct / 100).round();
  int get _liquidoCent => (_totalCent - _taxaCent).clamp(0, 1 << 40);

  /// Totais do turno derivados do histórico de vendas (fonte única da verdade).
  ({int dinheiro, int pix, int debito, int credito, int vendas}) _totaisTurno() {
    final s = _sessao;
    if (s == null) return (dinheiro: 0, pix: 0, debito: 0, credito: 0, vendas: 0);
    var din = 0, pix = 0, deb = 0, cre = 0;
    final ids = <String>{};
    for (final v in e.vendas) {
      if (v.data.isBefore(s.abertaEm)) continue;
      ids.add(v.vendaId ?? v.id);
      final liq = (v.quantidade * centavos(v.valorUnitario) * (1 - v.desconto / 100)).round();
      switch (v.metodoPagamento) {
        case 'PIX':
          pix += liq;
        case 'CARTAO_DEBITO':
          deb += liq;
        case 'CARTAO_CREDITO':
          cre += liq;
        default:
          din += liq;
      }
    }
    return (dinheiro: din, pix: pix, debito: deb, credito: cre, vendas: ids.length);
  }

  double get _saldoGaveta {
    final s = _sessao;
    if (s == null) return 0;
    return s.fundoTroco + _totaisTurno().dinheiro / 100 + s.totalSuprimento - s.totalSangria;
  }

  // ---------- Carrinho ----------
  void _bip() {
    if (conta.somBeep) {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.selectionClick();
    }
  }

  void _adicionar(Produto p) {
    if (p.quantidade <= 0) {
      aviso(context, '"${p.nome}" está sem estoque.', erro: true);
      return;
    }
    final i = _carrinho.indexWhere((x) => x.produto.codigo == p.codigo);
    if (i >= 0) {
      if (_carrinho[i].quantidade >= p.quantidade) {
        aviso(context, 'Estoque máximo atingido (${p.quantidade} un) para "${p.nome}".', erro: true);
        return;
      }
      setState(() => _carrinho[i].quantidade++);
    } else {
      setState(() => _carrinho.add(ItemCarrinho(produto: p)));
    }
    _bip();
    _resetarPagamento();
  }

  void _alterarQtd(ItemCarrinho item, int delta) {
    final nova = item.quantidade + delta;
    if (nova <= 0) {
      setState(() => _carrinho.remove(item));
    } else if (nova > item.produto.quantidade) {
      aviso(context, 'Limite de estoque atingido (${item.produto.quantidade} unidades).', erro: true);
      return;
    } else {
      setState(() => item.quantidade = nova);
    }
    _resetarPagamento();
  }

  void _resetarPagamento() {
    _aprovado = false;
    _pixTxid = 'CIC${DateTime.now().millisecondsSinceEpoch % 1000000}';
    if (_forma == _Forma.dinheiro) _recebido.text = (_totalCent / 100).toStringAsFixed(2).replaceAll('.', ',');
  }

  Future<void> _bipar() => widget.onAbrirScanner((codigo) {
    final c = codigo.trim();
    final p = e.estoque.where((x) => x.codigo == c).firstOrNull;
    if (p == null) {
      aviso(context, 'Produto com código $c não encontrado no estoque.', erro: true);
    } else {
      _adicionar(p);
    }
  });

  // ---------- Finalizar ----------
  Future<void> _finalizar() async {
    if (_carrinho.isEmpty || _finalizando) return;
    if (_forma == _Forma.dinheiro && _recebidoCent < _totalCent) {
      aviso(context, 'O valor recebido (${brl(_recebidoCent / 100)}) é menor que o total (${brl(_totalCent / 100)}).', erro: true);
      return;
    }
    if (_forma.cartao && !_aprovado) {
      aviso(context, 'Confirme que o pagamento foi aprovado na maquininha antes de finalizar.', erro: true);
      return;
    }
    setState(() => _finalizando = true);
    final itens = [for (final i in _carrinho) ItemCarrinho(produto: i.produto, quantidade: i.quantidade)];
    final forma = _forma;
    final total = _totalCent;
    final recebido = forma == _Forma.dinheiro ? _recebidoCent : total;
    final troco = _trocoCent;
    final maq = forma.cartao ? _maquina : null;
    final nsu = _nsu.text.trim().isEmpty ? null : _nsu.text.trim();
    try {
      final id = await e.finalizarVenda(itens: itens, formaPagamento: forma.codigo, operador: conta.operador);
      if (!mounted) return;
      final cupom = _Cupom(
        id: 'VEN-${id.substring(0, 8).toUpperCase()}',
        data: DateTime.now(),
        itens: [for (final i in itens) (i.produto.nome, i.quantidade, i.subtotalCentavos)],
        totalCent: total,
        forma: forma,
        recebidoCent: recebido,
        trocoCent: troco,
        operador: conta.operador,
        maquininha: maq?.nome,
        nsu: nsu,
        chavePix: forma == _Forma.pix ? conta.pixChave : null,
      );
      setState(() {
        _carrinho.clear();
        _recebido.clear();
        _nsu.clear();
        _aprovado = false;
        _finalizando = false;
      });
      await showDialog<void>(context: context, builder: (_) => _CupomDialog(cupom: cupom, conta: conta));
    } on ErroCic catch (er) {
      if (!mounted) return;
      setState(() => _finalizando = false);
      aviso(context, er.mensagem, erro: true);
      // Saldo mudou em outro aparelho: atualiza o que a tela mostra.
      if (er.codigo == 'ESTOQUE_INSUFICIENTE' || er.codigo == 'PRODUTO_NAO_ENCONTRADO') e.carregar();
    }
  }

  // ---------- Movimento de caixa ----------
  Future<void> _movimento(String tipo) async {
    final s = _sessao;
    if (s == null) return;
    final r = await showDialog<(double, String)>(
      context: context,
      builder: (_) => _MovimentoDialog(tipo: tipo, saldoGaveta: _saldoGaveta),
    );
    if (r == null) return;
    try {
      final nova = await e.repo.registrarMovimentoCaixa(
        s.id,
        MovimentoCaixa(
          id: '${tipo == 'SANGRIA' ? 'SANG' : 'SUPR'}-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
          tipo: tipo,
          valor: r.$1,
          motivo: r.$2.isEmpty ? (tipo == 'SANGRIA' ? 'Retirada de segurança para cofre/banco' : 'Reforço de troco e moedas') : r.$2,
          operador: conta.operador,
          dataHora: DateTime.now(),
        ),
      );
      if (!mounted) return;
      setState(() => _sessao = nova);
      aviso(context, '${tipo == 'SANGRIA' ? 'Sangria' : 'Reforço'} de ${brl(r.$1)} registrado.');
    } on ErroCic catch (er) {
      if (mounted) aviso(context, er.mensagem, erro: true);
    }
  }

  Future<void> _turno() async {
    final s = _sessao;
    if (s == null) return;
    final t = _totaisTurno();
    final acao = await showDialog<String>(
      context: context,
      builder: (_) => _TurnoDialog(sessao: s, totais: t, saldoGaveta: _saldoGaveta),
    );
    if (acao == 'fechar') {
      try {
        await e.repo.fecharSessaoCaixa(s.id);
        final nova = await e.repo.abrirNovaSessaoCaixa(conta.operador, conta.fundoTrocoPadrao);
        if (!mounted) return;
        setState(() => _sessao = nova);
        aviso(context, 'Turno fechado. Novo turno aberto com fundo de ${brl(conta.fundoTrocoPadrao)}.');
      } on ErroCic catch (er) {
        if (mounted) aviso(context, er.mensagem, erro: true);
      }
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final largura = MediaQuery.sizeOf(context).width;
    final dois = largura >= 1024;
    final cats = ['TODOS', ...{for (final p in e.estoque) p.categoria.isEmpty ? 'Geral' : p.categoria}];
    final t = _busca.text.trim().toLowerCase();
    final lista = e.estoque.where((p) {
      final okBusca = t.isEmpty || p.nome.toLowerCase().contains(t) || p.codigo.contains(t);
      final okCat = _categoria == 'TODOS' || (p.categoria.isEmpty ? 'Geral' : p.categoria) == _categoria;
      return okBusca && okCat;
    }).take(24).toList();

    final catalogo = _catalogo(c, cats, lista);
    final checkout = KeyedSubtree(key: _checkoutKey, child: _checkout(c));

    return Stack(children: [
      CicPagina(
        controller: _rolagem,
        padding: EdgeInsets.fromLTRB(largura >= 640 ? 24 : 12, 16, largura >= 640 ? 24 : 12, _carrinho.isNotEmpty && !dois ? 96 : 32),
        children: [
          _topo(c),
          if (_ajuda) ...[const SizedBox(height: 14), _painelAjuda(c)],
          const SizedBox(height: 18),
          if (dois)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: catalogo),
              const SizedBox(width: 24),
              Expanded(child: checkout),
            ])
          else ...[catalogo, const SizedBox(height: 18), checkout],
        ],
      ),
      if (_carrinho.isNotEmpty && !dois)
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.isLight ? Colors.white.withValues(alpha: 0.96) : const Color(0xF2171717),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.isLight ? const Color(0xFFCBD5E1) : const Color(0xFF404040)),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 20)],
            ),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Total ($_unidades itens):', style: TextStyle(color: c.textMuted, fontSize: 11)),
                Text(brl(_totalCent / 100), style: fonteMono(context, size: 16, cor: c.emerald)),
              ]),
              const Spacer(),
              CicBotao('Ir p/ Pagamento', icone: LucideIcons.shoppingCart, compacto: true, onPressed: _irParaPagamento),
            ]),
          ),
        ),
    ]);
  }

  Widget _topo(CicPalette c) {
    final nome = conta.nomeFantasia.isEmpty ? (e.usuario?.lojaNome ?? 'Minha Loja') : conta.nomeFantasia;
    final botoes = [
      _acao(c, LucideIcons.circleArrowDown, 'Tirar (Sangria)', c.amber, () => _movimento('SANGRIA')),
      _acao(c, LucideIcons.circleArrowUp, 'Troco (Reforço)', c.emerald, () => _movimento('SUPRIMENTO')),
      _acao(c, LucideIcons.wallet, 'Turno', c.gold, _turno),
      Material(
        color: c.botao,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => abrirContaModal(context, e),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.settings, size: 14, color: Colors.black),
              SizedBox(width: 6),
              Text('Conta', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
          ),
        ),
      ),
    ];
    return CicCard(
      gradiente: c.isLight ? null : const LinearGradient(colors: [Color(0xFF171A21), Color(0xFF1B1F28), Color(0xFF14161C)]),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          CicIconeCaixa(LucideIcons.store, tom: BadgeTom.ouro, tamanho: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(nome, style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w800)),
                const CicBadge('Frente de Caixa Ativo', tom: BadgeTom.verde),
              ]),
              const SizedBox(height: 4),
              Text(
                '${conta.documentoNumero.isEmpty ? 'Documento não informado' : '${conta.documentoTipo}: ${conta.documentoNumero}'}'
                '${conta.banco.isEmpty ? '' : ' • Banco: ${conta.banco}'} • Op: ${conta.operador}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.textMuted, fontSize: 11.5),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        if (_erroSessao != null) ...[CicErroBanner(mensagem: _erroSessao!, onTentar: _carregarSessao), const SizedBox(height: 12)],
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: c.isLight ? const Color(0xFFF8FAFC) : const Color(0xFF13151A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.isLight ? c.cardBorder : const Color(0xFF272D3A)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Gaveta Dinheiro', style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
              Text(_sessao == null ? '—' : brl(_saldoGaveta), style: fonteMono(context, size: 14, cor: c.emerald)),
            ]),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _ajuda = !_ajuda),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: _ajuda ? c.goldBg : c.sub,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _ajuda ? c.gold : c.subBorder),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.circleQuestionMark, size: 15, color: c.gold),
                const SizedBox(width: 4),
                Text('O que é?', style: TextStyle(color: c.textSoft, fontSize: 11, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
          ...botoes,
        ]),
      ]),
    );
  }

  Widget _acao(CicPalette c, IconData i, String t, Color cor, VoidCallback f) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: _sessao == null ? null : f,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.isLight ? c.sub : const Color(0xFF20242D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.isLight ? c.cardBorder : const Color(0xFF313642)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 14, color: cor),
        const SizedBox(width: 6),
        Text(t, style: TextStyle(color: c.textSoft, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  Widget _painelAjuda(CicPalette c) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: c.isLight ? const Color(0xFFFFFBEB) : const Color(0xFF1D1B16),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.isLight ? c.amberBorder : const Color(0xFF423720)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(LucideIcons.circleQuestionMark, size: 16, color: c.amber),
        const SizedBox(width: 8),
        Expanded(child: Text('Entenda Sangria e Reforço de forma simples', style: TextStyle(color: c.amber, fontWeight: FontWeight.w800, fontSize: 13))),
        IconButton(onPressed: () => setState(() => _ajuda = false), icon: Icon(LucideIcons.x, size: 15, color: c.textMuted), visualDensity: VisualDensity.compact),
      ]),
      const SizedBox(height: 8),
      CicGrid(minLargura: 280, espaco: 12, maxColunas: 2, children: [
        CicSub(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sangria = tirar dinheiro da gaveta', style: TextStyle(color: c.amber, fontWeight: FontWeight.w800, fontSize: 12.5)),
            const SizedBox(height: 6),
            Text('Retirada segura de notas quando acumulou dinheiro: guardar no cofre, depositar no banco ou pagar um fornecedor na porta.',
                style: TextStyle(color: c.textMuted, fontSize: 11.5, height: 1.4)),
          ]),
        ),
        CicSub(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Reforço = colocar troco', style: TextStyle(color: c.emerald, fontWeight: FontWeight.w800, fontSize: 12.5)),
            const SizedBox(height: 6),
            Text('Entrada de dinheiro na gaveta: fundo de troco do início do dia, moedas, notas miúdas ou aporte do dono.',
                style: TextStyle(color: c.textMuted, fontSize: 11.5, height: 1.4)),
          ]),
        ),
      ]),
    ]),
  );

  Widget _catalogo(CicPalette c, List<String> cats, List<Produto> lista) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CicCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: CicCampo(
                controller: _busca,
                dica: 'Buscar produto (nome ou código de barras)...',
                icone: LucideIcons.search,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            CicBotao('Bipar', icone: LucideIcons.barcode, onPressed: _bipar),
          ]),
          if (cats.length > 1) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final cat in cats)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _categoria = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _categoria == cat ? c.botao : (c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF20242D)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(cat, style: TextStyle(color: _categoria == cat ? Colors.black : c.textSoft, fontSize: 11, fontWeight: _categoria == cat ? FontWeight.w800 : FontWeight.w500)),
                      ),
                    ),
                  ),
              ]),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 14),
      if (lista.isEmpty)
        CicCard(
          child: CicVazio(
            icone: LucideIcons.packageSearch,
            titulo: e.estoque.isEmpty ? 'Estoque vazio' : 'Nenhum produto encontrado',
            texto: e.estoque.isEmpty ? 'Cadastre produtos para começar a vender.' : 'Ajuste a busca ou a categoria.',
          ),
        )
      else
        CicGrid(minLargura: 150, espaco: 12, maxColunas: 4, children: [
          for (final p in lista) _produto(c, p),
        ]),
    ]);
  }

  Widget _produto(CicPalette c, Produto p) {
    final esgotado = p.quantidade <= 0;
    final noCarrinho = _carrinho.where((x) => x.produto.codigo == p.codigo).fold(0, (s, x) => s + x.quantidade);
    return Opacity(
      opacity: esgotado ? 0.4 : 1,
      child: CicCard(
        onTap: esgotado ? null : () => _adicionar(p),
        padding: const EdgeInsets.all(14),
        cor: c.isLight ? Colors.white : const Color(0xFF171A21),
        borda: noCarrinho > 0 ? c.gold : (c.isLight ? c.cardBorder : const Color(0xFF272D3A)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.codigo, style: fonteMono(context, size: 10, peso: FontWeight.w400, cor: c.textMuted)),
          const SizedBox(height: 3),
          SizedBox(
            height: 34,
            child: Text(p.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w800, height: 1.25)),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF242A36)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(brl(p.valorVenda), style: fonteMono(context, size: 12, cor: c.emerald)))),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: esgotado ? const Color(0x1AEF4444) : (c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF262626)),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(esgotado ? 'Esgotado' : '${p.quantidade} un',
                  style: TextStyle(color: esgotado ? const Color(0xFFEF4444) : c.textMuted, fontSize: 10, fontWeight: esgotado ? FontWeight.w800 : FontWeight.w500)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _checkout(CicPalette c) {
    return CicCard(
      cor: c.isLight ? Colors.white : const Color(0xFF171A21),
      borda: c.isLight ? c.cardBorder : const Color(0xFF272D3A),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(LucideIcons.shoppingCart, size: 18, color: c.gold),
          const SizedBox(width: 8),
          Text('CARRINHO DE VENDA', style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
          const Spacer(),
          Text('$_unidades itens', style: fonteMono(context, size: 11, peso: FontWeight.w400, cor: c.textMuted)),
        ]),
        const SizedBox(height: 10),
        Divider(height: 1, color: c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF242A36)),
        if (_carrinho.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 34),
            child: Text('Carrinho vazio. Bipe o código ou toque nos produtos para iniciar a venda.',
                textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, fontSize: 12)),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView(
              shrinkWrap: true,
              children: [for (final i in _carrinho) _itemCarrinho(c, i)],
            ),
          ),
        const SizedBox(height: 10),
        Divider(height: 1, color: c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF242A36)),
        const SizedBox(height: 14),
        Text('Forma de pagamento:', style: TextStyle(color: c.textSoft, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        CicGrid(minLargura: 120, espaco: 8, maxColunas: 2, children: [for (final f in _Forma.values) _formaBtn(c, f)]),
        const SizedBox(height: 12),
        if (_totalCent > 0) ...[
          if (_forma == _Forma.pix) _pix(c),
          if (_forma.cartao) _cartao(c),
          if (_forma == _Forma.dinheiro) _dinheiro(c),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.isLight ? const Color(0xFFFFFBEB) : const Color(0xFF13151A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.isLight ? c.amberBorder : const Color(0xFF242A36)),
          ),
          child: Row(children: [
            Text('Total a Pagar:', style: TextStyle(color: c.textMuted, fontSize: 12)),
            const Spacer(),
            Text(brl(_totalCent / 100), style: fonteMono(context, size: 20, cor: c.gold)),
          ]),
        ),
        const SizedBox(height: 12),
        CicBotao(
          'Finalizar Venda & Emitir Cupom',
          icone: LucideIcons.circleCheck,
          largo: true,
          carregando: _finalizando,
          onPressed: _carrinho.isEmpty ? null : _finalizar,
        ),
      ]),
    );
  }

  Widget _itemCarrinho(CicPalette c, ItemCarrinho i) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(i.produto.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w600)),
          Text('${brl(i.produto.valorVenda)} cada', style: fonteMono(context, size: 11, peso: FontWeight.w400, cor: c.textMuted)),
        ]),
      ),
      _mini(c, LucideIcons.minus, () => _alterarQtd(i, -1), c.textSoft),
      SizedBox(width: 26, child: Text('${i.quantidade}', textAlign: TextAlign.center, style: fonteMono(context, size: 12))),
      _mini(c, LucideIcons.plus, () => _alterarQtd(i, 1), c.gold),
      SizedBox(width: 72, child: Text(brl(i.subtotalCentavos / 100), textAlign: TextAlign.right, style: fonteMono(context, size: 12, cor: c.emerald))),
    ]),
  );

  Widget _mini(CicPalette c, IconData i, VoidCallback f, Color cor) => Material(
    color: c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF252A36),
    borderRadius: BorderRadius.circular(6),
    child: InkWell(borderRadius: BorderRadius.circular(6), onTap: f, child: SizedBox(width: 26, height: 26, child: Icon(i, size: 12, color: cor))),
  );

  Widget _formaBtn(CicPalette c, _Forma f) {
    final ativa = _forma == f;
    return GestureDetector(
      onTap: () => setState(() {
        _forma = f;
        _resetarPagamento();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          color: ativa ? c.emeraldBg : (c.isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1F232B)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ativa ? (c.isLight ? const Color(0xFF10B981) : const Color(0xFF059669)) : (c.isLight ? c.cardBorder : const Color(0xFF313642))),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(f.icone, size: 14, color: ativa ? c.emerald : c.textMuted),
          const SizedBox(width: 6),
          Flexible(child: Text(f.rotulo, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: ativa ? FontWeight.w800 : FontWeight.w500, color: ativa ? c.emerald : c.textMuted))),
        ]),
      ),
    );
  }

  Widget _painelPagto(CicPalette c, {required Widget child, Color? borda}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: c.isLight ? const Color(0xFFF8FAFC) : const Color(0xFF13151A),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borda ?? (c.isLight ? c.cardBorder : const Color(0xFF272D3A))),
    ),
    child: child,
  );

  Widget _pix(CicPalette c) {
    if (!conta.pixConfigurado) {
      return _painelPagto(
        c,
        borda: c.amberBorder,
        child: Row(children: [
          Icon(LucideIcons.triangleAlert, size: 16, color: c.amber),
          const SizedBox(width: 10),
          Expanded(child: Text('Cadastre sua chave PIX em Conta > "2. Conta & PIX" para gerar o QR Code.', style: TextStyle(color: c.amber, fontSize: 11.5))),
          TextButton(onPressed: () => abrirContaModal(context, e), child: Text('Abrir', style: TextStyle(color: c.gold))),
        ]),
      );
    }
    final payload = gerarPayloadPix(
      chave: conta.pixChave,
      nomeRecebedor: conta.pixTitular.isEmpty ? conta.nomeFantasia : conta.pixTitular,
      cidadeRecebedor: conta.pixCidade.isEmpty ? (conta.cidade.isEmpty ? 'BRASIL' : conta.cidade) : conta.pixCidade,
      valor: _totalCent / 100,
      identificador: _pixTxid,
    );
    return _painelPagto(
      c,
      borda: c.isLight ? c.emeraldBorder : const Color(0x66065F46),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(LucideIcons.qrCode, size: 13, color: c.emerald),
          const SizedBox(width: 6),
          Text('QR Code Oficial PIX', style: TextStyle(color: c.emerald, fontSize: 11, fontWeight: FontWeight.w800)),
          const Spacer(),
          Flexible(child: Text(conta.pixChave, overflow: TextOverflow.ellipsis, style: fonteMono(context, size: 10, peso: FontWeight.w400, cor: c.gold))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: QrImageView(data: payload, size: 110, backgroundColor: Colors.white, padding: EdgeInsets.zero),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cai direto na sua conta${conta.banco.isEmpty ? '' : ' ${conta.banco}'} sem taxas.', style: TextStyle(color: c.textMuted, fontSize: 11.5, height: 1.3)),
              const SizedBox(height: 8),
              CicBotao(_pixCopiado ? 'Código copiado!' : 'Copiar PIX Copia e Cola', icone: _pixCopiado ? LucideIcons.check : LucideIcons.copy, secundario: true, compacto: true, largo: true, onPressed: () async {
                await Clipboard.setData(ClipboardData(text: payload));
                setState(() => _pixCopiado = true);
                Future.delayed(const Duration(seconds: 2), () => mounted ? setState(() => _pixCopiado = false) : null);
              }),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _cartao(CicPalette c) {
    final m = _maquina;
    return _painelPagto(
      c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(LucideIcons.creditCard, size: 13, color: c.gold),
          const SizedBox(width: 6),
          Expanded(child: Text('Maquininha do balcão', style: TextStyle(color: c.text, fontSize: 11.5, fontWeight: FontWeight.w800))),
          const CicBadge('Taxas no automático', tom: BadgeTom.verde),
        ]),
        const SizedBox(height: 10),
        if (conta.maquininhas.isEmpty)
          Row(children: [
            Expanded(child: Text('Nenhuma maquininha cadastrada. Cadastre em Conta > "3. Maquininhas".', style: TextStyle(color: c.amber, fontSize: 11.5))),
            TextButton(onPressed: () => abrirContaModal(context, e), child: Text('Abrir', style: TextStyle(color: c.gold))),
          ])
        else ...[
          DropdownButtonFormField<String>(
            initialValue: m?.id,
            isExpanded: true,
            dropdownColor: c.card,
            style: TextStyle(color: c.text, fontSize: 12.5),
            decoration: const InputDecoration(),
            items: [
              for (final x in conta.maquininhas)
                DropdownMenuItem(value: x.id, child: Text('${x.nome} (${_forma == _Forma.debito ? '${x.taxaDebito}% débito' : '${x.taxaCredito}% crédito'})', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() {
              _maquininhaId = v;
              _aprovado = false;
            }),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.sub, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.subBorder)),
            child: Column(children: [
              Row(children: [
                Text('Taxa (${_taxaPct.toStringAsFixed(2)}%):', style: TextStyle(color: c.textMuted, fontSize: 11)),
                const Spacer(),
                Text('- ${brl(_taxaCent / 100)}', style: fonteMono(context, size: 11, cor: const Color(0xFFEF4444))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Text('Líquido na sua conta:', style: TextStyle(color: c.text, fontSize: 11, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(brl(_liquidoCent / 100), style: fonteMono(context, size: 11, cor: c.emerald)),
              ]),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Depósito em ${m!.prazoDias == 0 ? 'tempo real (D+0)' : '${m.prazoDias} dia(s) útil'}.',
                  style: TextStyle(color: c.textMuted, fontSize: 10),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: CicCampo(controller: _nsu, dica: 'NSU / autorização (opcional)')),
          const SizedBox(width: 8),
          CicBotao(_aprovado ? 'Aprovado!' : 'Aprovado na máquina', icone: _aprovado ? LucideIcons.checkCheck : LucideIcons.shieldCheck, secundario: !_aprovado, compacto: true, onPressed: () {
            _bip();
            setState(() => _aprovado = true);
          }),
        ]),
      ]),
    );
  }

  Widget _dinheiro(CicPalette c) => _painelPagto(
    c,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Valor recebido do cliente:', style: TextStyle(color: c.textSoft, fontSize: 12, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('Dinheiro em mãos', style: TextStyle(color: c.textMuted, fontSize: 11)),
      ]),
      const SizedBox(height: 8),
      CicCampo(
        controller: _recebido,
        dica: (_totalCent / 100).toStringAsFixed(2).replaceAll('.', ','),
        teclado: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        _chipValor(c, 'Exato', _totalCent / 100),
        for (final v in [10, 20, 50, 100, 200]) _chipValor(c, 'R\$ $v', v.toDouble()),
      ]),
      const SizedBox(height: 10),
      Divider(height: 1, color: c.cardBorder),
      const SizedBox(height: 10),
      Row(children: [
        Text('Troco a devolver:', style: TextStyle(color: c.textMuted, fontSize: 12)),
        const Spacer(),
        Text(brl(_trocoCent / 100), style: fonteMono(context, size: 14, cor: _trocoCent > 0 ? c.amber : c.textMuted)),
      ]),
    ]),
  );

  Widget _chipValor(CicPalette c, String t, double v) => GestureDetector(
    onTap: () => setState(() => _recebido.text = v.toStringAsFixed(2).replaceAll('.', ',')),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: c.sub, borderRadius: BorderRadius.circular(7), border: Border.all(color: c.subBorder)),
      child: Text(t, style: TextStyle(color: c.textSoft, fontSize: 10.5)),
    ),
  );
}

// ============================ Diálogos ============================

class _MovimentoDialog extends StatefulWidget {
  const _MovimentoDialog({required this.tipo, required this.saldoGaveta});
  final String tipo;
  final double saldoGaveta;

  @override
  State<_MovimentoDialog> createState() => _MovimentoDialogState();
}

class _MovimentoDialogState extends State<_MovimentoDialog> {
  final _valor = TextEditingController();
  final _motivo = TextEditingController();
  String? _erro;

  bool get _sangria => widget.tipo == 'SANGRIA';

  @override
  void dispose() {
    _valor.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _ok() async {
    final v = lerDecimal(_valor.text);
    if (v == null || v <= 0) return setState(() => _erro = 'Informe um valor válido.');
    if (_sangria && v > widget.saldoGaveta) {
      final seguir = await confirmar(context, 'Valor maior que a gaveta',
          'A retirada (${brl(v)}) é maior que o saldo em dinheiro na gaveta (${brl(widget.saldoGaveta)}). Continuar mesmo assim?',
          ok: 'Continuar', perigo: true);
      if (!seguir) return;
    }
    if (mounted) Navigator.pop(context, (v, _motivo.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cor = _sangria ? c.amber : c.emerald;
    final atalhos = _sangria
        ? ['Guardar no Cofre', 'Depósito Bancário', 'Pagar Fornecedor', 'Troca de Turno']
        : ['Fundo de Troco Inicial', 'Mais Moedas', 'Notas Miúdas (R\$ 2, 5, 10)', 'Aporte do Dono'];
    return Dialog(
      backgroundColor: c.isLight ? Colors.white : const Color(0xFF181C23),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.isLight ? c.cardBorder : const Color(0xFF2A313E))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(_sangria ? LucideIcons.circleArrowDown : LucideIcons.circleArrowUp, size: 22, color: cor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_sangria ? 'TIRAR DINHEIRO (SANGRIA)' : 'COLOCAR TROCO (REFORÇO)', style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(_sangria ? 'Retirada segura da gaveta física' : 'Entrada de dinheiro para troco no caixa', style: TextStyle(color: c.textMuted, fontSize: 11)),
                ]),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(LucideIcons.x, size: 18, color: c.textMuted)),
            ]),
            const SizedBox(height: 14),
            if (_erro != null) ...[CicErroBanner(mensagem: _erro!), const SizedBox(height: 10)],
            CicCampo(
              rotulo: _sangria ? 'Valor a retirar (R\$) *' : 'Valor a adicionar (R\$) *',
              controller: _valor,
              dica: '0,00',
              autofocus: true,
              teclado: const TextInputType.numberWithOptions(decimal: true),
            ),
            if (_sangria) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Saldo na gaveta: ${brl(widget.saldoGaveta)}', style: TextStyle(color: c.emerald, fontSize: 11, fontWeight: FontWeight.w700))),
            const SizedBox(height: 12),
            CicCampo(rotulo: 'Motivo', controller: _motivo, dica: _sangria ? 'Ex: Guardar no cofre' : 'Ex: Troco inicial'),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final a in atalhos)
                ActionChip(label: Text(a, style: TextStyle(fontSize: 11, color: c.textSoft)), backgroundColor: c.sub, side: BorderSide(color: c.subBorder), onPressed: () => setState(() => _motivo.text = a)),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: CicBotao('Cancelar', secundario: true, onPressed: () => Navigator.pop(context))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: CicBotao(_sangria ? 'Confirmar Retirada' : 'Confirmar Troco', icone: _sangria ? LucideIcons.circleArrowDown : LucideIcons.circleArrowUp, onPressed: _ok)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _TurnoDialog extends StatelessWidget {
  const _TurnoDialog({required this.sessao, required this.totais, required this.saldoGaveta});
  final SessaoCaixa sessao;
  final ({int dinheiro, int pix, int debito, int credito, int vendas}) totais;
  final double saldoGaveta;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget linha(String t, String v, {Color? cor, bool negrito = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(t, style: TextStyle(color: c.textSoft, fontSize: 12, fontWeight: negrito ? FontWeight.w800 : FontWeight.w400))),
        Text(v, style: fonteMono(context, size: 12, cor: cor ?? c.text, peso: negrito ? FontWeight.w800 : FontWeight.w600)),
      ]),
    );
    final total = totais.dinheiro + totais.pix + totais.debito + totais.credito;
    return Dialog(
      backgroundColor: c.isLight ? Colors.white : const Color(0xFF181C23),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.isLight ? c.cardBorder : const Color(0xFF2A313E))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(LucideIcons.wallet, size: 20, color: c.gold),
              const SizedBox(width: 10),
              Expanded(child: Text('RESUMO DO TURNO DE CAIXA', style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 14))),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(LucideIcons.x, size: 18, color: c.textMuted)),
            ]),
            const SizedBox(height: 12),
            CicSub(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                linha('Operador em turno:', sessao.operador),
                linha('Abertura do caixa:', dataHora(sessao.abertaEm)),
                linha('Fundo de troco inicial:', brl(sessao.fundoTroco)),
                Divider(color: c.cardBorder),
                linha('Vendas em dinheiro:', brl(totais.dinheiro / 100)),
                linha('Vendas via PIX:', brl(totais.pix / 100), cor: c.emerald),
                linha('Vendas no cartão débito:', brl(totais.debito / 100)),
                linha('Vendas no cartão crédito:', brl(totais.credito / 100)),
                Divider(color: c.cardBorder),
                linha('(+) Reforços de troco:', '+ ${brl(sessao.totalSuprimento)}', cor: c.emerald),
                linha('(-) Retiradas (sangria):', '- ${brl(sessao.totalSangria)}', cor: c.amber),
                Divider(color: c.cardBorder),
                linha('Total de vendas no turno:', '${brl(total / 100)} (${totais.vendas})', cor: c.gold, negrito: true),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: c.emeraldBg, borderRadius: BorderRadius.circular(10)),
                  child: linha('Saldo em dinheiro na gaveta:', brl(saldoGaveta), cor: c.emerald, negrito: true),
                ),
              ]),
            ),
            if (sessao.movimentos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Movimentações registradas na gaveta:', style: TextStyle(color: c.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final m in sessao.movimentos.take(8))
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: c.sub, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.subBorder)),
                  child: Row(children: [
                    Expanded(
                      child: Text('${m.tipo == 'SANGRIA' ? 'Sangria' : 'Reforço'} • ${m.motivo}',
                          overflow: TextOverflow.ellipsis, style: TextStyle(color: m.tipo == 'SANGRIA' ? c.amber : c.emerald, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    Text('${m.tipo == 'SANGRIA' ? '-' : '+'} ${brl(m.valor)}', style: fonteMono(context, size: 11)),
                  ]),
                ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: CicBotao('Fechar turno', secundario: true, icone: LucideIcons.lock, onPressed: () async {
                final ok = await confirmar(context, 'Fechar o turno?', 'O turno atual será encerrado e um novo será aberto com o fundo de troco padrão. As vendas já feitas continuam no histórico.', ok: 'Fechar turno');
                if (ok && context.mounted) Navigator.pop(context, 'fechar');
              })),
              const SizedBox(width: 10),
              Expanded(child: CicBotao('OK', onPressed: () => Navigator.pop(context))),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _CupomDialog extends StatefulWidget {
  const _CupomDialog({required this.cupom, required this.conta});
  final _Cupom cupom;
  final ContaEstabelecimento conta;

  @override
  State<_CupomDialog> createState() => _CupomDialogState();
}

class _CupomDialogState extends State<_CupomDialog> {
  final _fone = TextEditingController();
  bool _copiado = false;

  @override
  void dispose() {
    _fone.dispose();
    super.dispose();
  }

  String _texto() {
    final v = widget.cupom;
    final c = widget.conta;
    final b = StringBuffer()
      ..writeln('*${c.nomeFantasia.toUpperCase()}*');
    if (c.razaoSocial.isNotEmpty) b.writeln(c.razaoSocial);
    if (c.documentoNumero.isNotEmpty) b.writeln('${c.documentoTipo}: ${c.documentoNumero}');
    if (c.logradouro.isNotEmpty) b.writeln('${c.logradouro}, ${c.bairro} - ${c.cidade}/${c.uf}');
    if (c.telefone.isNotEmpty) b.writeln('WhatsApp: ${c.telefone}');
    b
      ..writeln('--------------------------------')
      ..writeln('*CUPOM NÃO FISCAL:* ${v.id}')
      ..writeln('Data: ${dataHora(v.data)} | Op: ${v.operador}')
      ..writeln('--------------------------------')
      ..writeln('*ITENS DA COMPRA:*');
    for (final i in v.itens) {
      b.writeln('${i.$2}x ${i.$1} - ${brl(i.$3 / 100)}');
    }
    b
      ..writeln('--------------------------------')
      ..writeln('*TOTAL A PAGAR:* ${brl(v.totalCent / 100)}')
      ..writeln('Forma de pagamento: ${v.forma.rotulo}');
    if (v.forma == _Forma.dinheiro) {
      b
        ..writeln('Valor recebido: ${brl(v.recebidoCent / 100)}')
        ..writeln('Troco: ${brl(v.trocoCent / 100)}');
    }
    if (v.maquininha != null) b.writeln('Maquininha: ${v.maquininha}');
    if (v.nsu != null) b.writeln('Autorização / NSU: ${v.nsu}');
    if (v.chavePix != null && v.chavePix!.isNotEmpty) b.writeln('Chave PIX: ${v.chavePix}');
    b
      ..writeln('--------------------------------')
      ..writeln(c.mensagemRodape);
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = widget.cupom;
    final conta = widget.conta;
    Widget tracejado() => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1, color: c.isLight ? const Color(0xFFCBD5E1) : const Color(0xFF333333)));
    TextStyle mono(double s, {Color? cor, FontWeight w = FontWeight.w400}) => fonteMono(context, size: s, peso: w, cor: cor ?? c.textSoft);

    return Dialog(
      backgroundColor: c.isLight ? Colors.white : const Color(0xFF181C23),
      insetPadding: const EdgeInsets.all(14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.isLight ? c.cardBorder : const Color(0x99059669))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(LucideIcons.circleCheck, size: 22, color: c.emerald),
              const SizedBox(width: 10),
              Expanded(child: Text('Venda concluída com sucesso!', style: TextStyle(color: c.text, fontWeight: FontWeight.w800, fontSize: 15))),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(LucideIcons.x, size: 18, color: c.textMuted)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.isLight ? const Color(0xFFF8FAFC) : const Color(0xFF12141A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.isLight ? c.cardBorder : const Color(0xFF242A36)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(conta.nomeFantasia.toUpperCase(), textAlign: TextAlign.center, style: mono(13, cor: c.text, w: FontWeight.w800)),
                if (conta.razaoSocial.isNotEmpty) Text(conta.razaoSocial, textAlign: TextAlign.center, style: mono(10, cor: c.textMuted)),
                if (conta.documentoNumero.isNotEmpty) Text('${conta.documentoTipo}: ${conta.documentoNumero}', textAlign: TextAlign.center, style: mono(10, cor: c.textMuted)),
                if (conta.logradouro.isNotEmpty)
                  Text('${conta.logradouro}, ${conta.bairro} - ${conta.cidade}/${conta.uf}', textAlign: TextAlign.center, style: mono(10, cor: c.textMuted)),
                tracejado(),
                Row(children: [
                  Expanded(child: Text('CUPOM: ${v.id}', style: mono(11, cor: c.textMuted))),
                  Text(dataHora(v.data), style: mono(11, cor: c.textMuted)),
                ]),
                Text('Operador: ${v.operador}', style: mono(10, cor: c.textMuted)),
                tracejado(),
                Row(children: [
                  Expanded(child: Text('QTD X ITEM', style: mono(10, cor: c.textMuted, w: FontWeight.w800))),
                  Text('TOTAL (R\$)', style: mono(10, cor: c.textMuted, w: FontWeight.w800)),
                ]),
                const SizedBox(height: 4),
                for (final i in v.itens)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(children: [
                      Expanded(child: Text('${i.$2}x ${i.$1}', overflow: TextOverflow.ellipsis, style: mono(12))),
                      Text((i.$3 / 100).toStringAsFixed(2).replaceAll('.', ','), style: mono(12, w: FontWeight.w700)),
                    ]),
                  ),
                tracejado(),
                Row(children: [
                  Text('TOTAL:', style: mono(14, cor: c.emerald, w: FontWeight.w800)),
                  const Spacer(),
                  Text(brl(v.totalCent / 100), style: mono(14, cor: c.emerald, w: FontWeight.w800)),
                ]),
                const SizedBox(height: 4),
                Row(children: [Text('Forma de pagto:', style: mono(11, cor: c.textMuted)), const Spacer(), Text(v.forma.rotulo, style: mono(11, cor: c.text, w: FontWeight.w700))]),
                if (v.forma == _Forma.dinheiro) ...[
                  Row(children: [Text('Valor recebido:', style: mono(11, cor: c.textMuted)), const Spacer(), Text(brl(v.recebidoCent / 100), style: mono(11))]),
                  Row(children: [Text('Troco:', style: mono(11, cor: c.amber, w: FontWeight.w800)), const Spacer(), Text(brl(v.trocoCent / 100), style: mono(11, cor: c.amber, w: FontWeight.w800))]),
                ],
                if (v.maquininha != null) Row(children: [Text('Maquininha:', style: mono(10, cor: c.textMuted)), const Spacer(), Flexible(child: Text(v.maquininha!, overflow: TextOverflow.ellipsis, style: mono(10, cor: c.text)))]),
                if (v.nsu != null) Row(children: [Text('NSU / Aut:', style: mono(10, cor: c.textMuted)), const Spacer(), Text(v.nsu!, style: mono(10, cor: c.emerald))]),
                tracejado(),
                Text(conta.mensagemRodape, textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, fontSize: 10, fontStyle: FontStyle.italic)),
              ]),
            ),
            const SizedBox(height: 12),
            CicBotao(_copiado ? 'Copiado!' : 'Copiar texto do cupom', icone: _copiado ? LucideIcons.check : LucideIcons.copy, secundario: true, onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _texto()));
              setState(() => _copiado = true);
              Future.delayed(const Duration(seconds: 2), () => mounted ? setState(() => _copiado = false) : null);
            }),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: CicCampo(controller: _fone, dica: 'WhatsApp (DDD + número)', teclado: TextInputType.phone)),
              const SizedBox(width: 8),
              Material(
                color: const Color(0xFF059669),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final fone = _fone.text.replaceAll(RegExp(r'\D'), '');
                    final url = fone.isEmpty
                        ? 'https://api.whatsapp.com/send?text=${Uri.encodeComponent(_texto())}'
                        : 'https://api.whatsapp.com/send?phone=${fone.startsWith('55') ? fone : '55$fone'}&text=${Uri.encodeComponent(_texto())}';
                    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.share2, size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Text('WhatsApp', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            CicBotao('Nova Venda (Frente de Caixa)', largo: true, onPressed: () => Navigator.pop(context)),
          ]),
        ),
      ),
    );
  }
}
