import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../widgets/kpi_card.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_text_field.dart';
import '../services/supabase_helper.dart';
import '../models/produto.dart';
import '../models/custo_operacional.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// DashboardScreen — Painel Principal Premium v2.0
///
/// Réplica mobile do dashboard React com:
/// - Alerta de Risco Operacional
/// - 4 KPI Cards (Custo Estoque, Faturamento, Lucro, Custos Fixos)
/// - Curva ABC (Pareto)
/// - Mix por Categoria
/// - Banner do Consultor IA
/// ═══════════════════════════════════════════════════════════════════════
class DashboardScreen extends StatefulWidget {
  final void Function(int)? onNavigate;

  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Produto> _estoque = [];
  List<CustoOperacional> _custos = [];
  Map<String, dynamic> _kpis = {};
  bool _carregando = true;
  bool _mostrarAlerta = true;

  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    try {
      final results = await Future.wait([
        SupabaseHelper.getEstoque(),
        SupabaseHelper.getCustosOperacionais(),
        SupabaseHelper.getKpisVendasMes(),
      ]);

      if (mounted) {
        setState(() {
          _estoque = results[0] as List<Produto>;
          _custos = results[1] as List<CustoOperacional>;
          _kpis = results[2] as Map<String, dynamic>;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // ── Cálculos ──
  double get _custoEstoque =>
      _estoque.fold(0.0, (s, p) => s + (p.valorCompra * p.quantidade));

  double get _faturamentoProjetado =>
      _estoque.fold(0.0, (s, p) => s + (p.valorVenda * p.quantidade));

  double get _lucroBruto => _faturamentoProjetado - _custoEstoque;

  double get _totalCustosFixos => _custos.fold(0.0, (s, c) => s + c.valor);

  double get _margemLucro =>
      _faturamentoProjetado > 0 ? (_lucroBruto / _faturamentoProjetado) * 100 : 0;

  bool get _riscoOperacional => _totalCustosFixos > _lucroBruto && _estoque.isNotEmpty;

  // ── Curva ABC ──
  List<Map<String, dynamic>> get _curvaAbc {
    if (_estoque.isEmpty) return [];

    final sorted = List<Produto>.from(_estoque)
      ..sort((a, b) {
        final va = a.valorVenda * a.quantidade;
        final vb = b.valorVenda * b.quantidade;
        return vb.compareTo(va);
      });

    final totalFaturamento =
        sorted.fold(0.0, (s, p) => s + (p.valorVenda * p.quantidade));

    if (totalFaturamento <= 0) return [];

    double acumulado = 0;
    final result = <Map<String, dynamic>>[];

    for (final p in sorted) {
      final faturamento = p.valorVenda * p.quantidade;
      acumulado += faturamento;
      final percentAcumulado = (acumulado / totalFaturamento) * 100;

      String classe;
      if (percentAcumulado <= 80) {
        classe = 'A';
      } else if (percentAcumulado <= 95) {
        classe = 'B';
      } else {
        classe = 'C';
      }

      result.add({
        'produto': p,
        'faturamento': faturamento,
        'percent': (faturamento / totalFaturamento) * 100,
        'classe': classe,
      });
    }

    return result;
  }

  // ── Mix por Categoria ──
  List<Map<String, dynamic>> get _mixCategoria {
    if (_estoque.isEmpty) return [];

    final categorias = <String, double>{};
    for (final p in _estoque) {
      final cat = p.origem.isNotEmpty ? p.origem : 'Outros';
      categorias[cat] = (categorias[cat] ?? 0) + (p.valorVenda * p.quantidade);
    }

    final total = categorias.values.fold(0.0, (s, v) => s + v);
    if (total <= 0) return [];

    final sorted = categorias.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((e) => {
      'categoria': e.key,
      'valor': e.value,
      'percent': (e.value / total) * 100,
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = AppColors.goldForBrightness(Theme.of(context).brightness);
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return RefreshIndicator(
      onRefresh: _carregarDados,
      color: gold,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Alerta de Risco Operacional ──
          if (_riscoOperacional && _mostrarAlerta)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Alerta: Seus custos fixos (${_currencyFormat.format(_totalCustosFixos)}) superam o lucro projetado (${_currencyFormat.format(_lucroBruto)}). Risco de prejuízo operacional!',
                          style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.error, size: 20),
                        onPressed: () => setState(() => _mostrarAlerta = false),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.auto_awesome, color: AppColors.error, size: 16),
                      label: const Text('Consultar IA', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                      onPressed: () => widget.onNavigate?.call(3),
                    ),
                  )
                ],
              ),
            ),

          // ── 4 KPI Cards (2x2 Grid) ──
          Row(
            children: [
              Expanded(
                child: KpiCard(
                  icon: Icons.inventory_2_outlined,
                  iconColor: AppColors.info,
                  title: 'Custo do Estoque',
                  value: _currencyFormat.format(_custoEstoque),
                  subtitle: '${_estoque.length} SKUs cadastrados',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KpiCard(
                  icon: Icons.trending_up_rounded,
                  iconColor: AppColors.gold,
                  title: 'Faturamento Projetado',
                  value: _currencyFormat.format(_faturamentoProjetado),
                  subtitle: 'Se vender tudo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: KpiCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: _lucroBruto >= 0 ? AppColors.success : AppColors.error,
                  title: 'Lucro Bruto',
                  value: _currencyFormat.format(_lucroBruto),
                  variation: '${_margemLucro.toStringAsFixed(1)}%',
                  isPositiveVariation: _lucroBruto >= 0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KpiCard(
                  icon: Icons.receipt_long_outlined,
                  iconColor: AppColors.warning,
                  title: 'Custos Fixos',
                  value: _currencyFormat.format(_totalCustosFixos),
                  subtitle: 'Meta break-even',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Curva ABC ──
          if (_curvaAbc.isNotEmpty) ...[
            _buildSectionHeader('Curva ABC de Estoque', textPrimary),
            const SizedBox(height: 8),

            // Legenda
            Row(
              children: [
                AbcClassBadge(classe: 'A'),
                const SizedBox(width: 4),
                Text('80%', style: TextStyle(fontSize: 11, color: textSecondary)),
                const SizedBox(width: 12),
                AbcClassBadge(classe: 'B'),
                const SizedBox(width: 4),
                Text('15%', style: TextStyle(fontSize: 11, color: textSecondary)),
                const SizedBox(width: 12),
                AbcClassBadge(classe: 'C'),
                const SizedBox(width: 4),
                Text('5%', style: TextStyle(fontSize: 11, color: textSecondary)),
              ],
            ),
            const SizedBox(height: 10),

            // Lista ABC (top 10)
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: _curvaAbc.take(10).map((item) {
                  final p = item['produto'] as Produto;
                  final classe = item['classe'] as String;
                  final percent = item['percent'] as double;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        AbcClassBadge(classe: classe),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            p.nome,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${percent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: classe == 'A'
                                ? AppColors.classeA
                                : classe == 'B'
                                    ? AppColors.classeB
                                    : AppColors.classeC,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Mix por Categoria ──
          if (_mixCategoria.isNotEmpty) ...[
            _buildSectionHeader('Mix por Categoria', textPrimary),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                children: _mixCategoria.map((item) {
                  final cat = item['categoria'] as String;
                  final valor = item['valor'] as double;
                  final percent = item['percent'] as double;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(cat, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary)),
                            Text(
                              '${percent.toStringAsFixed(1)}% • ${_currencyFormat.format(valor)}',
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            minHeight: 6,
                            backgroundColor: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            color: gold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Banner Consultor IA ──
          GestureDetector(
            onTap: () => widget.onNavigate?.call(3),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradientSubtle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.auto_awesome, color: gold, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Consultor IA Gemini',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Diagnóstico financeiro em tempo real',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: gold, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    );
  }
}
