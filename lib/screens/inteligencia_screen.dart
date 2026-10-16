import 'package:cic_domain/cic_domain.dart' as dom;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/repository.dart';
import '../services/ia_consultor.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';

class _Msg {
  _Msg({required this.deUsuario, required this.texto, this.origem, this.aviso, DateTime? quando}) : quando = quando ?? DateTime.now();
  final bool deUsuario;
  final String texto;
  final dom.OrigemResposta? origem;
  final String? aviso;
  final DateTime quando;
}

/// Inteligência IA (porte de `InteligenciaScreen.tsx`).
///
///  * A auditoria é calculada dos dados reais (sem IA) e sempre funciona.
///  * O chat responde perguntas objetivas sem IA; análise aberta passa pelo
///    Gemini e é descartada se citar qualquer dado que não foi calculado.
///  * Cada resposta mostra de onde veio (calculado, IA ou fallback seguro).
class InteligenciaScreen extends StatefulWidget {
  const InteligenciaScreen({super.key, required this.estado});
  final AppState estado;

  @override
  State<InteligenciaScreen> createState() => _InteligenciaScreenState();
}

class _InteligenciaScreenState extends State<InteligenciaScreen> {
  late final IaConsultor _consultor = IaConsultor(widget.estado);
  final _entrada = TextEditingController();
  final _rolagem = ScrollController();
  final List<_Msg> _msgs = [
    _Msg(
      deUsuario: false,
      origem: dom.OrigemResposta.deterministica,
      texto: 'Olá! Sou o consultor do APP-CIC. Respondo estoque, faturamento, mais vendidos, curva ABC, validades e o que está acabando direto dos seus números, sem inventar nada. Para análises abertas, uso IA, mas descarto qualquer resposta que não bata com os dados calculados.',
    ),
  ];
  bool _enviando = false;
  bool _gerando = false;
  bool _verHistorico = false;
  List<Map<String, dynamic>> _salvos = [];
  Map<String, dynamic>? _ativo;
  String? _erroSalvos;
  bool _copiado = false;

  static const _sugestoes = [
    'O que tenho no meu estoque agora?',
    'Quanto faturei nos últimos 30 dias?',
    'Qual o produto mais vendido?',
    'Quais produtos estão acabando?',
    'Quais produtos vencem em breve?',
    'Como atingir o ponto de equilíbrio?',
    'Quais produtos têm markup abaixo de 1,30x?',
  ];

  AppState get e => widget.estado;

  @override
  void initState() {
    super.initState();
    _carregarSalvos();
  }

