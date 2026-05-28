import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/produto.dart';
import '../services/supabase_helper.dart';
import '../services/ia_service.dart';
import '../models/custo_operacional.dart';
import 'leitor_screen.dart';
import 'tela_estoque.dart';
import 'tela_vendedor.dart';
import 'tela_chat_ia.dart';

class TelaDashboard extends StatefulWidget {
  const TelaDashboard({super.key});

  @override
  State<TelaDashboard> createState() => _TelaDashboardState();
}

class _TelaDashboardState extends State<TelaDashboard> {
  List<Produto> estoque = [];
  List<Map<String, dynamic>> historicoVendas = [];
  List<CustoOperacional> custosOperacionais = [];
  bool _isAnalyzing = false;
  String? _analiseIA;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    List<Produto> dados = [];
    List<Map<String, dynamic>> historico = [];
    List<CustoOperacional> custos = [];

    try {
      dados = await SupabaseHelper.getEstoque();
    } catch (e) {
      print("Dashboard: Erro ao carregar estoque: $e");
    }

    try {
      historico = await SupabaseHelper.getHistoricoVendas();
    } catch (e) {
      print("Dashboard: Erro ao carregar historico: $e");
    }

    try {
      custos = await SupabaseHelper.getCustosOperacionais();
    } catch (e) {
      print("Dashboard: Erro ao carregar custos: $e");
    }

    if (!mounted) return; // Proteção: impede erro se o usuário fechar a tela durante o carregamento

