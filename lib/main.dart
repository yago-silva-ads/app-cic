import 'package:flutter/material.dart';
import 'screens/leitor_screen.dart'; // Importa a tela principal

void main() {
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