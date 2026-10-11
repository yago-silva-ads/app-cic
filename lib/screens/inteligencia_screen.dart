import 'package:flutter/material.dart';
import '../state/app_state.dart';

class InteligenciaScreen extends StatelessWidget {
  const InteligenciaScreen({super.key, required this.estado});
  final AppState estado;
  @override
  Widget build(BuildContext context) => const Center(child: Text('InteligenciaScreen'));
}
