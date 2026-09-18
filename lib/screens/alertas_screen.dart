import 'package:flutter/material.dart';
import '../models/alerta.dart';
import '../services/supabase_helper.dart';
import '../theme/app_colors.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// AlertasScreen — Central de Alertas v2.0
///
/// Interface redesenhada para visualização de alertas e sugestões de IA.
/// ═══════════════════════════════════════════════════════════════════════
class AlertasScreen extends StatefulWidget {
  const AlertasScreen({super.key});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  List<Alerta> _alertas = [];
  bool _isLoading = true;
  String? _filtroTipo;
  bool _mostrarLidos = false;

  @override
  void initState() {
    super.initState();
    _carregarAlertas();
  }

  Future<void> _carregarAlertas() async {
    setState(() => _isLoading = true);
    try {
      final dados = await SupabaseHelper.getAlertas(apenasNaoLidos: !_mostrarLidos);
      if (!mounted) return;
      setState(() {
        _alertas = dados;
        if (_filtroTipo != null) {
          _alertas = _alertas.where((a) => a.tipo == _filtroTipo).toList();
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _marcarLido(Alerta alerta) async {
    await SupabaseHelper.marcarAlertaLido(alerta.id);
    _carregarAlertas();
  }

  Future<void> _marcarTodosLidos() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = AppColors.goldForBrightness(Theme.of(context).brightness);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        title: Text('Marcar todos como lidos?', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        content: Text('Todos os alertas pendentes serão arquivados.', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: AppColors.darkBackground),
            child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseHelper.marcarTodosAlertasLidos();
      _carregarAlertas();
    }
  }

  Color _corSeveridade(String severidade, bool isDark) {
    switch (severidade) {
      case 'CRITICO': return AppColors.error;
      case 'ALTO': return Colors.orange;
      case 'MEDIO': return isDark ? Colors.amber.shade400 : Colors.amber.shade700;
      case 'BAIXO': return AppColors.info;
      default: return isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    }
  }

  IconData _iconeTipo(String tipo) {
    switch (tipo) {
      case 'VALIDADE': return Icons.calendar_today_rounded;
      case 'ESTOQUE_BAIXO': return Icons.inventory_2_outlined;
      case 'PREJUIZO': return Icons.trending_down_rounded;
      case 'IA_SUGESTAO': return Icons.auto_awesome_rounded;
      default: return Icons.warning_amber_rounded;
    }
  }

  String _formatarData(DateTime dt) {
    final agora = DateTime.now();
    final diff = agora.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    if (diff.inDays < 7) return '${diff.inDays}d atrás';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = AppColors.goldForBrightness(Theme.of(context).brightness);
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final criticos = _alertas.where((a) => a.severidade == 'CRITICO').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de Alertas'),
        actions: [
          if (_alertas.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Marcar todos como lidos',
              onPressed: _marcarTodosLidos,
            ),
          IconButton(
            icon: Icon(_mostrarLidos ? Icons.visibility_off : Icons.visibility),
            tooltip: _mostrarLidos ? 'Ocultar lidos' : 'Mostrar lidos',
            onPressed: () {
              setState(() => _mostrarLidos = !_mostrarLidos);
              _carregarAlertas();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isLoading && criticos > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.error.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$criticos alerta(s) CRÍTICO(S) exigem ação imediata!',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterPill(null, 'Todos', Icons.list),
                _buildFilterPill('VALIDADE', 'Validade', Icons.calendar_today_rounded),
                _buildFilterPill('ESTOQUE_BAIXO', 'Estoque', Icons.inventory_2_outlined),
                _buildFilterPill('PREJUIZO', 'Prejuízo', Icons.trending_down_rounded),
                _buildFilterPill('IA_SUGESTAO', 'IA Sugestão', Icons.auto_awesome_rounded),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _alertas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 64, color: AppColors.success.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text(
                              'Tudo limpo! Nenhum alerta.',
                              style: TextStyle(color: textSecondary, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: gold,
                        onRefresh: _carregarAlertas,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _alertas.length,
                          itemBuilder: (context, index) {
                            final a = _alertas[index];
                            final color = _corSeveridade(a.severidade, isDark);

                            return Dismissible(
                              key: Key('alerta_${a.id}'),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => _marcarLido(a),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 30),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: a.isUrgente ? color.withValues(alpha: 0.5) : borderCol,
                                    width: a.isUrgente ? 1.5 : 1,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: CircleAvatar(
                                    backgroundColor: color.withValues(alpha: 0.1),
                                    child: Icon(_iconeTipo(a.tipo), color: color),
                                  ),
                                  title: Text(
                                    a.mensagem,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontWeight: a.isUrgente ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            a.severidade,
                                            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(a.tipoLabel, style: TextStyle(color: textSecondary, fontSize: 12)),
                                        const Spacer(),
                                        Text(_formatarData(a.criadoEm), style: TextStyle(color: textSecondary, fontSize: 11)),
                                      ],
                                    ),
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

  Widget _buildFilterPill(String? tipo, String label, IconData icon) {
    final isSelected = _filtroTipo == tipo;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = AppColors.goldForBrightness(Theme.of(context).brightness);

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? gold : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _filtroTipo = tipo);
          _carregarAlertas();
        },
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        selectedColor: gold.withValues(alpha: 0.15),
        showCheckmark: false,
        labelStyle: TextStyle(
          color: isSelected ? gold : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? gold : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
      ),
    );
  }
}
