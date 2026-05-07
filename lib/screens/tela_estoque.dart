import 'package:flutter/material.dart';
import '../models/produto.dart';
import '../utils/moeda_formatter.dart';
import '../services/db_helper.dart';

class TelaEstoque extends StatefulWidget {
  final List<Produto> estoque;
  final VoidCallback onUpdate;
  const TelaEstoque({super.key, required this.estoque, required this.onUpdate});

  @override
  State<TelaEstoque> createState() => _TelaEstoqueState();
}

class _TelaEstoqueState extends State<TelaEstoque> {
  void _edit(int index) {
    Produto p = widget.estoque[index];
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
                    decoration: const InputDecoration(labelText: "Qtd"),
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
                      labelText: "Markup (Ex: 2.0)",
                    ),
                    onChanged: (_) =>
                        recalcularVenda(), 
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
                  );

                  await DBHelper.instance.insertProduto(produtoAtualizado);

                  setState(() {
                    widget.estoque[index] = produtoAtualizado;
                  });

                  widget.onUpdate();
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
      body: widget.estoque.isEmpty
          ? const Center(child: Text("Estoque vazio."))
          : ListView.builder(
              itemCount: widget.estoque.length,
              itemBuilder: (ctx, i) {
                final p = widget.estoque[i];
                return Dismissible(
                  key: Key(p.codigo + i.toString()),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) async {
                    // Apaga do banco SQLite
                    await DBHelper.instance.deleteProduto(p.codigo);

                    // Remove da tela
                    setState(() => widget.estoque.removeAt(i));
                    widget.onUpdate();
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
                      "Qtd: ${p.quantidade} | Custo: R\$ ${p.valorCompra.toStringAsFixed(2).replaceAll('.', ',')} | Venda: R\$ ${p.valorVenda.toStringAsFixed(2).replaceAll('.', ',')}",
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
