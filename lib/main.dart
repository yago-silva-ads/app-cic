import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Import do Firebase gerado pelo CLI
import 'screens/tela_login.dart';
import 'screens/tela_dashboard.dart';

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

      if (event == AuthChangeEvent.signedOut) {
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

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Leitor GS1 - CIC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Se logado → Dashboard, senão → Login
      home: session != null ? const TelaDashboard() : const TelaLogin(),
    );
  }
}