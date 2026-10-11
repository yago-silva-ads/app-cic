import 'package:flutter/material.dart';
import '../app/shell.dart';
import '../state/app_state.dart';

class AlertasScreen extends StatelessWidget {
  const AlertasScreen({super.key, required this.estado, required this.onNavegar});
  final AppState estado;
  final void Function(NavTab, {String? codigo}) onNavegar;
  @override
  Widget build(BuildContext context) => const Center(child: Text('Alertas'));
}
