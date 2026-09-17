import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Import do Firebase gerado pelo CLI
import 'screens/tela_login.dart';
import 'screens/main_layout.dart';
import 'services/app_state.dart';

Future<void> main() async {
  // Garante que os widgets do Flutter estejam prontos
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa o Firebase (Analytics, etc) com as opções corretas
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Inicializa o Supabase com a URL corrigida
  await Supabase.initialize(
    url: 'https://drszfkijbemrzzgxvboy.supabase.co', // <-- CORRIGIDO AQUI!
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRyc3pma2lqYmVtcnp6Z3h2Ym95Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5ODU3NzIsImV4cCI6MjA5NTU2MTc3Mn0.TYgZDdviLlJoPR5ZFlLqHt9ltzeIwv2IWLMGFlqmA3Y',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// 🔒 Chave global do Navigator para poder navegar de qualquer lugar
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    // 🔒 Auth Gateway: escuta mudanças de estado da autenticação em tempo real.
    // Cobre: login, logout, expiração de token, revogação remota.
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      if (event == AuthChangeEvent.signedIn) {
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MainLayout(),
          ),
          (_) => false,
        );
      } else if (event == AuthChangeEvent.signedOut) {
        // Sessão encerrada ou token expirou → volta para Login
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TelaLogin()),
          (_) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🔒 Verifica se já existe sessão ativa na abertura do app
    final session = Supabase.instance.client.auth.currentSession;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppState.themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Sistema de Gestão',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          // TEMA CLARO: Muito limpo, sério, fundo branco/gelo, textos escuros
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade800,
              secondary: Colors.blue.shade600,
              surface: Colors.grey.shade50, // Fundo gelo
              background: Colors.grey.shade100,
              onSurface: Colors.grey.shade900,
            ),
            scaffoldBackgroundColor: Colors.grey.shade100,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            useMaterial3: true,
          ),
          // TEMA ESCURO: Fundo muito escuro, não cansativo, sério
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.dark(
              primary: Colors.blue.shade400,
              secondary: Colors.blue.shade200,
              surface: Colors.grey.shade900,
              background: Colors.black,
              onSurface: Colors.grey.shade100,
            ),
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.grey.shade900,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            useMaterial3: true,
          ),
          // Se logado → MainLayout, senão → Login
          home: session != null ? const MainLayout() : const TelaLogin(),
        );
      },
    );
  }
}