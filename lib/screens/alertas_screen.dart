import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/shell.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';

/// Central de Alertas (porte de `AlertasScreen.tsx`). Os alertas são gerados
/// pelos triggers do banco (validade, estoque baixo, margem) e lidos daqui.
class AlertasScreen extends StatefulWidget {
  const AlertasScreen({super.key, required this.estado, required this.onNavegar});
  final AppState estado;
  final void Function(NavTab, {String? codigo}) onNavegar;

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  String _filtro = 'todos';
  bool _soNaoLidos = false;

  AppState get e => widget.estado;

  Future<void> _tentar(Future<void> Function() f) async {
    try {
      await f();
    } on ErroCic catch (er) {
      if (mounted) aviso(context, er.mensagem, erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final todos = e.alertas;
    final lista = todos.where((a) {
      if (_soNaoLidos && a.lido) return false;
      if (_filtro != 'todos' && a.severidade != _filtro) return false;
      return true;
    }).toList();
    final naoLidos = e.alertasNaoLidos;
    int qtd(String s) => todos.where((a) => a.severidade == s).length;

    return CicPagina(children: [
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CicCard(
              child: Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text('CENTRAL DE ALERTAS OPERACIONAIS', style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                    if (naoLidos > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(99)),
                        child: Text('$naoLidos pendentes', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                  ]),
                  const SizedBox(height: 2),
                  Text('Monitoramento preventivo de validades, quebra de estoque e risco de prejuízo', style: TextStyle(color: c.textMuted, fontSize: 11.5)),
                ]),
                if (naoLidos > 0)
                  CicBotao('Marcar todos como lidos', icone: LucideIcons.checkCheck, secundario: true, compacto: true, onPressed: () => _tentar(e.marcarTodosAlertasLidos)),
              ]),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.cardBorder)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _aba(c, 'todos', 'Todos (${todos.length})', c.botao, Colors.black),
                  _aba(c, 'CRITICO', 'Críticos (${qtd('CRITICO')})', const Color(0xFFDC2626), Colors.white),
                  _aba(c, 'ALTO', 'Altos (${qtd('ALTO')})', const Color(0xFFD97706), Colors.white),
                  _aba(c, 'MEDIO', 'Médios', const Color(0xFF2563EB), Colors.white),
                ]),
              ),
              InkWell(
                onTap: () => setState(() => _soNaoLidos = !_soNaoLidos),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Checkbox(value: _soNaoLidos, activeColor: c.gold, checkColor: Colors.black, onChanged: (v) => setState(() => _soNaoLidos = v ?? false), visualDensity: VisualDensity.compact),
                  Text('Exibir somente não lidos', style: TextStyle(color: c.textSoft, fontSize: 12)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            if (lista.isEmpty)
              CicCard(
                child: CicVazio(
                  icone: LucideIcons.checkCheck,
                  titulo: 'Nenhum alerta pendente',
                  texto: 'Seu estoque está em dia com validades e controle de margem anti-falência.',
                ),
              )
            else
              for (final a in lista) Padding(padding: const EdgeInsets.only(bottom: 12), child: _alerta(c, a)),
          ]),
        ),
      ),
    ]);
  }

  Widget _aba(CicPalette c, String id, String t, Color bg, Color fg) {
    final ativo = _filtro == id;
    return GestureDetector(
      onTap: () => setState(() => _filtro = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: ativo ? bg : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: TextStyle(color: ativo ? fg : c.textMuted, fontSize: 12, fontWeight: ativo ? FontWeight.w800 : FontWeight.w500)),
      ),
    );
  }

  Widget _alerta(CicPalette c, Alerta a) {
    final (icone, corIcone) = switch (a.tipo) {
      'VALIDADE' => (LucideIcons.calendar, c.amber),
      'ESTOQUE_BAIXO' => (LucideIcons.boxes, const Color(0xFF60A5FA)),
      'PREJUIZO' => (LucideIcons.trendingDown, c.red),
      _ => (LucideIcons.sparkles, c.gold),
    };
    final tom = switch (a.severidade) {
      'CRITICO' => BadgeTom.vermelho,
      'ALTO' => BadgeTom.ambar,
      'MEDIO' => BadgeTom.ouro,
      _ => BadgeTom.neutro,
    };
    final rotulo = switch (a.severidade) { 'CRITICO' => 'CRÍTICO', 'ALTO' => 'ALTO', 'MEDIO' => 'MÉDIO', _ => 'INFO' };
    Color? fundo;
    Color? borda;
    if (a.lido) {
      fundo = c.isLight ? const Color(0xFFF8FAFC) : const Color(0xFF141414);
      borda = c.isLight ? c.cardBorder : const Color(0xFF222222);
    } else if (a.severidade == 'CRITICO') {
      fundo = c.redBg;
      borda = c.redBorder;
    } else if (a.severidade == 'ALTO') {
      fundo = c.amberBg;
      borda = c.amberBorder;
    }
    return Opacity(
      opacity: a.lido ? 0.75 : 1,
      child: CicCard(
        cor: fundo,
        borda: borda,
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF202020),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.isLight ? c.cardBorder : const Color(0xFF333333)),
            ),
            child: Icon(icone, size: 18, color: corIcone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                CicBadge(rotulo, tom: tom),
                Text('${dataCurta(a.criadoEm)} • ${a.tipo}', style: fonteMono(context, size: 11, peso: FontWeight.w400, cor: c.textMuted)),
              ]),
              const SizedBox(height: 6),
              Text(a.mensagem, style: TextStyle(color: c.textSoft, fontSize: 13, fontWeight: FontWeight.w500, height: 1.45)),
              if (a.produtoCodigo != null && a.produtoCodigo!.isNotEmpty && !a.lido) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => widget.onNavegar(NavTab.estoque),
                  child: Text('Ver no estoque', style: TextStyle(color: c.gold, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
          ),
          if (!a.lido)
            IconButton(
              tooltip: 'Marcar como lido',
              onPressed: () => _tentar(() => e.marcarAlertaLido(a.id)),
              icon: Icon(LucideIcons.check, size: 16, color: c.textSoft),
              style: IconButton.styleFrom(backgroundColor: c.sub),
            ),
        ]),
      ),
    );
  }
}
