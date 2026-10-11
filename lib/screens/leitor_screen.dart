import 'package:flutter/material.dart';
import '../state/app_state.dart';

class LeitorScreen extends StatelessWidget {
  const LeitorScreen({super.key, required this.estado, this.codigoInicial, required this.onAbrirScanner, required this.onSalvo});
  final AppState estado;
  final String? codigoInicial;
  final Future<void> Function([ValueChanged<String>? aoLer]) onAbrirScanner;
  final VoidCallback onSalvo;
  @override
  Widget build(BuildContext context) => const Center(child: Text('Leitor'));
}
