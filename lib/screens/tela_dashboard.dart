import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/produto.dart';
import '../services/db_helper.dart';
import '../services/ia_service.dart';
import 'graficos_dashboard.dart';

class TelaDashboard extends StatefulWidget {
  const TelaDashboard({super.key});

  @override
  State<TelaDashboard> createState() => _TelaDashboardState();
}

class _TelaDashboardState extends State<TelaDashboard> {
  List<Produto> estoque = [];
  bool _isAnalyzing = false;
  String? _analiseIA;

  String _filtroOrigem = 'Todos';
  String _filtroMargem = 'Todos';
  String _filtroQtd = 'Todos';
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final dados = await DBHelper.instance.getEstoque();

    setState(() {
      estoque = dados;
    });
  }

  Future<void> _gerarAnaliseInteligente() async {
    setState(() {
      _isAnalyzing = true;
      _analiseIA = null;
    });

    String resposta = await IaService.analisarEstoque(estoque);

    setState(() {
      _analiseIA = resposta;
      _isAnalyzing = false;
    });
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

    String insight = await IaService.analisarProduto(p);

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
              Expanded(child: SingleChildScrollView(controller: controller, child: MarkdownBody(data: insight))),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text("Resumo Financeiro Global", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Custo Investido:"), Text("R\$ ${custoTotal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Faturamento Projetado:"), Text("R\$ ${vendaTotal.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
                  const Divider(height: 30),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Lucro Bruto:", style: TextStyle(fontWeight: FontWeight.bold)), Text("R\$ ${(vendaTotal - custoTotal).toStringAsFixed(2)}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))]),
                ],
              ),
            ),
          ),
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
          buildLineChartCard(estoque),
          const SizedBox(height: 20),
          Wrap(
            spacing: 15, runSpacing: 10,
            children: [
              _buildFilterDropdown("Origem", _filtroOrigem, ['Todos', 'Fabricado', 'Revendido'], (v) => setState(() => _filtroOrigem = v!)),
              _buildFilterDropdown("Margem", _filtroMargem, ['Todos', '> 30%', '<= 30%'], (v) => setState(() => _filtroMargem = v!)),
              _buildFilterDropdown("Estoque", _filtroQtd, ['Todos', 'Baixo (<5)', 'Normal (>=5)'], (v) => setState(() => _filtroQtd = v!)),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Painel Consultor IA (Teal)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.teal.shade700, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Consultor IA Global", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                      const SizedBox(height: 4),
                      Text("Clique no botão abaixo para gerar recomendações estratégicas completas baseadas em todo o seu inventário.", style: TextStyle(color: Colors.teal.shade800, fontSize: 13)),
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
            label: Text(_isAnalyzing ? "Analisando estoque..." : "Gerar Análise Inteligente", style: const TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
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