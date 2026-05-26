import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/produto.dart';
import '../models/custo_operacional.dart';
import '../services/db_helper.dart';
import '../services/ia_service.dart';
import 'graficos_dashboard.dart';
import 'leitor_screen.dart';
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
  bool _isAnalyzing = false;
  String? _analiseIA;

  String _filtroOrigem = 'Todos';
  String _filtroMargem = 'Todos';
  String _filtroQtd = 'Todos';
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  
  // Expandidos dos cards
  Set<String> _expandidosCards = {};

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final dados = await DBHelper.instance.getEstoque();
      final custos = await DBHelper.instance.getCustosOperacionais();

      setState(() {
        estoque = dados;
        custosOperacionais = custos;
      });
    } catch (e) {
      // Silenciar para não quebrar a tela
    }
  }

  Future<void> _gerarAnaliseInteligente() async {
    setState(() {
      _isAnalyzing = true;
      _analiseIA = null;
    });

    try {
      String resposta = await IaService.analisarEstoque(estoque);
      setState(() {
        _analiseIA = resposta;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _analiseIA = "ERRO_OFFLINE";
        _isAnalyzing = false;
      });
    }
  }

  List<Produto> get _filteredEstoque {
    List<Produto> filtered = estoque.where((p) {
      if (_filtroOrigem != 'Todos' && p.origem != _filtroOrigem) return false;
      double margem = p.valorCompra > 0 ? ((p.valorVenda - p.valorCompra) / p.valorCompra) * 100 : 0;
      if (_filtroMargem == '> 30%' && margem <= 30) return false;
      if (_filtroMargem == '<= 30%' && margem > 30) return false;
      if (_filtroQtd == 'Baixo (<5)' && p.quantidade >= 5) return false;
      if (_filtroQtd == 'Normal (>=5)' && p.quantidade < 5) return false;
      return true;
    }).toList();

    filtered.sort((a, b) {
      int cmp = 0;
      switch (_sortColumnIndex) {
        case 0: cmp = a.nome.compareTo(b.nome); break;
        case 1: cmp = a.quantidade.compareTo(b.quantidade); break;
        case 2: cmp = (a.quantidade * a.valorCompra).compareTo(b.quantidade * b.valorCompra); break;
        case 3: cmp = (a.quantidade * a.valorVenda).compareTo(b.quantidade * b.valorVenda); break;
        case 4:
          double mA = a.valorCompra > 0 ? ((a.valorVenda - a.valorCompra) / a.valorCompra) * 100 : 0;
          double mB = b.valorCompra > 0 ? ((b.valorVenda - b.valorCompra) / b.valorCompra) * 100 : 0;
          cmp = mA.compareTo(mB);
          break;
        case 5: cmp = a.origem.compareTo(b.origem); break;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return filtered.take(50).toList();
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  Widget _buildAnaliseVendasCard() {
    int totalEstoque = 0;
    int totalVendido = 0;
    int totalRestante = 0;

    for (var p in estoque) {
      totalEstoque += p.quantidade;
      totalVendido += p.vendidas;
      totalRestante += (p.quantidade - p.vendidas);
    }

    double percentualVendido = totalEstoque > 0 ? (totalVendido / totalEstoque) * 100 : 0;
    double percentualRestante = totalEstoque > 0 ? (totalRestante / totalEstoque) * 100 : 0;

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
            Row(
              children: [
                Container(width: 4, height: 16, color: pbiBlue1),
                const SizedBox(width: 8),
                const Text("Análise de Vendas", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 4),
            const Text("Comparativo entre unidades vendidas e estoque disponível.", style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text("Total em Estoque", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text("$totalEstoque", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ],
                ),
                Column(
                  children: [
                    Text("Vendidas", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text("$totalVendido", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: pbiBlue1)),
                  ],
                ),
                Column(
                  children: [
                    Text("Restante", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text("$totalRestante", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            ClipRect(
              child: LinearProgressIndicator(
                minHeight: 12,
                value: percentualVendido / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(pbiBlue1),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${percentualVendido.toStringAsFixed(1)}% Vendido", style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                Text("${percentualRestante.toStringAsFixed(1)}% Restante", style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              style: TextStyle(color: Colors.blueGrey.shade900, fontSize: 14),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _mostrarAnaliseProduto(Produto p) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [CircularProgressIndicator(), SizedBox(width: 20), Text("Consultando IA...")],
        ),
      ),
    );

    String insight;
    try {
      insight = await IaService.analisarProduto(p);
    } catch (e) {
      insight = "ERRO_OFFLINE";
    }

    if (!mounted) return;
    Navigator.pop(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Análise: ${p.nome}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
              const Divider(),
              Expanded(
                child: insight == "ERRO_OFFLINE"
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 64, color: Colors.blueGrey.shade300),
                          const SizedBox(height: 16),
                          Text("Modo Offline: Verifique sua conexão para gerar análises inteligentes", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(controller: controller, child: MarkdownBody(data: insight)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumoCard(String titulo, double valor, Color corIcone, IconData icone, String descricao) {
    bool expandido = _expandidosCards.contains(titulo);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          setState(() {
            if (expandido) {
              _expandidosCards.remove(titulo);
            } else {
              _expandidosCards.add(titulo);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: corIcone.withOpacity(0.1),
                          radius: 25,
                          child: Icon(icone, color: corIcone, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(titulo, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text("R\$ ${valor.toStringAsFixed(2)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expandido ? Icons.expand_less : Icons.expand_more,
                    color: corIcone,
                  ),
                ],
              ),
              if (expandido) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  descricao,
                  style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade700, height: 1.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAbaVisaoGeral() {
    double custoTotal = 0, vendaTotal = 0;
    for (var p in estoque) {
      custoTotal += p.quantidade * p.valorCompra;
      vendaTotal += p.quantidade * p.valorVenda;
    }
    double custosFixos = 0;
    for (var c in custosOperacionais) {
      custosFixos += c.valor;
    }
    double lucroBruto = vendaTotal - custoTotal;
    double lucroLiquido = lucroBruto - custosFixos;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Resumo Financeiro Global", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          const Text("Acompanhe o capital total investido e o retorno projetado de todo o seu inventário.", style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 24),
          _buildResumoCard("Custo do Estoque", custoTotal, Colors.redAccent, Icons.shopping_bag_outlined, "O valor utilizado para comprar/fabricar os produtos que serão revendidos."),
          const SizedBox(height: 12),
          _buildResumoCard("Custos Operacionais", custosFixos, Colors.orange, Icons.money_off, "O valor gasto no dia a dia para manter a loja funcionando, como frete, embalagens, água ou luz."),
          const SizedBox(height: 12),
          _buildResumoCard("Faturamento Projetado", vendaTotal, Colors.green, Icons.point_of_sale, "O valor total que vai entrar no seu caixa se todos os produtos forem vendidos pelo preço atual."),
          const SizedBox(height: 12),
          _buildResumoCard("Lucro Bruto", lucroBruto, Colors.blueAccent, Icons.trending_up, "O valor que sobra das suas vendas depois de pagar apenas o custo de compra das mercadorias vendidas."),
          const SizedBox(height: 12),
          _buildResumoCard("Saldo Operacional (Fora Impostos e Taxas)", lucroLiquido, Colors.teal, Icons.account_balance_wallet, "O resultado final do seu negócio após pagar tudo (estoque e despesas). Se estiver negativo, significa que a loja está operando no prejuízo."),
          const SizedBox(height: 30),
          const Center(child: Text("Navegue pelas abas acima para gráficos e Inteligência Artificial.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildAbaTabelaBI() {
    List<Produto> filteredList = _filteredEstoque;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Painel Análise BI (Indigo)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.analytics, color: Colors.indigo.shade700, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Análise BI Avançada", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
                      const SizedBox(height: 4),
                      Text("Filtre e ordene as variáveis analíticas (Margem, Custo, Venda). Clique em uma linha na tabela para análise IA específica do produto.", style: TextStyle(color: Colors.indigo.shade700, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          buildPieChartCard(estoque),
          const SizedBox(height: 20),
          buildStackedBarChartCard(estoque),
          const SizedBox(height: 20),
          _buildAnaliseVendasCard(),
          const SizedBox(height: 20),
          buildLineChartCard(estoque),
          const SizedBox(height: 30),
          const Text("Tabela Analítica (Detalhamento)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 10),
          Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Filtros de Tabela", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 15, runSpacing: 10,
                    children: [
                      _buildFilterDropdown("Origem", _filtroOrigem, ['Todos', 'Fabricado', 'Revendido'], (v) => setState(() => _filtroOrigem = v!)),
                      _buildFilterDropdown("Margem", _filtroMargem, ['Todos', '> 30%', '<= 30%'], (v) => setState(() => _filtroMargem = v!)),
                      _buildFilterDropdown("Estoque", _filtroQtd, ['Todos', 'Baixo (<5)', 'Normal (>=5)'], (v) => setState(() => _filtroQtd = v!)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 2, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _sortColumnIndex, sortAscending: _sortAscending, showCheckboxColumn: false,
                columns: [
                  DataColumn(label: const Text("Produto", style: TextStyle(fontWeight: FontWeight.bold)), onSort: _onSort),
                  DataColumn(label: const Text("Qtd", style: TextStyle(fontWeight: FontWeight.bold)), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text("Custo Total", style: TextStyle(fontWeight: FontWeight.bold)), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text("Valor Total", style: TextStyle(fontWeight: FontWeight.bold)), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text("Margem", style: TextStyle(fontWeight: FontWeight.bold)), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text("Origem", style: TextStyle(fontWeight: FontWeight.bold)), onSort: _onSort),
                ],
                rows: filteredList.map((p) {
                  double margem = p.valorCompra > 0 ? ((p.valorVenda - p.valorCompra) / p.valorCompra) * 100 : 0;
                  return DataRow(
                    onSelectChanged: (_) => _mostrarAnaliseProduto(p),
                    cells: [
                      DataCell(Text(p.nome, overflow: TextOverflow.ellipsis)),
                      DataCell(Text("${p.quantidade}")),
                      DataCell(Text("R\$ ${(p.quantidade * p.valorCompra).toStringAsFixed(2)}")),
                      DataCell(Text("R\$ ${(p.quantidade * p.valorVenda).toStringAsFixed(2)}")),
                      DataCell(Text("${margem.toStringAsFixed(1)}%", style: TextStyle(color: margem < 20 ? Colors.red : Colors.green, fontWeight: FontWeight.bold))),
                      DataCell(Text(p.origem)),
                    ]
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbaConsultorIA() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blueGrey.withOpacity(0.1), blurRadius: 15, spreadRadius: 5)],
        border: Border.all(color: Colors.teal.shade100, width: 1.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.psychology, size: 40, color: Colors.teal.shade700),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Consultor Executivo IA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.teal.shade900)),
                      const SizedBox(height: 4),
                      Text("Decisões estratégicas baseadas em inteligência de mercado.", style: TextStyle(color: Colors.teal.shade700, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton.icon(
              onPressed: _isAnalyzing ? null : _gerarAnaliseInteligente,
              icon: _isAnalyzing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.insights, color: Colors.white),
              label: Text(_isAnalyzing ? "Processando Algoritmos..." : "Gerar Diagnóstico Estratégico", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(55),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          Expanded(
            child: _analiseIA == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.query_stats, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text("Aguardando comando para analisar inventário.", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                      ],
                    ),
                  )
                : _analiseIA == "ERRO_OFFLINE"
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off_rounded, size: 60, color: Colors.red.shade300),
                            const SizedBox(height: 16),
                            Text("Conexão com o servidor IA perdida.", style: TextStyle(color: Colors.red.shade400, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: MarkdownBody(
                          data: _analiseIA!,
                          styleSheet: MarkdownStyleSheet(
                            h1: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold),
                            h2: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.bold),
                            p: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                            listBullet: TextStyle(color: Colors.teal.shade600),
                          ),
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
          backgroundColor: Colors.blueGrey.shade900,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: "Visão Geral"),
              Tab(icon: Icon(Icons.table_chart), text: "Análise BI"),
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
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LeitorScreen()),
                  );
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
        backgroundColor: const Color(0xFFF5F6FA),
        body: estoque.isEmpty
            ? const Center(child: Text("Sem dados no estoque para analisar."))
            : TabBarView(
                children: [
                  _buildAbaVisaoGeral(),
                  _buildAbaTabelaBI(),
                  _buildAbaConsultorIA(),
                ],
              ),
      ),
    );
  }
}