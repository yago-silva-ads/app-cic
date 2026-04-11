import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    TextEditingController q = TextEditingController(text: p.quantidade.toString());
    TextEditingController v = TextEditingController(text: p.valorCompra.toStringAsFixed(2).replaceAll('.', ','));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Editar Produto"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: n, decoration: const InputDecoration(labelText: "Nome")),
          TextField(
            controller: q, 
            keyboardType: TextInputType.number, 
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: "Qtd")
          ),
          TextField(
            controller: v, 
            inputFormatters: [MoedaFormatter()], 
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Valor")
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              // 1. Atualiza o objeto com os novos valores
              Produto produtoAtualizado = Produto(
                codigo: p.codigo,
                nome: n.text,
                lote: p.lote,
                quantidade: int.parse(q.text),
                valorCompra: double.parse(v.text.replaceAll('.', '').replaceAll(',', '.'))
              );

              // 2. Salva no banco de dados SQLite
              await DBHelper.instance.insertProduto(produtoAtualizado);
              
              // 3. Atualiza a lista da tela
              setState(() {
                widget.estoque[index] = produtoAtualizado;
              });
              
              widget.onUpdate();
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("Salvar")
          )
        ],
      ));
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
                background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                child: ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: Text(p.nome),
                  subtitle: Text("Qtd: ${p.quantidade} | R\$ ${p.valorCompra.toStringAsFixed(2).replaceAll('.', ',')}"),
                  trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _edit(i)),
                ),
              );
            },
          ),
    );
  }
}