    setState(() {
      estoque = dados;
      historicoVendas = historico;
      custosOperacionais = custos;
      _isLoading = false;
    });
  }

  Future<void> _gerarAnaliseInteligente() async {
    setState(() {
      _isAnalyzing = true;
      _analiseIA = null;
    });

    // Envia o estoque E O HISTÓRICO para a IA fazer a visão preditiva!
    String resposta = await IaService.analisarEstoque(estoque, historicoVendas, custosOperacionais);

    if (!mounted) return; // Proteção

    setState(() {
      _analiseIA = resposta;
      _isAnalyzing = false;
    });
  }

  Widget _buildAlertaPrejuizo() {
    double lucroProjetado = 0;
    for (var p in estoque) {
      lucroProjetado += (p.valorVenda - p.valorCompra) * p.quantidade;
    }

    double custoTotal = 0;
    for (var c in custosOperacionais) {
      custoTotal += c.valor;
    }

    // Limite da Meta: Exibe aviso de prejuízo caso o lucro bruto não cubra o custo operacional.
    if (lucroProjetado < custoTotal && custoTotal > 0) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '⚠️ Alerta: Seu lucro projetado não cobre os custos operacionais mensais. Reveja a margem de lucro dos seus produtos.',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildAbaCurvaABC() {
    if (estoque.isEmpty) {
      return const Center(child: Text("Sem dados no estoque para analisar."));
    }

    List<Produto> listaOrdenada = List.from(estoque);

    listaOrdenada.sort((a, b) {
      double lucroA = a.quantidade * (a.valorVenda - a.valorCompra);
      double lucroB = b.quantidade * (b.valorVenda - b.valorCompra);
      return lucroB.compareTo(lucroA);
    });

    int total = listaOrdenada.length;
    int limiteA = (total * 0.2).ceil();
    int limiteB = limiteA + (total * 0.3).ceil();

    return Column(
      children: [
        _buildAlertaPrejuizo(), // Card crítico fixado no topo
        Expanded(
          child: ListView.builder(
            itemCount: total,
            itemBuilder: (context, index) {
              Produto p = listaOrdenada[index];
              double lucroTotal = p.quantidade * (p.valorVenda - p.valorCompra);

              String classe;
              Color cor;
              if (index < limiteA) {
                classe = 'Classe A';
                cor = Colors.green;
              } else if (index < limiteB) {
                classe = 'Classe B';
                cor = Colors.orange;
              } else {
                classe = 'Classe C';
                cor = Colors.red;
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: cor.withOpacity(0.2),
                  child: Text(
                    classe.split(' ').last,
                    style: TextStyle(color: cor, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(p.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Lucro Projetado: R\$ ${lucroTotal.toStringAsFixed(2)}"),
                trailing: Text(classe, style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAbaFluxoCaixa() {
    if (historicoVendas.isEmpty) {
      return const Center(
        child: Text(
          "Nenhuma venda registrada ainda no Supabase.\nVá em Estoque Atual -> Vendas e registre uma saída!",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    List<FlSpot> vendasSpots = [];
    double totalFaturamento = 0;
    double faturamentoAcumulado = 0;
    List<Widget> historicoDetalhado = [];

    for (int i = 0; i < historicoVendas.length; i++) {
      var venda = historicoVendas[i];
      // Tratamento seguro para os números do Supabase
      double valorUnitario = double.tryParse(venda['valor_unitario'].toString()) ?? 0.0;
      int quantidade = int.tryParse(venda['quantidade_vendida'].toString()) ?? 0;
      String codigoProduto = venda['produto_codigo'].toString();
      
      double valorTotalVenda = valorUnitario * quantidade;
      totalFaturamento += valorTotalVenda;
      faturamentoAcumulado += valorTotalVenda;
      
      vendasSpots.add(FlSpot(i.toDouble(), faturamentoAcumulado));

      // Busca o nome do produto na lista de estoque
      String nomeProduto = "Produto Excluído";
      try {
        nomeProduto = estoque.firstWhere((p) => p.codigo == codigoProduto).nome;
      } catch (_) {}

      // Cria o item da lista (inserindo no topo para os mais recentes aparecerem primeiro)
      historicoDetalhado.insert(
        0,
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Colors.green.shade100,
            child: Icon(Icons.check_circle, color: Colors.green.shade700),
          ),
          title: Text(nomeProduto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text("$quantidade un. x R\$ ${valorUnitario.toStringAsFixed(2).replaceAll('.', ',')}", style: const TextStyle(fontSize: 12)),
          trailing: Text(
            "+ R\$ ${valorTotalVenda.toStringAsFixed(2).replaceAll('.', ',')}",
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                const Text("Faturamento Total Registrado", style: TextStyle(fontSize: 14, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                Text(
                  "R\$ ${totalFaturamento.toStringAsFixed(2).replaceAll('.', ',')}",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("Evolução do Faturamento", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          SizedBox(
            height: 120, // Altura ajustada para dar espaço à lista detalhada
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (group) => Colors.blueGrey.shade900,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          'Acumulado:\nR\$ ${spot.y.toStringAsFixed(2).replaceAll('.', ',')}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: vendasSpots,
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.2)),
                  ),
                ],
                titlesData: const FlTitlesData(
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text("Detalhamento das Vendas", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const Divider(),
          Expanded(
            child: ListView(
              children: historicoDetalhado,
            ),
          ),
          if (_analiseIA != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => TelaChatIA(diagnosticoInicial: _analiseIA!)));
              },
              icon: const Icon(Icons.chat),
              label: const Text("Aprofundar Análise no Chat"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAbaConsultorIA() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.auto_awesome, color: Colors.teal, size: 28),
                    SizedBox(width: 8),
                    Text("Consultor IA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    "Acesso Ilimitado (Powered by Gemini)",
                    style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Text("Clique em 'Gerar Relatório de Mercado' para obter previsões de vendas baseadas em datas, alertas de inflação e metas para cobrir seus custos fixos.",
                    style: TextStyle(color: Colors.blueGrey.shade700)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade200)),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(child: Text("Dica de Letramento: Após gerar o relatório, clique em 'Aprofundar no Chat' e pergunte à IA: 'Se eu vender 50 produtos a mais, quanto sobra pro meu bolso?'", style: TextStyle(fontSize: 12, color: Colors.amber.shade900))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isAnalyzing ? null : _gerarAnaliseInteligente,
            icon: _isAnalyzing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.auto_awesome, color: Colors.white),
            label: Text(_isAnalyzing ? "Analisando previsões..." : "Gerar Relatório de Mercado", style: const TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _analiseIA == null
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: MarkdownBody(data: _analiseIA!),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Dashboard & IA"),
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.analytics), text: "Curva ABC"),
              Tab(icon: Icon(Icons.show_chart), text: "Fluxo Caixa"),
              Tab(icon: Icon(Icons.auto_awesome), text: "Consultor IA"),
            ],
          ),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.1,
                child: DrawerHeader(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: const BoxDecoration(color: Color(0xFF1565C0)),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Menu',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Página Inicial'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LeitorScreen()));
                },
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
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TelaEstoque()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('Custos Operacionais'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TelaVendedor()));
                },
              ),
            ],
          ),
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text("Debug: Estoque (${estoque.length}) | Vendas (${historicoVendas.length})", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildAbaCurvaABC(),
                        _buildAbaFluxoCaixa(),
                        _buildAbaConsultorIA(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}