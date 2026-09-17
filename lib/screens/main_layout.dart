import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'leitor_screen.dart';
import 'tela_dashboard.dart';
import 'tela_estoque.dart';
import 'tela_vendedor.dart';
import 'tela_alertas.dart';
import 'tela_suporte.dart';
import 'tela_tutorial_web.dart';
import 'tela_login.dart';
import '../services/supabase_helper.dart';
import 'tela_unica_dashboard.dart';
import 'tela_chat_ia.dart';
import '../services/app_state.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Fecha o Drawer (navbar) no mobile
    if (!kIsWeb && Scaffold.of(context).isDrawerOpen) {
      Navigator.pop(context);
    } else if (kIsWeb && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _fazerLogout() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Deseja realmente sair?'),
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
    if (confirmar == true && mounted) {
      await SupabaseHelper.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const TelaLogin()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> telas = [
      TelaUnicaDashboard(
        onNavigate: _onItemTapped,
      ), // 0
      const LeitorScreen(isEmbedded: true), // 1
      const TelaEstoque(isEmbedded: true), // 2
      const TelaChatIA(diagnosticoInicial: 'Olá!', isEmbedded: true), // 3
      const TelaVendedor(isEmbedded: true), // 4
    ];

    return Scaffold(
      key: AppState.mainScaffoldKey,
      appBar: AppBar(
        title: const Text('Sistema de Gestão', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Alternar Tema',
            onPressed: AppState.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Configurações',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.support_agent, color: Colors.blue),
                          title: const Text('Ajuda & Suporte'),
                          subtitle: const Text('Falar com suporte do sistema'),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TelaSuporte()),
                            );
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: Icon(Icons.logout, color: Colors.red.shade700),
                          title: Text('Sair da Conta', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                          onTap: () {
                            Navigator.pop(ctx);
                            _fazerLogout();
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
              accountName: const Text("Meu Negócio"),
              accountEmail: const Text("Painel de Controle"),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.store, size: 40, color: Colors.blue),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Início'),
              selected: _selectedIndex == 0,
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Leitor'),
              selected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Estoque'),
              selected: _selectedIndex == 2,
              onTap: () => _onItemTapped(2),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Análise IA'),
              selected: _selectedIndex == 3,
              onTap: () => _onItemTapped(3),
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Custos Operacionais'),
              selected: _selectedIndex == 4,
              onTap: () => _onItemTapped(4),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red.shade700),
              title: Text('Sair', style: TextStyle(color: Colors.red.shade700)),
              onTap: _fazerLogout,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: telas,
      ),
    );
  }
}
