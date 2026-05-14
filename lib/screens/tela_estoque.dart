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
    String tipoSelecionado = p.tipoProduto;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        // <-- Isso permite atualizar a caixinha em tempo real!
        builder: (context, setStateModal) {
          // Função que recalcula a Venda na hora que digita o Custo ou Markup
          void recalcularVenda() {
            double? c = double.tryParse(
              custoCtrl.text.replaceAll('.', '').replaceAll(',', '.'),
            );
            double? m = double.tryParse(markupCtrl.text.replaceAll(',', '.'));
            if (c != null && m != null) {
              setStateModal(() {
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
                    decoration: const InputDecoration(labelText: "Nome"),
                  ),
                  TextField(
                    controller: q,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Quantidade"),
                  ),
                  TextField(
                    controller: custoCtrl,
                    inputFormatters: [MoedaFormatter()],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Custo"),
                    onChanged: (_) =>
                        recalcularVenda(), // Chama o cálculo ao digitar
                  ),
                  TextField(
                    controller: markupCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Margem (Ex: 2.0)",
                    ),
                    onChanged: (_) =>
                        recalcularVenda(), 
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: tipoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Produto',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'revendido',
                        child: Text('Revendido'),
                      ),
                      DropdownMenuItem(
                        value: 'produzido',
                        child: Text('Produzido'),
                      ),
                    ],
                    onChanged: (value) {
                      setStateModal(() {
                        tipoSelecionado = value!;
                      });
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
                      labelText: "Sugestão de Venda",
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
                  Produto produtoAtualizado = Produto(
                    codigo: p.codigo,
                    nome: n.text,
                    lote: p.lote,
                    quantidade: int.parse(q.text),
                    valorCompra: double.parse(
                      custoCtrl.text.replaceAll('.', '').replaceAll(',', '.'),
                    ),
                    markup: double.parse(markupCtrl.text.replaceAll(',', '.')),
                    valorVenda: double.parse(
                      vendaCtrl.text.replaceAll('.', '').replaceAll(',', '.'),
                    ),
                    tipoProduto: tipoSelecionado,
                  );

                  await DBHelper.instance.insertProduto(produtoAtualizado);

                  setState(() {
                    estoqueLocal[index] = produtoAtualizado;
                  });

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
      appBar: AppBar(
        title: const Text("Estoque Atual"),
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
                decoration: const BoxDecoration(
                  color: Color(0xFF1565C0),
                ),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TelaDashboard()),
                );
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TelaVendedor()),
                );
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
                return Dismissible(
                  key: Key(p.codigo + i.toString()),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) async {
                    // Apaga do banco SQLite
                    await DBHelper.instance.deleteProduto(p.codigo);

                    // Remove da tela
                    setState(() => estoqueLocal.removeAt(i));
                    _onUpdate();
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2),
                    title: Text(p.nome),

                    subtitle: Text(
                      "Tipo: ${p.tipoProduto == 'revendido' ? 'Revendido' : 'Produzido'} | Qtd: ${p.quantidade} | Custo: R\$ ${p.valorCompra.toStringAsFixed(2).replaceAll('.', ',')} | Venda: R\$ ${p.valorVenda.toStringAsFixed(2).replaceAll('.', ',')}",
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _edit(i),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
