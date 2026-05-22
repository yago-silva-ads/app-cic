import 'package:flutter/material.dart';
import '../models/produto.dart';
import '../utils/moeda_formatter.dart';
import '../services/db_helper.dart';
import 'leitor_screen.dart';
import 'tela_dashboard.dart';
import 'tela_vendedor.dart';

class TelaEstoque extends StatefulWidget {
  final List<Produto>? estoque;
  final VoidCallback? onUpdate;
  const TelaEstoque({super.key, this.estoque, this.onUpdate});

  @override
  State<TelaEstoque> createState() => _TelaEstoqueState();
}

class _TelaEstoqueState extends State<TelaEstoque> {
  List<Produto> estoqueLocal = [];

  @override
  void initState() {
    super.initState();
    _carregarEstoque();
  }

  Future<void> _carregarEstoque() async {
    if (widget.estoque != null) {
      setState(() {
        estoqueLocal = widget.estoque!;
      });
    } else {
      final produtos = await DBHelper.instance.getEstoque();
      setState(() {
        estoqueLocal = produtos;
      });
    }
  }

  void _onUpdate() {
    _carregarEstoque();
    if (widget.onUpdate != null) {
      widget.onUpdate!();
    }
  }

  void _edit(int index) {
    Produto p = estoqueLocal[index];
    TextEditingController n = TextEditingController(text: p.nome);
    TextEditingController q = TextEditingController(
      text: p.quantidade.toString(),
    );
    TextEditingController custoCtrl = TextEditingController(
      text: p.valorCompra.toStringAsFixed(2).replaceAll('.', ','),
    );
    TextEditingController markupCtrl = TextEditingController(
      text: p.markup.toString(),
    );
    TextEditingController vendaCtrl = TextEditingController(
      text: p.valorVenda.toStringAsFixed(2).replaceAll('.', ','),
    );
    String tipoSelecionado = (p.origem.toLowerCase() == 'fabricado' || p.origem.toLowerCase() == 'produzido') ? 'Fabricado' : 'Revendido';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        // <-- Isso permite atualizar a caixinha em tempo real!
        builder: (context, setStateModal) {
          bool margemSeguraModal = double.tryParse(markupCtrl.text.replaceAll(',', '.')) != null && double.parse(markupCtrl.text.replaceAll(',', '.')) >= 1.3;

          // Função que recalcula a Venda na hora que digita o Custo ou Markup
          void recalcularVenda() {
            double? c = double.tryParse(
              custoCtrl.text.replaceAll('.', '').replaceAll(',', '.'),
            );
            double? m = double.tryParse(markupCtrl.text.replaceAll(',', '.'));
            if (c != null && m != null) {
              setStateModal(() {
                margemSeguraModal = m >= 1.3;
                vendaCtrl.text = (c * m)
                    .toStringAsFixed(2)
                    .replaceAll('.', ',');
              });
            }
          }

          return AlertDialog(
            title: const Text("Editar Produto"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: n,
                    decoration: const InputDecoration(labelText: "Nome do Produto"),
                  ),
                  TextField(
                    controller: q,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Quantidade em Estoque"),
                  ),
                  TextField(
                    controller: custoCtrl,
                    inputFormatters: [MoedaFormatter()],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Custo Unitário (R\$)"),
                    onChanged: (_) =>
                        recalcularVenda(), // Chama o cálculo ao digitar
                  ),
                  TextField(
                    controller: markupCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: "Margem de Lucro (Markup)",
                      errorText: margemSeguraModal ? null : '⚠️ Margem muito baixa!',
                    ),
                    onChanged: (_) =>
                        recalcularVenda(), 
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: tipoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Origem do Produto',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Revendido',
                        child: Text('Revendido'),
                      ),
                      DropdownMenuItem(
                        value: 'Fabricado',
                        child: Text('Fabricado'),
                      ),
                    ],
                    onChanged: (value) {
                      setStateModal(() => tipoSelecionado = value!);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: vendaCtrl,
                    readOnly: true,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Preço de Venda Sugerido (R\$)",
                      filled: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!margemSeguraModal) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Ação Bloqueada: Corrija a margem de lucro!"),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  int? parsedQtd = int.tryParse(q.text);
                  double? parsedCusto = double.tryParse(custoCtrl.text.replaceAll('.', '').replaceAll(',', '.'));
                  double? parsedMarkup = double.tryParse(markupCtrl.text.replaceAll(',', '.'));
                  double? parsedVenda = double.tryParse(vendaCtrl.text.replaceAll('.', '').replaceAll(',', '.'));

                  if (parsedQtd == null || parsedCusto == null || parsedMarkup == null || parsedVenda == null ||
                      parsedQtd <= 0 || parsedCusto <= 0 || parsedMarkup <= 0 || parsedVenda <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Erro: Valores numéricos não podem estar vazios ou zerados!"),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Produto produtoAtualizado = Produto(
                    codigo: p.codigo,
                    nome: n.text,
                    lote: p.lote,
                    quantidade: parsedQtd,
                    valorCompra: parsedCusto,
                    markup: parsedMarkup,
                    valorVenda: parsedVenda,
                    origem: tipoSelecionado,
                  );

                  await DBHelper.instance.insertProduto(produtoAtualizado);

                  _onUpdate();
                  if (mounted) Navigator.pop(ctx);
                },
                child: const Text("Salvar"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Estoque Atual")),
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
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TelaDashboard()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Estoque Atual'),
              onTap: () {
                Navigator.pop(context);
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
      body: estoqueLocal.isEmpty
          ? const Center(child: Text("Estoque vazio."))
          : ListView.builder(
              itemCount: estoqueLocal.length,
              itemBuilder: (ctx, i) {
                final p = estoqueLocal[i];
                final lucroUnid = p.valorVenda - p.valorCompra;
                final isFabricado = p.origem.toLowerCase() == 'fabricado' || p.origem.toLowerCase() == 'produzido';
                final critico = p.quantidade <= 5;
                return Dismissible(
                  key: Key('${p.codigo}_$i'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) async {
                    await DBHelper.instance.deleteProduto(p.codigo);
                    _onUpdate();
                  },
                  background: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Card(
                    elevation: critico ? 6 : 3,
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: critico ? Colors.red.shade400 : Colors.transparent, width: 2),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: critico ? LinearGradient(colors: [Colors.red.shade50, Colors.white]) : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  if (critico) const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                                  if (critico) const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      p.nome,
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: critico ? Colors.red.shade900 : Colors.black87),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isFabricado ? Colors.purple.shade100 : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                p.origem,
                                style: TextStyle(color: isFabricado ? Colors.purple.shade900 : Colors.blue.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text("Qtd: ${p.quantidade}", style: p.quantidade <= 5 ? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold) : null),
                        Text("Custo: R\$ ${p.valorCompra.toStringAsFixed(2).replaceAll('.', ',')}"),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _edit(i), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                                const SizedBox(width: 16),
                              ],
                            ),
                            Text("Lucro Unid: R\$ ${lucroUnid.toStringAsFixed(2).replaceAll('.', ',')}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
    );
  }
}
