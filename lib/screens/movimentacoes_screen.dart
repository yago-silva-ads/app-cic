import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../services/supabase_helper.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// MovimentacoesScreen — Histórico de Estoque v2.0
///
/// Exibe um histórico de entradas e saídas (simulado no momento via 
/// tabela de movimentações, se existir).
/// ═══════════════════════════════════════════════════════════════════════
class MovimentacoesScreen extends StatefulWidget {
  const MovimentacoesScreen({super.key});

  @override
  State<MovimentacoesScreen> createState() => _MovimentacoesScreenState();
}

class _MovimentacoesScreenState extends State<MovimentacoesScreen> {
  bool _carregando = true;
  List<dynamic> _movimentacoes = [];
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _carregarMovimentacoes();
  }

  Future<void> _carregarMovimentacoes() async {
    setState(() => _carregando = true);
    try {
      // Como não temos a view/tabela 'movimentacoes' explicitada no helper, 
      // faremos um fetch genérico se a tabela existir, ou injetaremos mocks 
      // para demonstração do design system.
      try {
        final client = SupabaseHelper.supabase;
        final res = await client.from('movimentacoes').select().order('data_hora', ascending: false).limit(50);
        _movimentacoes = res;
      } catch (e) {
        // Fallback: Mocks para preview do layout
        _movimentacoes = [
          {'tipo': 'ENTRADA', 'produto': 'Fita LED RGB 5m', 'qtd': 50, 'data_hora': DateTime.now().toIso8601String()},
          {'tipo': 'SAIDA', 'produto': 'Arduino Uno R3', 'qtd': 2, 'data_hora': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String()},
          {'tipo': 'ENTRADA', 'produto': 'Sensor Ultrassônico HC-SR04', 'qtd': 100, 'data_hora': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
          {'tipo': 'SAIDA', 'produto': 'Módulo Relé 4 Canais', 'qtd': 5, 'data_hora': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
        ];
      }
    } catch (e) {
      debugPrint('Erro ao carregar movimentações: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = AppColors.goldForBrightness(Theme.of(context).brightness);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Movimentações'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _movimentacoes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, size: 64, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma movimentação registrada.',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: gold,
                  onRefresh: _carregarMovimentacoes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _movimentacoes.length,
                    itemBuilder: (context, index) {
                      final item = _movimentacoes[index];
                      final isEntrada = item['tipo'] == 'ENTRADA';
                      final data = DateTime.tryParse(item['data_hora'] ?? '');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isEntrada 
                                ? AppColors.success.withValues(alpha: 0.1) 
                                : AppColors.error.withValues(alpha: 0.1),
                            child: Icon(
                              isEntrada ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isEntrada ? AppColors.success : AppColors.error,
                            ),
                          ),
                          title: Text(
                            item['produto'] ?? 'Produto Desconhecido',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            data != null ? _dateFormat.format(data) : 'Data indisponível',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            '${isEntrada ? '+' : '-'}${item['qtd']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isEntrada ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
