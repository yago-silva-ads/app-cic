import 'package:flutter/material.dart';
import '../state/app_state.dart';

class XmlScreen extends StatelessWidget {
  const XmlScreen({super.key, required this.estado, required this.onConcluido});
  final AppState estado;
  final VoidCallback onConcluido;
  @override
  Widget build(BuildContext context) => const Center(child: Text('XML'));
}
