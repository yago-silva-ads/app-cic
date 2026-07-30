import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/leitor_screen.dart';
import '../screens/tela_dashboard.dart';
import '../screens/tela_estoque.dart';
import '../screens/tela_vendedor.dart';
import '../screens/tela_despesas_variaveis.dart';
import '../screens/tela_alertas.dart';
import '../screens/tela_suporte.dart';
import '../screens/tela_tutorial_web.dart';
import '../screens/tela_login.dart';
import '../services/supabase_helper.dart';
import '../web/tela_dashboard_web.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Drawer (Menu Lateral Universal) - Padronizado para 100% das telas
/// Garante que todas as 7 opções vitais do sistema estejam sempre visíveis.
/// ═══════════════════════════════════════════════════════════════════════
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? 'Usuário Logado';

    return Drawer(
      child: Column(
        children: [
          // Header Elegante
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 48, bottom: 20, left: 16, right: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 24,
                      child: Icon(Icons.store, color: Colors.blue.shade800, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'App CIC SaaS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Lista de 7 Opções Universais
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildMenuItem(
                  context: context,
                  icon: Icons.home,
                  title: 'Página Inicial (Leitor)',
                  color: Colors.blue.shade800,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LeitorScreen()),
                    );
                  },
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.pie_chart,
                  title: 'Dashboard Inteligente',
                  color: Colors.indigo.shade700,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const TelaDashboard()),
                    );
                  },
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.language,
                  title: 'Gráficos do Negócio',
                  color: Colors.teal.shade700,
                  onTap: () {
                    Navigator.pop(context);
                    if (kIsWeb) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const TelaDashboardWeb()),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TelaTutorialWeb()),
                      );
                    }
                  },
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.list_alt,
                  title: 'Estoque Atual',
                  color: Colors.blueGrey.shade800,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const TelaEstoque()),
                    );
                  },
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.attach_money,
                  title: 'Custos Operacionais',
                  color: Colors.green.shade700,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const TelaVendedor()),
                    );
                  },
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.receipt_long,
                  title: 'Despesas Variáveis',
                  color: Colors.red.shade600,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const TelaDespesasVariaveis()),
                    );
                  },
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.notifications_active,
                  title: 'Central de Avisos & Alertas',
                  color: Colors.amber.shade800,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const TelaAlertas()),
                    );
                  },
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.support_agent,
                  title: 'Ajuda & Suporte ao Lojista',
                  color: Colors.purple.shade700,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const TelaSuporte()),
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Divider(),
                ),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red.shade700),
                  title: Text(
                    'Sair da Conta',
                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirmar = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sair da conta'),
                        content: const Text('Deseja realmente sair do aplicativo?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('Sair', style: TextStyle(color: Colors.red.shade700)),
                          ),
                        ],
                      ),
                    );
                    if (confirmar == true && context.mounted) {
                      await SupabaseHelper.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const TelaLogin()),
                          (_) => false,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      onTap: onTap,
    );
  }
}
