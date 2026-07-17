import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/produto.dart';

// Paleta de Cores inspirada no PowerBI
const Color pbiBlue1 = Color(0xFF118DFF);
const Color pbiTeal = Color(0xFF00B8AA);
const Color pbiOrange = Color(0xFFE66C37);
const Color pbiPurple = Color(0xFF6B007B);

Widget _buildHeader(String title, String subtitle) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(width: 4, height: 16, color: pbiBlue1),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
    ],
  );
}

Widget _buildLegend(Color color, String text) {
  return Row(
    children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
    ],
  );
}

Widget buildPieChartCard(List<Produto> estoque) {
  if (estoque.isEmpty) return const SizedBox.shrink();

  int qtdRevendido = 0;
  int qtdFabricado = 0;
  for (var p in estoque) {
    String o = p.origem.toLowerCase();
    if (o == 'revendido') qtdRevendido += p.quantidade;
    if (o == 'fabricado' || o == 'produzido') qtdFabricado += p.quantidade;
  }

  return Card(
    elevation: 2,
    color: Colors.white,
    shadowColor: Colors.black12,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader("Composição do Estoque", "Quantidade de itens físicos separados por origem de aquisição."),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: [
                  if (qtdRevendido > 0)
                    PieChartSectionData(
                      value: qtdRevendido.toDouble(),
                      title: '$qtdRevendido',
                      color: pbiBlue1,
                      radius: 45,
                      titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  if (qtdFabricado > 0)
                    PieChartSectionData(
                      value: qtdFabricado.toDouble(),
                      title: '$qtdFabricado',
                      color: pbiTeal,
                      radius: 45,
                      titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(pbiBlue1, "Revendido"),
              const SizedBox(width: 16),
              _buildLegend(pbiTeal, "Fabricado"),
            ],
          )
        ],
      ),
    ),
  );
}

Widget buildStackedBarChartCard(List<Produto> estoque) {
  if (estoque.isEmpty) return const SizedBox.shrink();

  double custoRevendido = 0, lucroRevendido = 0;
  double custoFabricado = 0, lucroFabricado = 0;

  for (var p in estoque) {
    String o = p.origem.toLowerCase();
    if (o == 'revendido') {
      custoRevendido += p.valorCompra * p.quantidade;
      lucroRevendido += (p.valorVenda - p.valorCompra) * p.quantidade;
    } else if (o == 'fabricado' || o == 'produzido') {
      custoFabricado += p.valorCompra * p.quantidade;
      lucroFabricado += (p.valorVenda - p.valorCompra) * p.quantidade;
    }
  }

  return Card(
    elevation: 2,
    color: Colors.white,
    shadowColor: Colors.black12,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader("Margem por Categoria (R\$)", "Comparativo entre Custo Investido e Lucro Potencial de Venda."),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.blueGrey.shade900,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        'Total: R\$ ${rod.toY.toStringAsFixed(2)}',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: custoRevendido + (lucroRevendido > 0 ? lucroRevendido : 0),
                        rodStackItems: [
                          BarChartRodStackItem(0, custoRevendido, pbiOrange),
                          if (lucroRevendido > 0) BarChartRodStackItem(custoRevendido, custoRevendido + lucroRevendido, pbiBlue1),
                        ],
                        width: 35,
                        borderRadius: BorderRadius.zero,
                      )
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: custoFabricado + (lucroFabricado > 0 ? lucroFabricado : 0),
                        rodStackItems: [
                          BarChartRodStackItem(0, custoFabricado, pbiOrange),
                          if (lucroFabricado > 0) BarChartRodStackItem(custoFabricado, custoFabricado + lucroFabricado, pbiBlue1),
                        ],
                        width: 35,
                        borderRadius: BorderRadius.zero,
                      )
                    ],
                  ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() == 0) return const Padding(padding: EdgeInsets.only(top: 8), child: Text("Revendido", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)));
                        if (value.toInt() == 1) return const Padding(padding: EdgeInsets.only(top: 8), child: Text("Fabricado", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)));
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    )
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(pbiOrange, "Custo"),
              const SizedBox(width: 16),
              _buildLegend(pbiBlue1, "Lucro"),
            ],
          )
        ],
      ),
    ),
  );
}

Widget buildLineChartCard(List<Produto> estoque) {
  if (estoque.isEmpty) return const SizedBox.shrink();

  List<Produto> ordenados = List.from(estoque)..sort((a, b) => a.valorCompra.compareTo(b.valorCompra));
  List<FlSpot> custoSpots = [];
  List<FlSpot> lucroSpots = [];

  for (int i = 0; i < ordenados.length; i++) {
    double custo = ordenados[i].valorCompra;
    double lucro = ordenados[i].valorVenda - ordenados[i].valorCompra;
    custoSpots.add(FlSpot(i.toDouble(), custo));
    lucroSpots.add(FlSpot(i.toDouble(), lucro > 0 ? lucro : 0));
  }

  return Card(
    elevation: 2,
    color: Colors.white,
    shadowColor: Colors.black12,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader("Evolução Custo vs Lucro", "Curva de lucro de cada produto no estoque ordenado pelo custo de compra."),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (group) => Colors.blueGrey.shade900,
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: custoSpots,
                    isCurved: true,
                    color: pbiOrange,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: pbiOrange.withOpacity(0.1)),
                  ),
                  LineChartBarData(
                    spots: lucroSpots,
                    isCurved: true,
                    color: pbiBlue1,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: pbiBlue1.withOpacity(0.1)),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    )
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(pbiOrange, "Custo"),
              const SizedBox(width: 16),
              _buildLegend(pbiBlue1, "Lucro"),
            ],
          )
        ],
      ),
    ),
  );
}