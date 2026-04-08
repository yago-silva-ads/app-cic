
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class Produto {
  final String codigo;
  final String nome;
  final String lote;
  final int quantidade;
  final double valorCompra;

  Produto({
    required this.codigo,
    required this.nome,
    required this.lote,
    required this.quantidade,
    required this.valorCompra,
  });

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'nome': nome,
        'lote': lote,
        'quantidade': quantidade,
        'valorCompra': valorCompra,
      };

  factory Produto.fromJson(Map<String, dynamic> json) => Produto(
        codigo: json['codigo'],
        nome: json['nome'],
        lote: json['lote'],
        quantidade: json['quantidade'],
        valorCompra: json['valorCompra'],
      );
}

class MoedaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String numbers = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numbers.isEmpty) numbers = '0';
    double value = double.parse(numbers) / 100;
    List<String> parts = value.toStringAsFixed(2).split('.');
    String intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[0]}.');
    String formatted = '$intPart,${parts[1]}';
    return TextEditingValue(
        text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leitor GS1 - CIC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true),
      home: const LeitorScreen(),
    );
  }
}

class LeitorScreen extends StatefulWidget {
  const LeitorScreen({super.key});
  @override
  State<LeitorScreen> createState() => _LeitorScreenState();
}

class _LeitorScreenState extends State<LeitorScreen> {
  String codigoLido = 'A aguardar leitura...';
  bool buscando = false;
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController loteController = TextEditingController();
  final TextEditingController quantidadeController = TextEditingController();
  final TextEditingController valorCompraController = TextEditingController();
  List<Produto> bancoDeEstoque = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final prefs = await SharedPreferences.getInstance();
    final String? estoqueJson = prefs.getString('estoque_cic');
    if (estoqueJson != null) {
      final List<dynamic> jsonList = jsonDecode(estoqueJson);
      setState(() {
        bancoDeEstoque = jsonList.map((item) => Produto.fromJson(item)).toList();
      });
    }
  }

  Future<void> _salvarDados() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(bancoDeEstoque.map((p) => p.toJson()).toList());
    await prefs.setString('estoque_cic', jsonString);
  }

  
  Future<void> buscarNaAPI(String codigo) async {
    setState(() {
      buscando = true;
      nomeController.text = "Consultando base de dados...";
    });
    try {
      final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$codigo.json');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1) {
          setState(() {
            nomeController.text = data['product']['product_name'] ?? data['product']['brands'] ?? "";
          });
        } else {
          setState(() => nomeController.text = "");
        }
      }
    } catch (e) {
      setState(() => nomeController.text = "");
    } finally {
      setState(() => buscando = false);
    }
  }

  void salvar() {
    if (nomeController.text.isEmpty || codigoLido == 'A aguardar leitura...') return;
    int? qtd = int.tryParse(quantidadeController.text);
    double? valor = double.tryParse(valorCompraController.text.replaceAll('.', '').replaceAll(',', '.'));
    if (qtd == null || valor == null) return;

    setState(() {
      bancoDeEstoque.add(Produto(codigo: codigoLido, nome: nomeController.text, lote: loteController.text, quantidade: qtd, valorCompra: valor));
      _limpar();
    });
    _salvarDados();
  }

  void _limpar() {
    codigoLido = 'A aguardar leitura...';
    nomeController.clear();
    loteController.clear();
    quantidadeController.clear();
    valorCompraController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leitor CIC 2026'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TelaEstoque(estoque: bancoDeEstoque, onUpdate: _salvarDados)))),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: MobileScanner(onDetect: (cap) {
                final code = cap.barcodes.first.rawValue ?? "";
                if (code != codigoLido) {
                  setState(() => codigoLido = code);
                  buscarNaAPI(code);
                }
              }),
            ),
            if (buscando) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text("Código Lido: $codigoLido", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome do Produto (Auto)')),
                  TextField(controller: loteController, decoration: const InputDecoration(labelText: 'Lote')),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: quantidadeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qtd'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: valorCompraController, inputFormatters: [MoedaFormatter()], decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: salvar, 
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: const Text("Salvar no Estoque")
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

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
          TextField(controller: q, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Qtd")),
          TextField(controller: v, inputFormatters: [MoedaFormatter()], decoration: const InputDecoration(labelText: "Valor")),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                widget.estoque[index] = Produto(
                  codigo: p.codigo,
                  nome: n.text,
                  lote: p.lote,
                  quantidade: int.parse(q.text),
                  valorCompra: double.parse(v.text.replaceAll('.', '').replaceAll(',', '.')));
              });
              widget.onUpdate();
              Navigator.pop(ctx);
            },
            child: const Text("Salvar"))
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
                onDismissed: (_) {
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
