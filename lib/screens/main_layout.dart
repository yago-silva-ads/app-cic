import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../services/app_state.dart';
import '../services/supabase_helper.dart';
import 'auth/login_screen.dart';
import 'dashboard_screen.dart';
import 'estoque_screen.dart';
import 'leitor_screen.dart';
import 'inteligencia_screen.dart';
import 'custos_screen.dart';
import 'alertas_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// MainLayout — Navegação principal com BottomNavigationBar (5 abas)
///
/// Substitui o Drawer lateral por uma barra inferior moderna com 5 itens:
/// Dashboard, Estoque, Leitor (central), IA, Mais.
/// ═══════════════════════════════════════════════════════════════════════
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAlertBadge();
  }

  Future<void> _loadAlertBadge() async {
    try {
      final count = await SupabaseHelper.contarAlertasNaoLidos();
      AppState.updateAlertBadge(count);
    } catch (_) {}
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _fazerLogout() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da Conta'),
        content: const Text('Deseja realmente desconectar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sair', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      await SupabaseHelper.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = AppColors.goldForBrightness(Theme.of(context).brightness);

    final List<Widget> telas = [
      DashboardScreen(onNavigate: _onItemTapped),  // 0
      const EstoqueScreen(),                         // 1
      const LeitorScreen(isEmbedded: true),          // 2
      const InteligenciaScreen(),                    // 3
      _buildMaisScreen(),                            // 4
    ];

    return Scaffold(
      key: AppState.mainScaffoldKey,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.qr_code_scanner_rounded, size: 18, color: gold),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'APP-CIC',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Badge de alertas
          ValueListenableBuilder<int>(
            valueListenable: AppState.alertBadgeNotifier,
            builder: (_, count, __) {
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count', style: const TextStyle(fontSize: 10)),
                  backgroundColor: AppColors.error,
                  child: Icon(
                    Icons.notifications_outlined,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                tooltip: 'Alertas',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AlertasScreen()),
                  ).then((_) => _loadAlertBadge());
                },
              );
            },
          ),
          // Toggle tema
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: gold,
            ),
            tooltip: isDark ? 'Modo Claro' : 'Modo Escuro',
            onPressed: AppState.toggleTheme,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: telas,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Estoque',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Leitor',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'IA',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_rounded),
            selectedIcon: Icon(Icons.menu),
            label: 'Mais',
          ),
        ],
      ),
    );
  }

  /// Tela "Mais" com links para Custos, Alertas, Suporte, Logout
  Widget _buildMaisScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = AppColors.goldForBrightness(Theme.of(context).brightness);
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header do usuário
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: gold.withValues(alpha: 0.15),
                child: Icon(Icons.store_rounded, color: gold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Supabase.instance.client.auth.currentUser?.email ?? 'Minha Loja',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Plano Ativo • v2.0.0',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Menu items
        _buildMenuTile(
          icon: Icons.attach_money_rounded,
          color: AppColors.success,
          title: 'Custos & Despesas',
          subtitle: 'Gerencie custos fixos e variáveis',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustosScreen()),
          ),
        ),
        const SizedBox(height: 8),
        _buildMenuTile(
          icon: Icons.swap_vert_rounded,
          color: AppColors.info,
          title: 'Movimentações',
          subtitle: 'Histórico de entradas e saídas',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MovimentacoesScreen()),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<int>(
          valueListenable: AppState.alertBadgeNotifier,
          builder: (_, count, __) {
            return _buildMenuTile(
              icon: Icons.notifications_outlined,
              color: AppColors.warning,
              title: 'Central de Alertas',
              subtitle: count > 0 ? '$count alertas não lidos' : 'Nenhum alerta pendente',
              badge: count > 0 ? '$count' : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AlertasScreen()),
              ).then((_) => _loadAlertBadge()),
            );
          },
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),

        _buildMenuTile(
          icon: Icons.logout_rounded,
          color: AppColors.error,
          title: 'Sair da Conta',
          subtitle: 'Desconectar deste dispositivo',
          onTap: _fazerLogout,
        ),
      ],
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: textSecondary)),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(badge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Placeholder para MovimentacoesScreen (será expandido na Fase 5)
class MovimentacoesScreen extends StatelessWidget {
  const MovimentacoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Movimentações')),
      body: Center(
        child: Text(
          'Histórico de Entradas e Saídas\n(Em construção)',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }
}
