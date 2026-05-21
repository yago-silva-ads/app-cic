import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/leitor_screen.dart'; // Importa a tela principal

Future<void> main() async {
  // Garante que os widgets do Flutter estejam prontos
  WidgetsFlutterBinding.ensureInitialized(); 
  // Carrega a chave de API antes do App iniciar
  await dotenv.load(fileName: ".env"); 

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
        useMaterial3: true
      ),
      home: const LeitorScreen(), // Chama a tela separada
    );
  }
}


// Forçando atualização das pastas