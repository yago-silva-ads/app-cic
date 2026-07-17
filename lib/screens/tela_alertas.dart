import 'package:flutter/material.dart';
import '../models/alerta.dart';
import '../services/supabase_helper.dart';
import '../widgets/app_drawer.dart';

/// Tela dedicada para visualizar, filtrar e gerenciar alertas do sistema.
/// Exibe alertas de validade, estoque baixo, prejuízo e sugestões da IA.
class TelaAlertas extends StatefulWidget {
  const TelaAlertas({super.key});

  @override
  State<TelaAlertas> createState() => _TelaAlertasState();
}

class _TelaAlertasState extends State<TelaAlertas> {
  List<Alerta> alertas = [];
  bool isLoading = true;
  String? filtroTipo; // null = todos
  bool mostrarLidos = false;

  @override
  void initState() {
    super.initState();
    _carregarAlertas();
  }

  Future<void> _carregarAlertas() async {
    setState(() => isLoading = true);
    final dados = await SupabaseHelper.getAlertas(apenasNaoLidos: !mostrarLidos);
    if (!mounted) return;
    setState(() {
      alertas = dados;
      if (filtroTipo != null) {
        alertas = alertas.where((a) => a.tipo == filtroTipo).toList();
      }
      isLoading = false;
    });
  }

  Future<void> _marcarLido(Alerta alerta) async {
    await SupabaseHelper.marcarAlertaLido(alerta.id);
    _carregarAlertas();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alerta marcado como lido ✅'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _marcarTodosLidos() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar todos como lidos?'),
        content: const Text('Todos os alertas serão arquivados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseHelper.marcarTodosAlertasLidos();
      _carregarAlertas();
    }
  }

  Color _corSeveridade(String severidade) {
    switch (severidade) {
      case 'CRITICO':
        return Colors.red.shade700;
      case 'ALTO':
        return Colors.orange.shade700;
      case 'MEDIO':
        return Colors.amber.shade700;
      case 'BAIXO':
        return Colors.blue.shade600;
      default:
        return Colors.grey;
    }
  }

  IconData _iconeTipo(String tipo) {
    switch (tipo) {
      case 'VALIDADE':
        return Icons.calendar_today;
      case 'ESTOQUE_BAIXO':
        return Icons.inventory_2;
      case 'PREJUIZO':
        return Icons.trending_down;
      case 'IA_SUGESTAO':
        return Icons.auto_awesome;
      default:
        return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertasCriticos = alertas.where((a) => a.severidade == 'CRITICO').length;
    final alertasAltos = alertas.where((a) => a.severidade == 'ALTO').length;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('🔔 Central de Alertas'),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
        actions: [
          if (alertas.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Marcar todos como lidos',
              onPressed: _marcarTodosLidos,
            ),
          IconButton(
            icon: Icon(mostrarLidos ? Icons.visibility_off : Icons.visibility),
            tooltip: mostrarLidos ? 'Ocultar lidos' : 'Mostrar lidos',
            onPressed: () {
              setState(() => mostrarLidos = !mostrarLidos);
              _carregarAlertas();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // === Resumo no topo ===
          if (!isLoading && alertas.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: alertasCriticos > 0
                  ? Colors.red.shade900.withValues(alpha: 0.15)
                  : alertasAltos > 0
                      ? Colors.orange.shade900.withValues(alpha: 0.10)
                      : Colors.blue.shade900.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Icon(
                    alertasCriticos > 0 ? Icons.error : Icons.info,
                    color: alertasCriticos > 0 ? Colors.red : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alertasCriticos > 0
                          ? '🚨 $alertasCriticos alerta(s) CRÍTICO(S) exigem ação imediata!'
                          : '📋 ${alertas.length} alerta(s) pendente(s)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: alertasCriticos > 0 ? Colors.red.shade800 : Colors.blueGrey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // === Filtros por tipo ===
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _buildChipFiltro(null, 'Todos', Icons.list),
                _buildChipFiltro('VALIDADE', 'Validade', Icons.calendar_today),
                _buildChipFiltro('ESTOQUE_BAIXO', 'Estoque', Icons.inventory_2),
                _buildChipFiltro('PREJUIZO', 'Prejuízo', Icons.trending_down),
                _buildChipFiltro('IA_SUGESTAO', 'IA', Icons.auto_awesome),
              ],
            ),
          ),

          const Divider(height: 1),

          // === Lista de alertas ===
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : alertas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'Tudo certo! Nenhum alerta pendente. ✅',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _carregarAlertas,
                        child: ListView.builder(
                          itemCount: alertas.length,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemBuilder: (ctx, i) {
                            final a = alertas[i];
                            return Dismissible(
                              key: Key('alerta_${a.id}'),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => _marcarLido(a),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: Colors.green.shade600,
                                child: const Icon(Icons.done, color: Colors.white, size: 28),
                              ),
                              child: Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                elevation: a.isUrgente ? 4 : 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: _corSeveridade(a.severidade).withValues(alpha: 0.5),
                                    width: a.isUrgente ? 2 : 0.5,
                                  ),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _corSeveridade(a.severidade).withValues(alpha: 0.15),
                                    child: Icon(
                                      _iconeTipo(a.tipo),
                                      color: _corSeveridade(a.severidade),
                                      size: 22,
                                    ),
                                  ),
                                  title: Text(
                                    a.mensagem,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: a.isUrgente ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _corSeveridade(a.severidade).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            a.severidade,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _corSeveridade(a.severidade),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          a.tipoLabel,
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatarData(a.criadoEm),
                                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.check_circle_outline, color: Colors.green.shade400),
                                    tooltip: 'Marcar como lido',
                                    onPressed: () => _marcarLido(a),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipFiltro(String? tipo, String label, IconData icon) {
    final isSelected = filtroTipo == tipo;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.blueGrey),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: isSelected,
        selectedColor: Colors.blueGrey.shade700,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.blueGrey.shade800,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (_) {
          setState(() => filtroTipo = tipo);
          _carregarAlertas();
        },
      ),
    );
  }

  String _formatarData(DateTime dt) {
    final agora = DateTime.now();
    final diff = agora.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    if (diff.inDays < 7) return '${diff.inDays}d atrás';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
}
