import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme.dart';
import '../data/auth_service.dart';
import '../screens/alertas_screen.dart';
import '../screens/conta_modal.dart';
import '../screens/custos_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/estoque_screen.dart';
import '../screens/inteligencia_screen.dart';
import '../screens/leitor_screen.dart';
import '../screens/movimentacoes_screen.dart';
import '../screens/pdv_screen.dart';
import '../screens/scanner_modal.dart';
import '../screens/suporte_screen.dart';
import '../screens/xml_screen.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';

enum NavTab {
  dashboard('Visão Geral', 'Dashboard Executivo & Inteligência', LucideIcons.layoutDashboard),
  leitor('Leitor GS1 & Cadastro', 'Leitor de Código de Barras GS1 & Cadastro', LucideIcons.barcode),
  xml('Importador XML (NF-e)', 'Importador de XML (NF-e / NFC-e SEFAZ)', LucideIcons.fileSpreadsheet),
  estoque('Estoque Atual', 'Inventário & Controle de Estoque', LucideIcons.boxes),
  movimentacoes('Histórico & Movimentações', 'Histórico de Entradas & Saídas', LucideIcons.arrowDownUp),
  inteligencia('Inteligência IA', 'Consultoria Preditiva com IA', LucideIcons.sparkles),
  custos('Custos & Despesas', 'Custos Fixos & Despesas Variáveis', LucideIcons.dollarSign),
  alertas('Central de Alertas', 'Central de Alertas & Notificações', LucideIcons.bell),
  pdv('Frente de Caixa (PDV)', 'Frente de Caixa (PDV Ágil)', LucideIcons.shoppingCart),
  suporte('Ajuda & Suporte', 'Ajuda, Suporte & Prompt do Sistema', LucideIcons.lifeBuoy);

