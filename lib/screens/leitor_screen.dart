import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/produto.dart';
import '../utils/moeda_formatter.dart';
import '../services/db_helper.dart';
import '../services/api_service.dart';
import 'tela_estoque.dart';

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

  // Busca do SQLite
  Future<void> _carregarDados() async {
    final produtos = await DBHelper.instance.getEstoque();
    setState(() {
      bancoDeEstoque = produtos;
    });
  }

  // A função vazia para não quebrar o "onUpdate" da TelaEstoque
  void _atualizarTela() {
    _carregarDados();
  }

  // A lógica do Professor Sérgio continua aqui, blindada!
  Future<void> validarGS1(String code) async {
    if (code == "7891721201806") {
      setState(() {
        nomeController.text = "GLIFAGE XR 500MG TAB RM (30)";
      });
    } else {
      await _consultarService(code);
    }
  }

  // Função limpa usando o ApiService isolado
  Future<void> _consultarService(String codigo) async {
    setState(() {
      buscando = true;
      nomeController.text = "Consultando nuvem...";
    });

    // Chama o arquivo isolado que criamos!
    String? nomeEncontrado = await ApiService.buscarProdutoExterno(codigo);

    setState(() {
      buscando = false;
      if (nomeEncontrado != null) {
        nomeController.text = nomeEncontrado;
      } else {
        nomeController.text = ""; // Limpa para você digitar na mão
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Produto não encontrado na API. Digite o nome."), backgroundColor: Colors.orange)
          );
        }
      }
    });
  }

  void salvar() async {
    if (nomeController.text.isEmpty || codigoLido == 'A aguardar leitura...') return;
    
    int? qtd = int.tryParse(quantidadeController.text);
    String valorTexto = valorCompraController.text.replaceAll('.', '').replaceAll(',', '.');
    double? valor = double.tryParse(valorTexto);

    if (qtd == null || valor == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro: Verifique a quantidade e o valor!"), backgroundColor: Colors.red)
        );
      }
      return;
    }

    // Cria o produto
    Produto novoProduto = Produto(
      codigo: codigoLido, 
      nome: nomeController.text, 
      lote: loteController.text, 
      quantidade: qtd, 
      valorCompra: valor
    );

    // Salva no SQLite
    await DBHelper.instance.insertProduto(novoProduto);

    // Atualiza a tela
    _carregarDados();
    _limpar();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Produto salvo no Banco de Dados!"), backgroundColor: Colors.green)
      );
    }
  }

  void _limpar() {
    setState(() {
      codigoLido = 'A aguardar leitura...';
      nomeController.clear();
      loteController.clear();
      quantidadeController.clear();
      valorCompraController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leitor CIC 2026'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TelaEstoque(estoque: bancoDeEstoque, onUpdate: _atualizarTela)))
          ),
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
                  validarGS1(code);
                }
              }),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() => codigoLido = "7891721201806");
                validarGS1("7891721201806");
              },
              icon: const Icon(Icons.bolt, size: 16),
              label: const Text("Simular Leitura GS1"),
            ),
            if (buscando) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text("Código Lido: $codigoLido", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome do Produto (Auto)')),
                  const SizedBox(height: 10),
                  TextField(controller: loteController, decoration: const InputDecoration(labelText: 'Lote')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quantidadeController, 
                          keyboardType: TextInputType.number, 
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: 'Qtd')
                        )
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: valorCompraController, 
                          inputFormatters: [MoedaFormatter()], 
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ ')
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: salvar, 
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: const Text("Salvar no Banco de Dados")
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