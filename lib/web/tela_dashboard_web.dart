import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/alerta.dart';
import '../models/custo_operacional.dart';
import '../models/produto.dart';
import '../services/supabase_helper.dart';
import 'package:intl/intl.dart';

class TelaDashboardWeb extends StatefulWidget {
  final bool isEmbedded;
  const TelaDashboardWeb({super.key, this.isEmbedded = false});

  @override
  State<TelaDashboardWeb> createState() => _TelaDashboardWebState();
}

class _TelaDashboardWebState extends State<TelaDashboardWeb> {
  bool isLoading = true;
  List<Produto> estoque = [];
  Map<String, dynamic> kpis = {};
  List<Alerta> alertas = [];
  List<Map<String, dynamic>> faturamentoMensal = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => isLoading = true);
    try {
      final futures = await Future.wait([
        SupabaseHelper.getEstoque(),
        SupabaseHelper.getAlertas(),
        SupabaseHelper.getKpisVendasMes(),
        SupabaseHelper.getFaturamentoMensal(),
      ]);
      if (!mounted) return;
      setState(() {
        estoque = futures[0] as List<Produto>;
        alertas = futures[1] as List<Alerta>;
        kpis = futures[2] as Map<String, dynamic>;
        faturamentoMensal = futures[3] as List<Map<String, dynamic>>;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _formatarMoeda(double valor) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(valor);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isMobile = MediaQuery.of(context).size.width < 800;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.isEmbedded)
          Text(
            'Visão Geral',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        if (!widget.isEmbedded)
          const SizedBox(height: 16),
        _buildKpiGrid(isMobile),
        const SizedBox(height: 24),
        Text(
          'Faturamento Mensal',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildGraficoFaturamento(isMobile),
      ],
    );

    if (widget.isEmbedded) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: content,
      );
    }

    return RefreshIndicator(
      onRefresh: _carregarDados,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: content,
      ),
    );
  }

  Widget _buildKpiGrid(bool isMobile) {
    final receitaTotal = (kpis['receita_total'] as num?)?.toDouble() ?? 0.0;
    final lucroBruto = (kpis['lucro_bruto'] as num?)?.toDouble() ?? 0.0;
    final alertasAtivos = alertas.where((a) => !a.lido).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = 16;
        int columns = isMobile ? 2 : 4;
        
        // Se a tela for muito pequena (ex: iPhone SE), garantimos pelo menos 1 coluna decente ou 2 menores
        if (constraints.maxWidth < 300) columns = 1;

        final double cardWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _buildSimpleCard('Receita Total', _formatarMoeda(receitaTotal), Icons.attach_money, Colors.green, cardWidth),
            _buildSimpleCard('Lucro Bruto', _formatarMoeda(lucroBruto), Icons.trending_up, Colors.blue, cardWidth),
            _buildSimpleCard('Qtd Produtos', '${estoque.length}', Icons.inventory_2, Colors.orange, cardWidth),
            _buildSimpleCard('Alertas', '$alertasAtivos', Icons.notifications, alertasAtivos > 0 ? Colors.red : Colors.grey, cardWidth),
          ],
        );
      },
    );
  }

  Widget _buildSimpleCard(String titulo, String valor, IconData icone, Color cor, double width) {
    return Container(
      width: width,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icone, color: cor, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                valor,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraficoFaturamento(bool isMobile) {
    if (faturamentoMensal.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: Text('Sem dados de faturamento.')),
        ),
      );
    }
    return Card(
      elevation: 2,
      child: Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: true),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (value, meta) => Text(
                    'R\$${(value/1000).toStringAsFixed(1)}k',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx >= 0 && idx < faturamentoMensal.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          faturamentoMensal[idx]['mes_label'] ?? '',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
            lineBarsData: [
              LineChartBarData(
                spots: faturamentoMensal.asMap().entries.map((e) {
                  return FlSpot(e.key.toDouble(), (e.value['faturamento'] as num?)?.toDouble() ?? 0);
                }).toList(),
                isCurved: true,
                color: Colors.blue,
                barWidth: 3,
                belowBarData: BarAreaData(show: true, color: Colors.blue.withValues(alpha: 0.1)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
