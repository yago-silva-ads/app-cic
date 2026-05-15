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
                    decoration: InputDecoration(
                      labelText: "Markup (Ex: 2.0)",
                      errorText: margemSeguraModal ? null : '⚠️ Margem muito baixa!',
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
                  if (!margemSeguraModal) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Ação Bloqueada: Corrija a margem de lucro!"),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

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
                    origem: p.origem,
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
                final lucroUnid = p.valorVenda - p.valorCompra;
                final isFabricado = p.origem == 'Fabricado';

                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                p.nome,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  constraints: const BoxConstraints(), padding: EdgeInsets.zero,
                                  onPressed: () async {
                                    await DBHelper.instance.deleteProduto(p.codigo);
                                    setState(() => widget.estoque.removeAt(i));
                                    widget.onUpdate();
                                  },
                                ),
                              ],
                            ),
                            Text("Lucro Unid: R\$ ${lucroUnid.toStringAsFixed(2).replaceAll('.', ',')}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
