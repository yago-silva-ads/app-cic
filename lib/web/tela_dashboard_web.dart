import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/produto.dart';
import '../models/alerta.dart';
import '../models/custo_operacional.dart';
import '../services/supabase_helper.dart';
import '../screens/tela_alertas.dart';
import '../screens/tela_login.dart';
import '../screens/leitor_screen.dart';
import '../screens/tela_vendedor.dart';
import '../screens/tela_suporte.dart';
import 'tela_inteligencia_web.dart';

/// ═══════════════════════════════════════════════════════════════
/// SaaS Dashboard Web — Painel Gerencial Premium
/// ═══════════════════════════════════════════════════════════════
/// Design dark mode inspirado no dashboard Porsche Sales Intelligence.
/// Paleta: fundo #0D0D0D, cards #1A1A1A, accent gold #D4A843.
/// Reutiliza 100% do Supabase + RLS do app mobile.
/// ═══════════════════════════════════════════════════════════════

// Paleta de cores premium
const Color _bgDark = Color(0xFF0D0D0D);
const Color _cardDark = Color(0xFF1A1A1A);
const Color _cardBorder = Color(0xFF2A2A2A);
const Color _accentGold = Color(0xFFD4A843);
const Color _accentTeal = Color(0xFF00B8AA);
const Color _textPrimary = Color(0xFFF5F5F5);
const Color _textSecondary = Color(0xFF9E9E9E);
const Color _redAlert = Color(0xFFFF1744);
const Color _greenPositive = Color(0xFF00E676);

class TelaDashboardWeb extends StatefulWidget {
  const TelaDashboardWeb({super.key});

  @override
  State<TelaDashboardWeb> createState() => _TelaDashboardWebState();
}

class _TelaDashboardWebState extends State<TelaDashboardWeb> {
  // Dados
  List<Produto> estoque = [];
  List<Map<String, dynamic>> historicoVendas = [];
  List<CustoOperacional> custos = [];
  List<Alerta> alertas = [];
  Map<String, dynamic> kpis = {};
  List<Map<String, dynamic>> faturamentoMensal = [];
  List<Map<String, dynamic>> topProdutos = [];

