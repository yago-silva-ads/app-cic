import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Import do Firebase gerado pelo CLI
import 'screens/leitor_screen.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leitor GS1 - CIC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LeitorScreen(), // Chama a tela separada
    );
  }
}