import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/custo_operacional.dart';
import '../models/produto.dart';
import '../services/db_helper.dart';
import 'tela_estoque.dart';
import 'tela_vendedor.dart';

class TelaDashboard extends StatefulWidget {
  const TelaDashboard({super.key});

  @override
  State<TelaDashboard> createState() => _TelaDashboardState();
}

class _TelaDashboardState extends State<TelaDashboard> {
  List<Produto> estoque = [];
  List<CustoOperacional> custosOperacionais = [];
  double custoTotal = 0;
  double valorVendaTotal = 0;
  double custosOperacionaisTotal = 0;

  bool _isAnalyzing = false;
  String? _analiseIA;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final dados = await DBHelper.instance.getEstoque();
    final custos = await DBHelper.instance.getCustosOperacionais();
    double custo = 0;
    double venda = 0;
    double custosFixos = 0;

    for (var p in dados) {
      custo += (p.valorCompra * p.quantidade);
      venda += (p.valorVenda * p.quantidade);
    }

    for (var c in custos) {
      custosFixos += c.valor;
    }

    setState(() {
      estoque = dados;
      custosOperacionais = custos;
      custoTotal = custo;
      valorVendaTotal = venda;
      custosOperacionaisTotal = custosFixos;
    });
  }

  
  Future<void> _consultarIA() async {
    setState(() {
      _isAnalyzing = true;
      _analiseIA = null;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (estoque.isEmpty) {
      setState(() {
        _analiseIA = 'O seu estoque está vazio. Adicione produtos para que eu possa gerar insights!';
        _isAnalyzing = false;
      });
      return;
    }

    int produtosBaixoEstoque = 0;
    double maiorLucro = 0;
    String produtoMaiorLucro = '';

    for (var p in estoque) {
      if (p.quantidade < 5) produtosBaixoEstoque++;

      double lucroUnidade = p.valorVenda - p.valorCompra;
      if (lucroUnidade > maiorLucro) {
        maiorLucro = lucroUnidade;
        produtoMaiorLucro = p.nome;
      }
    }

    double margemGeral = custoTotal > 0 ? ((valorVendaTotal - custoTotal) / custoTotal) * 100 : 0;
    double custoTotalComOperacionais = custoTotal + custosOperacionaisTotal;

    String analise = '🤖 Análise Concluída:\n\n';
    analise += '📊 Margem Global: Sua margem de lucro projetada é de ${margemGeral.toStringAsFixed(1)}%.\n\n';

    if (produtosBaixoEstoque > 0) {
      analise += '⚠️ Atenção: Você tem $produtosBaixoEstoque produto(s) com baixo estoque (menos de 5 unidades). Sugiro reposição para não perder vendas.\n\n';
    } else {
      analise += '✅ Estoque Saudável: Todos os produtos estão com boas quantidades para atender a demanda.\n\n';
    }

    analise += '💼 Custos Operacionais: R\$ ${custosOperacionaisTotal.toStringAsFixed(2)}.\n';
    analise += valorVendaTotal >= custosOperacionaisTotal
        ? '✅ O valor de venda total do estoque compensa os custos fixos operacionais da loja.\n\n'
        : '⚠️ O valor de venda total do estoque ainda não cobre os custos fixos operacionais (diferença de R\$ ${(custosOperacionaisTotal - valorVendaTotal).abs().toStringAsFixed(2)}).\n\n';

    if (valorVendaTotal >= custoTotalComOperacionais) {
      analise += '🏁 Resultado geral: A receita projetada supera o custo total do estoque mais os custos operacionais.\n\n';
    } else {
      analise += '⚠️ Resultado geral: A receita projetada não cobre o custo total do estoque mais os custos operacionais. Ajuste preços ou custos.\n\n';
    }

    if (produtoMaiorLucro.isNotEmpty) {
      analise += '🏆 Destaque: O produto "$produtoMaiorLucro" é o que te traz maior lucro por unidade (R\$ ${maiorLucro.toStringAsFixed(2)}). Considere colocá-lo na vitrine ou fazer promoções casadas!';
    }

    setState(() {
      _analiseIA = analise;
      _isAnalyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    double lucroProjetado = valorVendaTotal - custoTotal;
    double lucroAposFixos = valorVendaTotal - (custoTotal + custosOperacionaisTotal);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Inteligente"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.pie_chart),
              title: const Text('Dashboard Inteligente'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Estoque Atual'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TelaEstoque(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Custos Operacionais'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TelaVendedor()),
                );
              },
            ),
          ],
        ),
      ),
      body: estoque.isEmpty && custosOperacionais.isEmpty
          ? const Center(child: Text("Sem dados no stock para analisar."))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text("Análise de Precificação", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Custo de Estoque:"),
                              Text("R\$ ${custoTotal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Retorno Esperado:"),
                              Text("R\$ ${valorVendaTotal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Custos Operacionais:"),
                              Text("R\$ ${custosOperacionaisTotal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 30, thickness: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Lucro Projetado:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text("R\$ ${lucroProjetado.toStringAsFixed(2)}", style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Lucro após custos (${custoTotal > 0 ? ((lucroAposFixos / custoTotal) * 100).toStringAsFixed(1) : '0.0'}% de lucro):", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              Text("R\$ ${lucroAposFixos.toStringAsFixed(2)}", style: const TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text("Custo vs Potencial de Venda", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 250,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: valorVendaTotal > 0 ? valorVendaTotal * 1.3 : 100,
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() == 0) return const Padding(padding: EdgeInsets.only(top: 10), child: Text('Estoque', style: TextStyle(fontWeight: FontWeight.bold)));
                                if (value.toInt() == 1) return const Padding(padding: EdgeInsets.only(top: 10), child: Text('Venda', style: TextStyle(fontWeight: FontWeight.bold)));
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: custoTotal, color: Colors.red.shade400, width: 40, borderRadius: BorderRadius.circular(4))]),
                          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: valorVendaTotal, color: Colors.green.shade400, width: 40, borderRadius: BorderRadius.circular(4))]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text("Custos Operacionais vs Venda Total", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 250,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: valorVendaTotal > 0 ? valorVendaTotal * 1.3 : 100,
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 60,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() == 0) return const Padding(padding: EdgeInsets.only(top: 10), child: Text('Estoque', style: TextStyle(fontWeight: FontWeight.bold)));
                                if (value.toInt() == 1) return const Padding(padding: EdgeInsets.only(top: 10), child: Text('Fixos', style: TextStyle(fontWeight: FontWeight.bold)));
                                if (value.toInt() == 2) return const Padding(padding: EdgeInsets.only(top: 10), child: Text('Venda', style: TextStyle(fontWeight: FontWeight.bold)));
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: custoTotal, color: Colors.red.shade400, width: 30, borderRadius: BorderRadius.circular(4))]),
                          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: custosOperacionaisTotal, color: Colors.orange.shade400, width: 30, borderRadius: BorderRadius.circular(4))]),
                          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: valorVendaTotal, color: Colors.green.shade400, width: 30, borderRadius: BorderRadius.circular(4))]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _consultarIA,
                    icon: _isAnalyzing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, color: Colors.white),
                    label: Text(_isAnalyzing ? "Analisando estoque..." : "Consultar IA ✨", style: const TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_analiseIA != null)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.deepPurple.shade200),
                      ),
                      child: Text(
                        _analiseIA!,
                        style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}