  @override
  void dispose() {
    _entrada.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _carregarSalvos() async {
    try {
      final r = await e.repo.relatoriosIa();
      if (!mounted) return;
      setState(() {
        _salvos = r;
        _ativo ??= r.isEmpty ? null : r.first;
        _erroSalvos = null;
      });
    } on ErroCic catch (er) {
      if (mounted) setState(() => _erroSalvos = er.mensagem);
    }
  }

  void _descer() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_rolagem.hasClients) _rolagem.animateTo(_rolagem.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  });

  Future<void> _enviar([String? texto]) async {
    final t = (texto ?? _entrada.text).trim();
    if (t.isEmpty || _enviando) return;
    setState(() {
      _msgs.add(_Msg(deUsuario: true, texto: t));
      _enviando = true;
      if (texto == null) _entrada.clear();
    });
    _descer();
    try {
      final r = await _consultor.perguntar(t);
      if (mounted && r != null) {
        setState(() => _msgs.add(_Msg(deUsuario: false, texto: r.resposta, origem: r.origem, aviso: r.aviso)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _msgs.add(_Msg(deUsuario: false, texto: 'Não consegui concluir a consulta agora. Tente de novo.')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
    _descer();
  }

  Future<void> _auditar() async {
    if (!e.estoqueConfiavel) {
      aviso(context, 'Estoque não carregado. Atualize a tela e tente de novo.', erro: true);
      return;
    }
    setState(() => _gerando = true);
    try {
      var texto = montarAuditoria(e);
      // Comentário opcional de IA, já validado. Se falhar, a auditoria segue completa.
      final c = await _consultor.comentarioSobreAuditoria();
      if (c.origem == dom.OrigemResposta.ia) {
        texto += '\n\n## 5. Leitura do consultor (IA validada)\n${c.resposta}';
      }
      var custo = 0, retorno = 0;
      for (final p in e.estoque) {
        custo += centavos(p.valorCompra) * p.quantidade;
        retorno += centavos(p.valorVenda) * p.quantidade;
      }
      await e.repo.salvarRelatorioIa(
        conteudo: texto,
        metricas: {
          'totalProdutos': e.estoque.length,
          'custoTotal': custo / 100,
          'faturamentoTotal': retorno / 100,
          'produtosCriticos': e.alertas.where((a) => a.severidade == 'CRITICO' && !a.lido).length,
        },
      );
      await _carregarSalvos();
      if (mounted && _salvos.isNotEmpty) setState(() => _ativo = _salvos.first);
    } on ErroCic catch (er) {
      if (mounted) aviso(context, er.mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  Future<void> _excluir(Map<String, dynamic> r) async {
    final ok = await confirmar(context, 'Excluir relatório', 'Excluir este relatório do seu histórico?', ok: 'Excluir', perigo: true);
    if (!ok) return;
    try {
      await e.repo.excluirRelatorioIa((r['id'] as num).toInt());
      if (_ativo?['id'] == r['id']) _ativo = null;
      await _carregarSalvos();
    } on ErroCic catch (er) {
      if (mounted) aviso(context, er.mensagem, erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return CicPagina(children: [
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _banner(c),
            if (_verHistorico && _salvos.isNotEmpty) ...[const SizedBox(height: 16), _historico(c)],
            if (_erroSalvos != null) ...[const SizedBox(height: 16), CicErroBanner(mensagem: _erroSalvos!, onTentar: _carregarSalvos)],
            if (_ativo != null) ...[const SizedBox(height: 16), _relatorio(c, _ativo!)],
            const SizedBox(height: 16),
            _chat(c),
          ]),
        ),
      ),
    ]);
  }

  Widget _banner(CicPalette c) => CicCard(
    padding: const EdgeInsets.all(22),
    gradiente: LinearGradient(
      colors: c.isLight ? const [Color(0xFFFEF9EE), Colors.white] : const [Color(0xFF171511), Color(0xFF1A1813), Color(0xFF121212)],
    ),
    borda: c.isLight ? const Color(0xFFF3D58C) : c.gold.withValues(alpha: 0.3),
    child: Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CicIconeCaixa(LucideIcons.sparkles, tom: BadgeTom.ouro, tamanho: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('Auditoria Financeira & Preditiva', style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w800)),
                const CicBadge('IA aterrada em dados reais', tom: BadgeTom.verde),
              ]),
              const SizedBox(height: 6),
              Text('Cruza estoque, validade, custos, margens e vendas reais para gerar um diagnóstico salvo na sua conta. Os números vêm do cálculo, não da IA.',
                  style: TextStyle(color: c.textMuted, fontSize: 12, height: 1.4)),
            ]),
          ),
        ]),
      ),
      Wrap(spacing: 10, runSpacing: 10, children: [
        if (_salvos.isNotEmpty)
          CicBotao('Salvos (${_salvos.length})', icone: LucideIcons.bookmark, secundario: true, onPressed: () => setState(() => _verHistorico = !_verHistorico)),
        CicBotao(_gerando ? 'Gerando...' : 'Executar Auditoria Completa', icone: LucideIcons.sparkles, carregando: _gerando, onPressed: _auditar),
      ]),
    ]),
  );

  Widget _historico(CicPalette c) => CicCard(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(LucideIcons.bookmark, size: 14, color: c.gold),
        const SizedBox(width: 6),
        Text('HISTÓRICO DE RELATÓRIOS', style: TextStyle(color: c.textSoft, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      ]),
      const SizedBox(height: 12),
      CicGrid(minLargura: 250, espaco: 10, maxColunas: 3, children: [
        for (final r in _salvos)
          GestureDetector(
            onTap: () => setState(() => _ativo = r),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _ativo?['id'] == r['id'] ? c.goldBg : c.sub,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _ativo?['id'] == r['id'] ? c.gold : c.subBorder),
              ),
              child: Row(children: [
                Icon(LucideIcons.fileText, size: 14, color: _ativo?['id'] == r['id'] ? c.gold : c.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Auditoria ${dataCurta(DateTime.tryParse('${r['criado_em']}'))}', style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(dataHora(DateTime.tryParse('${r['criado_em']}')), style: TextStyle(color: c.textMuted, fontSize: 10)),
                  ]),
                ),
                IconButton(visualDensity: VisualDensity.compact, onPressed: () => _excluir(r), icon: Icon(LucideIcons.trash2, size: 13, color: c.textMuted)),
              ]),
            ),
          ),
      ]),
    ]),
  );

  Widget _relatorio(CicPalette c, Map<String, dynamic> r) {
    final m = Map<String, dynamic>.from((r['metricas'] as Map?) ?? const {});
    final texto = '${r['conteudo_markdown']}';
    return CicCard(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(LucideIcons.shieldCheck, size: 20, color: c.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AUDITORIA ESTRATÉGICA', style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              Text('Gerado em ${dataHora(DateTime.tryParse('${r['criado_em']}'))}', style: TextStyle(color: c.textMuted, fontSize: 11)),
            ]),
          ),
          CicBotao(_copiado ? 'Copiado!' : 'Copiar', icone: _copiado ? LucideIcons.check : LucideIcons.copy, secundario: true, compacto: true, onPressed: () async {
            await Clipboard.setData(ClipboardData(text: texto));
            setState(() => _copiado = true);
            Future.delayed(const Duration(seconds: 2), () => mounted ? setState(() => _copiado = false) : null);
          }),
          TextButton(onPressed: () => setState(() => _ativo = null), child: Text('Recolher', style: TextStyle(color: c.textMuted, fontSize: 12))),
        ]),
        if (m.isNotEmpty) ...[
          const SizedBox(height: 14),
          CicSub(
            child: CicGrid(minLargura: 130, espaco: 10, maxColunas: 4, children: [
              _mini(c, 'Produtos no mix', '${m['totalProdutos'] ?? '—'}', c.text),
              _mini(c, 'Custo de estoque', m['custoTotal'] is num ? brl(m['custoTotal'] as num) : '—', c.textSoft),
              _mini(c, 'Faturamento proj.', m['faturamentoTotal'] is num ? brl(m['faturamentoTotal'] as num) : '—', c.emerald),
              _mini(c, 'Itens críticos', '${m['produtosCriticos'] ?? '—'}', c.red),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.isLight ? const Color(0xFFF8FAFC) : const Color(0xFF121212),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.isLight ? c.cardBorder : const Color(0xFF222222)),
          ),
          child: MarkdownBody(
            data: texto,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(color: c.textSoft, fontSize: 13, height: 1.5),
              listBullet: TextStyle(color: c.textSoft, fontSize: 13),
              h2: TextStyle(color: c.gold, fontSize: 14, fontWeight: FontWeight.w800, height: 2),
              strong: TextStyle(color: c.text, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _mini(CicPalette c, String t, String v, Color cor) => Column(children: [
    Text(t.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, fontSize: 9.5)),
    const SizedBox(height: 3),
    FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: TextStyle(color: cor, fontSize: 13, fontWeight: FontWeight.w800))),
  ]);

  Widget _chat(CicPalette c) {
    return Container(
      height: 600,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          color: c.isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1A1A1A),
          child: Row(children: [
            CicIconeCaixa(LucideIcons.bot, tom: BadgeTom.verde),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Consultor de Inteligência de Negócios', style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w800)),
                Text('Estoque, faturamento, ABC, validade e margem', style: TextStyle(color: c.textMuted, fontSize: 11)),
              ]),
            ),
            IconButton(
              tooltip: 'Limpar conversa',
              onPressed: () => setState(() => _msgs.removeRange(1, _msgs.length)),
              icon: Icon(LucideIcons.trash2, size: 15, color: c.textMuted),
            ),
          ]),
        ),
        Divider(height: 1, color: c.cardBorder),
        Expanded(
          child: ListView(
            controller: _rolagem,
            padding: const EdgeInsets.all(16),
            children: [
              for (final m in _msgs) _bolha(c, m),
              if (_enviando)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.gold)),
                    const SizedBox(width: 10),
                    Text('Analisando os dados da sua loja...', style: TextStyle(color: c.textMuted, fontSize: 12)),
                  ]),
                ),
            ],
          ),
        ),
        Container(
          height: 44,
          color: c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF141414),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              Center(child: Icon(LucideIcons.lightbulb, size: 13, color: c.textMuted)),
              const SizedBox(width: 8),
              for (final s in _sugestoes)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: _enviando ? null : () => _enviar(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.sub, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.subBorder)),
                      child: Text(s, style: TextStyle(color: c.textSoft, fontSize: 11)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          color: c.isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1A1A1A),
          child: Row(children: [
            Expanded(
              child: CicCampo(controller: _entrada, dica: 'Pergunte sobre o seu negócio...', onSubmitted: (_) => _enviar(), enabled: !_enviando),
            ),
            const SizedBox(width: 8),
            CicBotao('Enviar', icone: LucideIcons.send, onPressed: _enviando ? null : () => _enviar()),
          ]),
        ),
      ]),
    );
  }

  Widget _bolha(CicPalette c, _Msg m) {
    final user = m.deUsuario;
    final (rotuloOrigem, tom) = switch (m.origem) {
      dom.OrigemResposta.ia => ('IA validada', BadgeTom.ouro),
      dom.OrigemResposta.fallbackSeguro => ('Dados calculados (IA indisponível)', BadgeTom.ambar),
      _ => ('Calculado dos seus dados', BadgeTom.verde),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!user) ...[Container(width: 30, height: 30, decoration: BoxDecoration(color: c.sub, borderRadius: BorderRadius.circular(10)), child: Icon(LucideIcons.bot, size: 16, color: c.gold)), const SizedBox(width: 10)],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(crossAxisAlignment: user ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: user ? c.botao : (c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF202020)),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(user ? 16 : 4),
                      topRight: Radius.circular(user ? 4 : 16),
                      bottomLeft: const Radius.circular(16),
                      bottomRight: const Radius.circular(16),
                    ),
                    border: user ? null : Border.all(color: c.isLight ? c.cardBorder : const Color(0xFF2E2E2E)),
                  ),
                  child: SelectableText(m.texto, style: TextStyle(color: user ? Colors.black : c.textSoft, fontSize: 13, height: 1.5, fontWeight: user ? FontWeight.w600 : FontWeight.w400)),
                ),
                const SizedBox(height: 4),
                if (!user && m.origem != null) CicBadge(rotuloOrigem, tom: tom),
                if (m.aviso != null)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text(m.aviso!, style: TextStyle(color: c.amber, fontSize: 11, fontWeight: FontWeight.w600))),
                Padding(padding: const EdgeInsets.only(top: 3), child: Text(dataHora(m.quando), style: TextStyle(color: c.textMuted, fontSize: 10))),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