  bool isLoading = true;
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _carregarTodosDados();
  }

  Future<void> _carregarTodosDados() async {
    setState(() => isLoading = true);

    final futures = await Future.wait([
      SupabaseHelper.getEstoque(),
      SupabaseHelper.getHistoricoVendas(),
      SupabaseHelper.getCustosOperacionais(),
      SupabaseHelper.getAlertas(),
      SupabaseHelper.getKpisVendasMes(),
      SupabaseHelper.getFaturamentoMensal(),
      SupabaseHelper.getTopProdutosMes(),
    ]);

    if (!mounted) return;

    setState(() {
      estoque = futures[0] as List<Produto>;
      historicoVendas = futures[1] as List<Map<String, dynamic>>;
      custos = futures[2] as List<CustoOperacional>;
      alertas = futures[3] as List<Alerta>;
      kpis = futures[4] as Map<String, dynamic>;
      faturamentoMensal = futures[5] as List<Map<String, dynamic>>;
      topProdutos = futures[6] as List<Map<String, dynamic>>;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _bgDark,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 800;
          return Scaffold(
            drawer: isMobile
                ? Drawer(
                    backgroundColor: _cardDark,
                    child: _buildSidebar(isMobileDrawer: true),
                  )
                : null,
            body: Row(
              children: [
                // === SIDEBAR APENAS SE NÃO FOR MOBILE ===
                if (!isMobile) _buildSidebar(isMobileDrawer: false),

                // === CONTEÚDO PRINCIPAL ===
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(isMobile: isMobile),
                      Expanded(
                        child: isLoading
                            ? const Center(
                                child: CircularProgressIndicator(color: _accentGold))
                            : _buildConteudoPagina(isMobile: isMobile, constraints: constraints),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: isMobile
                ? BottomNavigationBar(
                    backgroundColor: _cardDark,
                    selectedItemColor: _accentGold,
                    unselectedItemColor: _textSecondary,
                    currentIndex: _selectedNavIndex,
                    type: BottomNavigationBarType.fixed,
                    onTap: (index) {
                      setState(() => _selectedNavIndex = index);
                    },
                    items: [
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.dashboard),
                        label: 'Visão Geral',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.auto_awesome),
                        label: 'IA & ABC',
                      ),
                      BottomNavigationBarItem(
                        icon: Badge(
                          isLabelVisible: alertas.any((a) => !a.lido),
                          label: Text('${alertas.where((a) => !a.lido).length}'),
                          child: const Icon(Icons.notifications_active),
                        ),
                        label: 'Alertas',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.inventory_2),
                        label: 'Produtos',
                      ),
                    ],
                  )
                : null,
          );
        },
      ),
    );
  }

  // ==================== SIDEBAR ====================
  Widget _buildSidebar({bool isMobileDrawer = false}) {
    return Container(
      width: 220,
      color: _cardDark,
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_accentGold, Color(0xFFE8C568)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.analytics, color: _bgDark, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'APP-CIC',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: _cardBorder, height: 1),
          const SizedBox(height: 8),

          // Navegação das 4 abas internas
          _buildNavItem(0, Icons.dashboard, 'Visão Geral', isMobileDrawer: isMobileDrawer),
          _buildNavItem(1, Icons.auto_awesome, 'Inteligência IA', isMobileDrawer: isMobileDrawer),
          _buildNavItem(2, Icons.notifications_active, 'Alertas',
              badge: alertas.where((a) => !a.lido).length, isMobileDrawer: isMobileDrawer),
          _buildNavItem(3, Icons.inventory_2, 'Estoque Atual', isMobileDrawer: isMobileDrawer),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(color: _cardBorder, height: 1),
          ),

          // Outras 3 abas globais (completando as 7 opções)
          _buildExternalNavItem(Icons.home, 'Página Inicial (Leitor)', () {
            if (isMobileDrawer && Navigator.canPop(context)) Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LeitorScreen()));
          }),
          _buildExternalNavItem(Icons.attach_money, 'Custos Operacionais', () {
            if (isMobileDrawer && Navigator.canPop(context)) Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaVendedor()));
          }),
          _buildExternalNavItem(Icons.support_agent, 'Ajuda & Suporte', () {
            if (isMobileDrawer && Navigator.canPop(context)) Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaSuporte()));
          }),
          _buildExternalNavItem(Icons.android, 'Baixar App Android (APK)', () {
            if (isMobileDrawer && Navigator.canPop(context)) Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaSuporte()));
          }),

          const Spacer(),

          // Logout
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.logout, color: _textSecondary, size: 18),
                label: Text('Sair', style: TextStyle(color: _textSecondary)),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: () async {
                  if (isMobileDrawer && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  await SupabaseHelper.signOut();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const TelaLogin()),
                    (_) => false,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {int badge = 0, bool isMobileDrawer = false}) {
    final isSelected = _selectedNavIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected ? _accentGold.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (isMobileDrawer && Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            setState(() => _selectedNavIndex = index);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20,
                    color: isSelected ? _accentGold : _textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? _textPrimary : _textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _redAlert,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExternalNavItem(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: _textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: _textSecondary, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== TOP BAR ====================
  Widget _buildTopBar({bool isMobile = false}) {
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
      decoration: const BoxDecoration(
        color: _cardDark,
        border: Border(bottom: BorderSide(color: _cardBorder)),
      ),
      child: Row(
        children: [
          if (isMobile) ...[
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: _textPrimary),
                tooltip: 'Abrir Menu Lateral',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              _getTituloPagina(),
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 16 : 20,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh, color: _textSecondary),
            tooltip: 'Atualizar dados',
            onPressed: _carregarTodosDados,
          ),
          const SizedBox(width: 4),
          // Contagem de produtos
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: 6),
            decoration: BoxDecoration(
              color: _accentGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accentGold.withValues(alpha: 0.3)),
            ),
            child: Text(
              isMobile ? '${estoque.length} prod.' : '● ${estoque.length} produtos',
              style: TextStyle(color: _accentGold, fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _getTituloPagina() {
    switch (_selectedNavIndex) {
      case 0: return '📊 Visão Geral';
      case 1: return '🤖 Inteligência Artificial';
      case 2: return '🔔 Central de Alertas';
      case 3: return '📦 Produtos';
      default: return 'Dashboard';
    }
  }

  // ==================== CONTEÚDO DA PÁGINA ====================
  Widget _buildConteudoPagina({bool isMobile = false, required BoxConstraints constraints}) {
    switch (_selectedNavIndex) {
      case 0:
        return _buildDashboardVisaoGeral(isMobile: isMobile, constraints: constraints);
      case 1:
        return TelaInteligenciaWeb(
          estoque: estoque,
          historicoVendas: historicoVendas,
          custos: custos,
          alertas: alertas,
        );
      case 2:
        return const TelaAlertas();
      case 3:
        return _buildProdutosGrid(isMobile: isMobile);
      default:
        return _buildDashboardVisaoGeral(isMobile: isMobile, constraints: constraints);
    }
  }

  // ==================== DASHBOARD: VISÃO GERAL ====================
  Widget _buildDashboardVisaoGeral({bool isMobile = false, required BoxConstraints constraints}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === ROW 1: KPI Cards ===
          _buildKpiRow(isMobile: isMobile, constraints: constraints),
          const SizedBox(height: 24),

          // === ROW 2: Gráfico de Faturamento + Top Produtos ===
          if (constraints.maxWidth > 900)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildGraficoFaturamento(isMobile: isMobile, constraints: constraints)),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildTopProdutosCard()),
              ],
            )
          else
            Column(
              children: [
                _buildGraficoFaturamento(isMobile: isMobile, constraints: constraints),
                const SizedBox(height: 20),
                _buildTopProdutosCard(),
              ],
            ),
          const SizedBox(height: 24),

          // === ROW 3: Alertas resumo + Custos operacionais ===
          if (constraints.maxWidth > 900)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildAlertasResumo()),
                const SizedBox(width: 20),
                Expanded(child: _buildCustosCard()),
              ],
            )
          else
            Column(
              children: [
                _buildAlertasResumo(),
                const SizedBox(height: 20),
                _buildCustosCard(),
              ],
            ),
        ],
      ),
    );
  }

  // ==================== KPI CARDS ====================
  Widget _buildKpiRow({bool isMobile = false, required BoxConstraints constraints}) {
    final totalVendas = (kpis['total_vendas'] ?? 0);
    final receitaTotal = (kpis['receita_total'] as num?)?.toDouble() ?? 0.0;
    final ticketMedio = (kpis['ticket_medio'] as num?)?.toDouble() ?? 0.0;
    final lucroBruto = (kpis['lucro_bruto'] as num?)?.toDouble() ?? 0.0;
    final alertasAtivos = alertas.where((a) => !a.lido).length;

    final cardWidth = isMobile ? constraints.maxWidth : 220.0;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildKpiCard(
          'TOTAL DE VENDAS',
          '$totalVendas',
          'vendas no período',
          Icons.shopping_cart,
          _accentTeal,
          cardWidth,
        ),
        _buildKpiCard(
          'RECEITA TOTAL',
          'R\$ ${_formatarMoeda(receitaTotal)}',
          'em vendas com preço válido',
          Icons.attach_money,
          _accentGold,
          cardWidth,
        ),
        _buildKpiCard(
          'TICKET MÉDIO',
          'R\$ ${_formatarMoeda(ticketMedio)}',
          'por transação válida',
          Icons.receipt_long,
          const Color(0xFF7C4DFF),
          cardWidth,
        ),
        _buildKpiCard(
          'LUCRO BRUTO',
          'R\$ ${_formatarMoeda(lucroBruto)}',
          lucroBruto >= 0 ? 'margem positiva' : 'PREJUÍZO',
          Icons.trending_up,
          lucroBruto >= 0 ? _greenPositive : _redAlert,
          cardWidth,
        ),
        _buildKpiCard(
          'ALERTAS ATIVOS',
          '$alertasAtivos',
          'pendentes de ação',
          Icons.notifications_active,
          alertasAtivos > 0 ? _redAlert : _greenPositive,
          cardWidth,
        ),
      ],
    );
  }

  Widget _buildKpiCard(String titulo, String valor, String subtitulo,
      IconData icone, Color cor, double cardWidth) {
    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: cor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(titulo,
                  style: const TextStyle(
                    color: _textSecondary, fontSize: 10,
                    fontWeight: FontWeight.w600, letterSpacing: 1,
                  )),
              const Spacer(),
              Icon(icone, color: cor.withValues(alpha: 0.6), size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(valor,
              style: GoogleFonts.outfit(
                color: _textPrimary, fontSize: 24, fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 4),
          Container(
            height: 3, width: 40,
            decoration: BoxDecoration(
              color: cor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitulo,
              style: const TextStyle(color: _textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  // ==================== GRÁFICO FATURAMENTO MENSAL ====================
  Widget _buildGraficoFaturamento({bool isMobile = false, required BoxConstraints constraints}) {
    final int qtdSpots = faturamentoMensal.length;
    final double minChartWidth = isMobile ? math.max(constraints.maxWidth - 48, qtdSpots * 65.0) : double.infinity;

    return Container(
      height: 380,
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FATURAMENTO MENSAL',
              style: GoogleFonts.outfit(
                color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600,
                letterSpacing: 1,
              )),
          const SizedBox(height: 4),
          const Text('Últimos 12 meses — Receita vs Lucro (Arraste para o lado no celular)',
              style: TextStyle(color: _textSecondary, fontSize: 11)),
          const SizedBox(height: 20),
          Expanded(
            child: faturamentoMensal.isEmpty
                ? Center(
                    child: Text('Sem dados de faturamento ainda.',
                        style: TextStyle(color: _textSecondary)),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: minChartWidth,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: _calcInterval(),
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: _cardBorder,
                              strokeWidth: 0.5,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 55,
                                getTitlesWidget: (value, meta) => Text(
                                  _formatarAbreviado(value),
                                  style: const TextStyle(color: _textSecondary, fontSize: 10),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx >= 0 && idx < faturamentoMensal.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        faturamentoMensal[idx]['mes_label'] ?? '',
                                        style: const TextStyle(color: _textSecondary, fontSize: 9),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            // Linha de Faturamento
                            LineChartBarData(
                              spots: faturamentoMensal.asMap().entries.map((e) {
                                return FlSpot(e.key.toDouble(),
                                    (e.value['faturamento'] as num?)?.toDouble() ?? 0);
                              }).toList(),
                              isCurved: true,
                              color: _accentGold,
                              barWidth: 3,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: _accentGold.withValues(alpha: 0.08),
                              ),
                            ),
                            // Linha de Lucro
                            LineChartBarData(
                              spots: faturamentoMensal.asMap().entries.map((e) {
                                return FlSpot(e.key.toDouble(),
                                    (e.value['lucro'] as num?)?.toDouble() ?? 0);
                              }).toList(),
                              isCurved: true,
                              color: _accentTeal,
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
                              dashArray: [5, 3],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendaDot(_accentGold, 'Faturamento'),
              const SizedBox(width: 20),
              _buildLegendaDot(_accentTeal, 'Lucro'),
            ],
          ),
        ],
      ),
    );
  }

  double _calcInterval() {
    if (faturamentoMensal.isEmpty) return 1000;
    final maxVal = faturamentoMensal.fold<double>(0, (prev, e) {
      final fat = (e['faturamento'] as num?)?.toDouble() ?? 0;
      return fat > prev ? fat : prev;
    });
    if (maxVal <= 0) return 1000;
    return (maxVal / 4).ceilToDouble();
  }

  Widget _buildLegendaDot(Color cor, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 11)),
      ],
    );
  }

  // ==================== TOP PRODUTOS (RANKING ESTILO PORSCHE) ====================
  Widget _buildTopProdutosCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RANKING — TOP PRODUTOS',
              style: GoogleFonts.outfit(
                color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600,
                letterSpacing: 1,
              )),
          const SizedBox(height: 4),
          const Text('Produtos com maior receita no mês',
              style: TextStyle(color: _textSecondary, fontSize: 11)),
          const SizedBox(height: 16),
          if (topProdutos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Sem vendas registradas ainda.',
                  style: TextStyle(color: _textSecondary)),
            )
          else
            ...topProdutos.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              final nome = p['produto_nome'] ?? p['produto_codigo'] ?? '—';
              final receita = (p['receita_produto'] as num?)?.toDouble() ?? 0;
              final maxReceita = topProdutos.isNotEmpty
                  ? (topProdutos[0]['receita_produto'] as num?)?.toDouble() ?? 1
                  : 1.0;
              final proporcao = maxReceita > 0 ? receita / maxReceita : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${i + 1}.',
                        style: TextStyle(
                          color: i < 3 ? _accentGold : _textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(nome,
                          style: const TextStyle(color: _textPrimary, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      flex: 4,
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: _cardBorder,
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: proporcao.clamp(0.05, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: _accentGold.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      child: Text(
                        'R\$ ${_formatarAbreviado(receita)}',
                        style: const TextStyle(color: _accentGold, fontSize: 11, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ==================== ALERTAS RESUMO ====================
  Widget _buildAlertasResumo() {
    final urgentes = alertas.where((a) => a.isUrgente && !a.lido).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: urgentes.isNotEmpty ? _redAlert.withValues(alpha: 0.3) : _cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ALERTAS ATIVOS',
                  style: GoogleFonts.outfit(
                    color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  )),
              const Spacer(),
              if (urgentes.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _redAlert.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${urgentes.length} urgente(s)',
                      style: const TextStyle(color: _redAlert, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (alertas.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: _greenPositive, size: 20),
                  const SizedBox(width: 8),
                  Text('Tudo certo! Nenhum alerta pendente.',
                      style: TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              ),
            )
          else
            ...alertas.take(5).map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: a.severidade == 'CRITICO'
                              ? _redAlert
                              : a.severidade == 'ALTO'
                                  ? Colors.orange
                                  : Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(a.mensagem,
                            style: const TextStyle(color: _textPrimary, fontSize: 11),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                )),
          if (alertas.length > 5)
            TextButton(
              onPressed: () => setState(() => _selectedNavIndex = 2),
              child: Text('Ver todos os ${alertas.length} alertas →',
                  style: const TextStyle(color: _accentGold, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  // ==================== CUSTOS OPERACIONAIS ====================
  Widget _buildCustosCard() {
    double totalCustos = custos.fold(0, (sum, c) => sum + c.valor);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CUSTOS OPERACIONAIS',
              style: GoogleFonts.outfit(
                color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600,
                letterSpacing: 1,
              )),
          const SizedBox(height: 4),
          Text('Total mensal: R\$ ${_formatarMoeda(totalCustos)}',
              style: TextStyle(color: _accentGold, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (custos.isEmpty)
            Text('Nenhum custo operacional cadastrado.',
                style: TextStyle(color: _textSecondary, fontSize: 12))
          else
            ...custos.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(c.nome,
                            style: const TextStyle(color: _textPrimary, fontSize: 12)),
                      ),
                      Text('R\$ ${_formatarMoeda(c.valor)}',
                          style: const TextStyle(color: _textSecondary, fontSize: 12)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // ==================== GRID DE PRODUTOS ====================
  Widget _buildProdutosGrid({bool isMobile = false}) {
    if (estoque.isEmpty) {
      return Center(
        child: Text('Nenhum produto cadastrado.',
            style: TextStyle(color: _textSecondary, fontSize: 16)),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${estoque.length} produto(s) no estoque',
              style: TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: estoque.map((p) {
              final lucro = p.valorVenda - p.valorCompra;
              final isEstoqueBaixo = p.quantidade <= 5;
              final isVencido = p.dataValidade != null &&
                  p.dataValidade!.isBefore(DateTime.now());
              final isVenceSemana = p.dataValidade != null &&
                  p.dataValidade!.difference(DateTime.now()).inDays <= 7 &&
                  !isVencido;

              return Container(
                width: isMobile ? double.infinity : 260,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isVencido
                        ? _redAlert.withValues(alpha: 0.5)
                        : isEstoqueBaixo
                            ? Colors.orange.withValues(alpha: 0.4)
                            : _cardBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(p.nome,
                              style: GoogleFonts.inter(
                                color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (isVencido)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _redAlert.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('VENCIDO', style: TextStyle(color: _redAlert, fontSize: 8, fontWeight: FontWeight.bold)),
                          )
                        else if (isVenceSemana)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('VENCE BREVE', style: TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Código: ${p.codigo}  |  Lote: ${p.lote}',
                        style: const TextStyle(color: _textSecondary, fontSize: 10)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildMiniKpi('Estoque', '${p.quantidade}',
                            isEstoqueBaixo ? _redAlert : _textPrimary),
                        _buildMiniKpi('Custo', 'R\$${p.valorCompra.toStringAsFixed(2)}', _textSecondary),
                        _buildMiniKpi('Venda', 'R\$${p.valorVenda.toStringAsFixed(2)}', _accentGold),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('Lucro/un: ',
                            style: TextStyle(color: _textSecondary, fontSize: 10)),
                        Text('R\$ ${lucro.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: lucro >= 0 ? _greenPositive : _redAlert,
                              fontSize: 11, fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniKpi(String label, String valor, Color cor) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: _textSecondary, fontSize: 9)),
          Text(valor, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ==================== UTILITÁRIOS ====================
  String _formatarMoeda(double valor) {
    if (valor >= 1000000) return '${(valor / 1000000).toStringAsFixed(2)}M';
    if (valor >= 1000) return '${(valor / 1000).toStringAsFixed(1)}K';
    return valor.toStringAsFixed(2);
  }

  String _formatarAbreviado(double valor) {
    if (valor >= 1000000) return '${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor >= 1000) return '${(valor / 1000).toStringAsFixed(0)}K';
    return valor.toStringAsFixed(0);
  }
}