  const NavTab(this.rotulo, this.titulo, this.icone);
  final String rotulo;
  final String titulo;
  final IconData icone;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.estado, required this.auth});
  final AppState estado;
  final AuthService auth;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  NavTab _aba = NavTab.dashboard;
  final _scaffold = GlobalKey<ScaffoldState>();
  String? _codigoInicialLeitor;

  AppState get e => widget.estado;

  @override
  void initState() {
    super.initState();
    e.carregar();
  }

  void _ir(NavTab t, {String? codigo}) {
    setState(() {
      _aba = t;
      if (t == NavTab.leitor) _codigoInicialLeitor = codigo;
    });
  }

  Future<void> _sair() async {
    final ok = await confirmar(context, 'Sair da conta', 'Deseja encerrar a sessão neste aparelho?', ok: 'Sair', perigo: true);
    if (!ok) return;
    e.limpar();
    await widget.auth.sair();
  }

  Future<void> _abrirScanner([ValueChanged<String>? aoLer]) async {
    final codigo = await abrirScanner(context);
    if (codigo == null || !mounted) return;
    if (aoLer != null) {
      aoLer(codigo);
    } else {
      _ir(NavTab.leitor, codigo: codigo);
    }
  }

  void _abrirConta() => abrirContaModal(context, e);

  Widget _tela() {
    switch (_aba) {
      case NavTab.dashboard:
        return DashboardScreen(estado: e, onNavegar: _ir);
      case NavTab.leitor:
        return LeitorScreen(
          key: ValueKey('leitor-${_codigoInicialLeitor ?? ''}'),
          estado: e,
          codigoInicial: _codigoInicialLeitor,
          onAbrirScanner: _abrirScanner,
          onSalvo: () => _ir(NavTab.estoque),
        );
      case NavTab.estoque:
        return EstoqueScreen(estado: e, onNavegar: _ir);
      case NavTab.xml:
        return XmlScreen(estado: e, onConcluido: () => _ir(NavTab.estoque));
      case NavTab.movimentacoes:
        return MovimentacoesScreen(estado: e);
      case NavTab.inteligencia:
        return InteligenciaScreen(estado: e);
      case NavTab.custos:
        return CustosScreen(estado: e);
      case NavTab.alertas:
        return AlertasScreen(estado: e, onNavegar: _ir);
      case NavTab.pdv:
        return PdvScreen(estado: e, onAbrirScanner: _abrirScanner);
      case NavTab.suporte:
        return SuporteScreen(estado: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListenableBuilder(
      listenable: Listenable.merge([e, e.tema]),
      builder: (context, _) {
        final largo = MediaQuery.sizeOf(context).width >= 1024;
        final menu = _Sidebar(
          ativa: _aba,
          alertas: e.alertasNaoLidos,
          estado: e,
          onSelecionar: (t) {
            _ir(t);
            if (!largo) Navigator.of(context).maybePop();
          },
          onConta: _abrirConta,
          onSair: _sair,
        );
        return Scaffold(
          key: _scaffold,
          backgroundColor: c.bg,
          drawer: largo ? null : Drawer(width: 270, backgroundColor: c.sidebar, child: menu),
          body: SafeArea(
            child: Row(
              children: [
                if (largo) SizedBox(width: 256, child: menu),
                Expanded(
                  child: Column(
                    children: [
                      _Header(
                        aba: _aba,
                        largo: largo,
                        alertas: e.alertasNaoLidos,
                        estado: e,
                        onMenu: () => _scaffold.currentState?.openDrawer(),
                        onIr: _ir,
                        onScanner: () => _abrirScanner(),
                        onConta: _abrirConta,
                        onSair: _sair,
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          color: c.gold,
                          backgroundColor: c.card,
                          onRefresh: e.carregar,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1400),
                              child: _corpo(c),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Celular: barra fixa com as 5 ações do dia a dia, botões grandes e com nome.
          bottomNavigationBar: largo ? null : _BarraInferior(aba: _aba, alertas: e.alertasNaoLidos, onIr: _ir, onBipar: () => _abrirScanner()),
        );
      },
    );
  }

  Widget _corpo(CicPalette c) {
    final erroEstoque = e.erros['estoque'];
    // Primeira carga: spinner, nunca "estoque vazio".
    if (!e.carregouUmaVez) {
      return Center(child: CircularProgressIndicator(color: c.gold));
    }
    return Column(
      children: [
        if (e.erros.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CicErroBanner(
              mensagem: erroEstoque != null
                  ? '$erroEstoque Os saldos mostrados podem estar desatualizados.'
                  : 'Não foi possível atualizar: ${e.erros.keys.join(', ')}.',
              onTentar: e.carregar,
            ),
          ),
        Expanded(child: _tela()),
      ],
    );
  }
}

// ============================ SIDEBAR ============================

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.ativa,
    required this.alertas,
    required this.estado,
    required this.onSelecionar,
    required this.onConta,
    required this.onSair,
  });

  final NavTab ativa;
  final int alertas;
  final AppState estado;
  final ValueChanged<NavTab> onSelecionar;
  final VoidCallback onConta;
  final VoidCallback onSair;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final u = estado.usuario;
    return Container(
      decoration: BoxDecoration(color: c.sidebar, border: Border(right: BorderSide(color: c.cardBorder))),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.cardBorder))),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(colors: [Color(0xFFD4A843), Color(0xFFF3D58C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      boxShadow: [BoxShadow(color: c.gold.withValues(alpha: 0.2), blurRadius: 8)],
                    ),
                    child: const Icon(LucideIcons.barcode, size: 20, color: Colors.black),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('APP-CIC',
                              style: GoogleFonts.outfit(color: c.text, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: c.gold.withValues(alpha: 0.3)),
                            ),
                            child: Text('v2.0', style: TextStyle(color: c.gold, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                        Text('Gestão de Estoque & IA', style: TextStyle(color: c.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                children: [
                  _secao(c, 'Módulos principais'),
                  for (final t in NavTab.values.take(4)) _item(c, t),
                  const SizedBox(height: 8),
                  _secao(c, 'Operação & controle'),
                  for (final t in NavTab.values.skip(4)) _item(c, t, badge: t == NavTab.alertas ? alertas : 0),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.isLight ? const Color(0xFFF8FAFC) : const Color(0xFF0E0E0E),
                border: Border(top: BorderSide(color: c.cardBorder)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: estado.tema.alternar,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: c.isLight ? Colors.white : const Color(0xFF181818),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.inputBorder),
                      ),
                      child: Row(children: [
                        Icon(c.isLight ? LucideIcons.moon : LucideIcons.sun, size: 15, color: c.isLight ? const Color(0xFF4F46E5) : c.gold),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Tema: ${c.isLight ? 'Modo Claro' : 'Modo Escuro'}', style: TextStyle(color: c.textSoft, fontSize: 12))),
                        CicBadge('Trocar', tom: BadgeTom.ouro),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Acessibilidade: aumentar a letra do app inteiro.
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: estado.tema.proximaEscala,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: c.isLight ? Colors.white : const Color(0xFF181818),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.inputBorder),
                      ),
                      child: Row(children: [
                        Icon(LucideIcons.aLargeSmall, size: 16, color: c.gold),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Letra: ${estado.tema.rotuloEscala}', style: TextStyle(color: c.textSoft, fontSize: 12))),
                        const CicBadge('Aumentar', tom: BadgeTom.ouro),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.isLight ? Colors.white : const Color(0xFF161616),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.isLight ? c.cardBorder : const Color(0xFF262626)),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: InkWell(
                          onTap: onConta,
                          child: Row(children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.25), spreadRadius: 3)],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(u?.lojaNome ?? 'Loja Principal',
                                    overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w700)),
                                Text(u == null ? 'PDV Ativo • Configurar' : '${u.nome} • Configurar',
                                    overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textMuted, fontSize: 10)),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Configurar conta do estabelecimento',
                        onPressed: onConta,
                        icon: Icon(LucideIcons.settings, size: 15, color: c.textMuted),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Sair da conta',
                        onPressed: onSair,
                        icon: Icon(LucideIcons.logOut, size: 15, color: c.textMuted),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secao(CicPalette c, String t) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    child: Text(t.toUpperCase(), style: TextStyle(color: c.textMuted.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
  );

  Widget _item(CicPalette c, NavTab t, {int badge = 0}) {
    final ativo = ativa == t;
    final corAtiva = c.gold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelecionar(t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: ativo ? (c.isLight ? const Color(0x26F59E0B) : c.gold.withValues(alpha: 0.15)) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ativo ? c.gold.withValues(alpha: c.isLight ? 0.4 : 0.3) : Colors.transparent),
            ),
            child: Row(children: [
              Icon(t.icone, size: 18, color: ativo ? corAtiva : c.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(t.rotulo,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
                      color: ativo ? (c.isLight ? const Color(0xFF92400E) : corAtiva) : (c.isLight ? const Color(0xFF475569) : const Color(0xFFD4D4D4)),
                    )),
              ),
              if (badge > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(99)),
                  child: Text('$badge', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ============================ HEADER ============================

class _Header extends StatelessWidget {
  const _Header({
    required this.aba,
    required this.largo,
    required this.alertas,
    required this.estado,
    required this.onMenu,
    required this.onIr,
    required this.onScanner,
    required this.onConta,
    required this.onSair,
  });

  final NavTab aba;
  final bool largo;
  final int alertas;
  final AppState estado;
  final VoidCallback onMenu;
  final void Function(NavTab) onIr;
  final VoidCallback onScanner;
  final VoidCallback onConta;
  final VoidCallback onSair;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final largura = MediaQuery.sizeOf(context).width;
    final sm = largura >= 640;
    final md = largura >= 768;
    final u = estado.usuario;

    Widget caixa(IconData i, VoidCallback f, {Color? cor, int badge = 0, String? dica}) => Tooltip(
      message: dica ?? '',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: f,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.isLight ? c.cardBorder : const Color(0xFF303030)),
            ),
            child: Icon(i, size: 16, color: cor ?? c.textSoft),
          ),
          if (badge > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      ),
    );

    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: sm ? 24 : 12),
      decoration: BoxDecoration(
        color: c.isLight ? c.header : c.header.withValues(alpha: 0.92),
        border: Border(bottom: BorderSide(color: c.cardBorder)),
      ),
      child: Row(
        children: [
          if (!largo)
            IconButton(
              onPressed: onMenu,
              tooltip: 'Abrir menu',
              icon: Icon(LucideIcons.menu, size: 20, color: c.textSoft),
            ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(aba.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.text, fontSize: sm ? 15 : 12.5, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                if (sm)
                  Text('Padrão GS1 Brasil • Algoritmo Anti-Falência • IA aterrada em dados reais',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textMuted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Bipar código
          Material(
            color: c.botao,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onScanner,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: sm ? 12 : 10, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.barcode, size: 16, color: Colors.black),
                  if (sm) const SizedBox(width: 6),
                  if (sm) const Text('Bipar Código', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
          if (md) ...[
            const SizedBox(width: 8),
            caixa(LucideIcons.shoppingBag, () => onIr(NavTab.pdv), cor: c.gold, dica: 'Abrir Caixa / PDV'),
          ],
          if (sm) ...[
            const SizedBox(width: 8),
            caixa(LucideIcons.arrowDownUp, () => onIr(NavTab.movimentacoes), dica: 'Histórico de entradas e saídas'),
          ],
          const SizedBox(width: 8),
          caixa(c.isLight ? LucideIcons.moon : LucideIcons.sun, estado.tema.alternar,
              cor: c.isLight ? const Color(0xFF4F46E5) : const Color(0xFFFBBF24), dica: 'Alternar tema'),
          const SizedBox(width: 8),
          caixa(LucideIcons.sparkles, () => onIr(NavTab.inteligencia), cor: c.gold, dica: 'Consultor IA'),
          const SizedBox(width: 8),
          caixa(LucideIcons.bell, () => onIr(NavTab.alertas), badge: alertas, dica: 'Ver alertas'),
          if (largura >= 640 && u != null) ...[
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onConta,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: c.isLight ? const Color(0xFFF1F5F9) : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.isLight ? c.cardBorder : const Color(0xFF2E2E2E)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(u.lojaNome, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSoft, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
          ],
          const SizedBox(width: 8),
          caixa(LucideIcons.logOut, onSair, dica: 'Sair da conta'),
        ],
      ),
    );
  }
}

// ============================ BARRA INFERIOR (celular) ============================

/// Navegação pensada para quem não é técnico: poucos botões, ícone + nome,
/// área de toque de 64 px e o "Bipar" grande no centro.
class _BarraInferior extends StatelessWidget {
  const _BarraInferior({required this.aba, required this.alertas, required this.onIr, required this.onBipar});
  final NavTab aba;
  final int alertas;
  final void Function(NavTab, {String? codigo}) onIr;
  final VoidCallback onBipar;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget item(NavTab t, IconData i, String rotulo) {
      final ativo = aba == t;
      return Expanded(
        child: Semantics(
          button: true,
          selected: ativo,
          label: rotulo,
          child: InkWell(
            onTap: () => onIr(t),
            child: SizedBox(
              height: 64,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(i, size: 24, color: ativo ? c.gold : c.textMuted),
                const SizedBox(height: 4),
                Text(rotulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: ativo ? FontWeight.w800 : FontWeight.w600, color: ativo ? c.gold : c.textSoft)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: c.sidebar, border: Border(top: BorderSide(color: c.cardBorder))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          item(NavTab.dashboard, LucideIcons.house, 'Início'),
          item(NavTab.pdv, LucideIcons.shoppingCart, 'Vender'),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Bipar código de barras',
              child: GestureDetector(
                onTap: onBipar,
                child: SizedBox(
                  height: 64,
                  child: Center(
                    child: Container(
                      width: 58,
                      height: 50,
                      decoration: BoxDecoration(
                        color: c.botao,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: c.botao.withValues(alpha: 0.35), blurRadius: 12)],
                      ),
                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(LucideIcons.barcode, size: 22, color: Colors.black),
                        Text('Bipar', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
          item(NavTab.estoque, LucideIcons.boxes, 'Estoque'),
          item(NavTab.inteligencia, LucideIcons.sparkles, 'Assistente'),
        ]),
      ),
    );
  }
}
