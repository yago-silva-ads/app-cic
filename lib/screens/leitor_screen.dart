import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/produto.dart';
import '../utils/moeda_formatter.dart';
import '../services/db_helper.dart';
import '../services/api_service.dart';
import 'tela_estoque.dart';
import 'tela_dashboard.dart';

class LeitorScreen extends StatefulWidget {
  const LeitorScreen({super.key});
  @override
  State<LeitorScreen> createState() => _LeitorScreenState();
}

class _LeitorScreenState extends State<LeitorScreen> {
  String codigoLido = 'A aguardar leitura...';
  bool buscando = false;

  final MobileScannerController scannerController = MobileScannerController();

  final TextEditingController nomeController = TextEditingController();
  final TextEditingController loteController = TextEditingController();
  final TextEditingController quantidadeController = TextEditingController();
  final TextEditingController valorCompraController = TextEditingController();

  final TextEditingController markupController = TextEditingController(
    text: '2.0',
  ); // Lucro de 100% por padrão
  final TextEditingController valorVendaController = TextEditingController();

  String origemSelecionada = 'Revendido';
  bool margemSegura = true;

  List<Produto> bancoDeEstoque = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();

    valorCompraController.addListener(_calcularVendaEmTempoReal);
    markupController.addListener(_calcularVendaEmTempoReal);
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  void _calcularVendaEmTempoReal() {
    if (valorCompraController.text.isEmpty || markupController.text.isEmpty) {
      valorVendaController.clear();
      setState(() => margemSegura = true);
      return;
    }

    String valorTexto = valorCompraController.text
        .replaceAll('.', '')
        .replaceAll(',', '.');
    double? custo = double.tryParse(valorTexto);
    double? markup = double.tryParse(
      markupController.text.replaceAll(',', '.'),
    );

    if (custo != null && markup != null) {
      bool ehSegura = markup >= 1.3;
      if (ehSegura != margemSegura) {
        setState(() => margemSegura = ehSegura);
      }

      double venda = custo * markup;
      valorVendaController.text = venda.toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  Future<void> _carregarDados() async {
    final produtos = await DBHelper.instance.getEstoque();
    setState(() {
      bancoDeEstoque = produtos;
    });
  }

  void _atualizarTela() {
    _carregarDados();
  }

  Future<void> validarGS1(String code) async {
    if (code == "7891721201806") {
      setState(() {
        nomeController.text = "GLIFAGE XR 500MG TAB RM (30)";
      });
    } else {
      await _consultarService(code);
    }
  }

  Future<void> _consultarService(String codigo) async {
    setState(() {
      buscando = true;
      nomeController.text = "Consultando nuvem...";
    });

    String? nomeEncontrado = await ApiService.buscarProdutoExterno(codigo);

    setState(() {
      buscando = false;
      if (nomeEncontrado != null) {
        nomeController.text = nomeEncontrado;
      } else {
        nomeController.text = "";
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Produto não encontrado. Digite o nome."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
  }

  void salvar() async {
    if (nomeController.text.isEmpty || codigoLido == 'A aguardar leitura...') {
      return;
    }

    if (!margemSegura) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ação Bloqueada: Corrija a margem de lucro antes de salvar!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int? qtd = int.tryParse(quantidadeController.text);
    String valorTexto = valorCompraController.text
        .replaceAll('.', '')
        .replaceAll(',', '.');
    double? valor = double.tryParse(valorTexto);

    double? markup = double.tryParse(
      markupController.text.replaceAll(',', '.'),
    );

    double? valorVenda = double.tryParse(
      valorVendaController.text.replaceAll('.', '').replaceAll(',', '.'),
    );

    if (qtd == null || valor == null || valorVenda == null || markup == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erro: Verifique a quantidade e os valores!"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    Produto novoProduto = Produto(
      codigo: codigoLido,
      nome: nomeController.text,
      lote: loteController.text,
      quantidade: qtd,
      valorCompra: valor,
      markup: markup,
      valorVenda: valorVenda,
      origem: origemSelecionada,
    );

    await DBHelper.instance.insertProduto(novoProduto);

    _carregarDados();
    _limpar();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Produto salvo com sucesso!"),
          backgroundColor: Colors.green,
        ),
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
      markupController.text = '2.0';
      valorVendaController.clear();
      origemSelecionada = 'Revendido';
    });

    scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leitor CIC 2026'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TelaDashboard()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TelaEstoque(
                  estoque: bancoDeEstoque,
                  onUpdate: _atualizarTela,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: MobileScanner(
                controller: scannerController,
                onDetect: (cap) {
                  final code = cap.barcodes.first.rawValue ?? "";

                  if (codigoLido == 'A aguardar leitura...') {
                    setState(() => codigoLido = code);
                    scannerController.stop();
                    validarGS1(code);
                  }
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 👇 BOTÃO DO FLASH ADICIONADO AQUI!
                IconButton(
                  onPressed: () => scannerController.toggleTorch(),
                  icon: const Icon(Icons.flashlight_on, color: Colors.amber),
                  tooltip: 'Ligar/Desligar Flash',
                ),

                TextButton.icon(
                  onPressed: () {
                    setState(() => codigoLido = "7891721201806");
                    scannerController.stop();
                    validarGS1("7891721201806");
                  },
                  icon: const Icon(Icons.bolt, size: 16),
                  label: const Text("Simular"),
                ),
                TextButton.icon(
                  onPressed: _limpar,
                  icon: const Icon(Icons.refresh, size: 16, color: Colors.red),
                  label: const Text(
                    "Limpar Câmera",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),

            if (buscando) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    "Código Lido: $codigoLido",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Produto',
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: loteController,
                          decoration: const InputDecoration(labelText: 'Lote'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: quantidadeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(labelText: 'Qtd'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Seletor de Origem
                  const Text(
                    "Origem do Produto:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Radio<String>(
                        value: 'Revendido',
                        groupValue: origemSelecionada,
                        onChanged: (val) => setState(() => origemSelecionada = val!),
                      ),
                      const Text('Revendido'),
                      const SizedBox(width: 20),
                      Radio<String>(
                        value: 'Fabricado',
                        groupValue: origemSelecionada,
                        onChanged: (val) => setState(() => origemSelecionada = val!),
                      ),
                      const Text('Fabricado'),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Bloco Financeiro do Cintra
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Precificação (Cintra)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: valorCompraController,
                                inputFormatters: [MoedaFormatter()],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Custo de Estoque',
                                  prefixText: 'R\$ ',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: markupController,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Margem de Lucro',
                                  errorText: null, // Será sobrescrito abaixo
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (!margemSegura)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text('⚠️ Risco de Prejuízo: Margem muito baixa!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        TextField(
                          controller: valorVendaController,
                          readOnly: true,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Faturamento Projetado (Unidade)',
                            prefixText: 'R\$ ',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: salvar,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text("Salvar no Banco de Dados"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
