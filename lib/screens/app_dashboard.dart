import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/produto.dart';
import '../services/supabase_helper.dart';
import '../services/ia_service.dart';

class AppDashboard extends StatefulWidget {
  const AppDashboard({super.key});

  @override
  State<AppDashboard> createState() => _AppDashboardState();
}

class _AppDashboardState extends State<AppDashboard> {
  List<Produto> estoque = [];
  List<Map<String, dynamic>> historicoVendas = [];
  bool _isAnalyzing = false;
  String? _analiseIA;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final dados = await SupabaseHelper.getEstoque();
    final historico = await SupabaseHelper.getHistoricoVendas();

    setState(() {
      estoque = dados;
      historicoVendas = historico;
    });
  }

  Future<void> _gerarAnaliseInteligente() async {
    setState(() {
      _isAnalyzing = true;
      _analiseIA = null;
    });

    String resposta = await IaService.analisarEstoque(estoque, historicoVendas, []);

    setState(() {
      _analiseIA = resposta;
      _isAnalyzing = false;
    });
  }

  Widget _buildAbaCurvaABC() {
    List<Produto> listaOrdenada = List.from(estoque);
    
    // Ordena pelo Lucro Total (Qtd * (Venda - Compra)) em ordem decrescente
    listaOrdenada.sort((a, b) {
      double lucroA = a.quantidade * (a.valorVenda - a.valorCompra);
      double lucroB = b.quantidade * (b.valorVenda - b.valorCompra);
      return lucroB.compareTo(lucroA); 
    });

    int total = listaOrdenada.length;
    int limiteA = (total * 0.2).ceil();
    int limiteB = limiteA + (total * 0.3).ceil();

    return ListView.builder(
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
                const SizedBox(height: 12),
                Text("Clique em 'Gerar Insight Inteligente' para obter análise automática do estoque.",
                    style: TextStyle(color: Colors.blueGrey.shade700)),
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
      length: 2,
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
              Tab(icon: Icon(Icons.auto_awesome), text: "Consultor IA"),
            ],
          ),
        ),
        body: estoque.isEmpty
            ? const Center(child: Text("Sem dados no estoque para analisar."))
            : TabBarView(
                children: [
                  _buildAbaCurvaABC(),
                  _buildAbaConsultorIA(),
                ],
              ),
      ),
    );
  }
}