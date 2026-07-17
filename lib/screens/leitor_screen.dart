import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/produto.dart';
import '../utils/moeda_formatter.dart';
import '../services/supabase_helper.dart';
import '../services/api_service.dart';
import 'tela_estoque.dart';
import 'tela_dashboard.dart';
import 'tela_vendedor.dart';
import 'tela_login.dart';
import '../widgets/app_drawer.dart';

class LeitorScreen extends StatefulWidget {
  const LeitorScreen({super.key});
  @override
  State<LeitorScreen> createState() => _LeitorScreenState();
}

class _LeitorScreenState extends State<LeitorScreen> {
  String codigoLido = 'A aguardar leitura...';
  bool buscando = false;
  bool _alertaMargem = false; // Controle do Limitador Anti-Falência

  final MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128, BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE, BarcodeFormat.code39, BarcodeFormat.code93, BarcodeFormat.codabar, BarcodeFormat.itf, BarcodeFormat.dataMatrix],
  );

  final TextEditingController codigoManualController = TextEditingController();
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController loteController = TextEditingController();
  final TextEditingController quantidadeController = TextEditingController();
  final TextEditingController valorCompraController = TextEditingController();

  final TextEditingController markupController = TextEditingController(
    text: '2.0',
  ); // Lucro de 100% por padrão
  final TextEditingController valorVendaController = TextEditingController();

  String tipoProdutoSelecionado = 'Revendido';

  List<Produto> bancoDeEstoque = [];

  DateTime? _dataValidadeSelecionada;

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
      setState(() {
        _alertaMargem = false;
      });
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
      double venda = custo * markup;
      valorVendaController.text = venda.toStringAsFixed(2).replaceAll('.', ',');

      // Ativa o alerta se a margem for menor que 1.3
      setState(() {
        _alertaMargem = markup < 1.3;
      });
    }
  }

  Future<void> _carregarDados() async {
    final produtos = await SupabaseHelper.getEstoque();
    setState(() {
      bancoDeEstoque = produtos;
    });
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

  Future<void> _selecionarDataValidade(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataValidadeSelecionada ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _dataValidadeSelecionada) {
      setState(() {
        _dataValidadeSelecionada = picked;
      });
    }
  }

  void salvar() async {
    if (nomeController.text.isEmpty || codigoLido == 'A aguardar leitura...') {
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

    if (qtd == null || valor == null || valorVenda == null || markup == null ||
        qtd <= 0 || valor <= 0 || markup <= 0 || valorVenda <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erro: Valores numéricos não podem estar vazios ou zerados!"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Confirmação Dupla Anti-Falência
    if (_alertaMargem) {
      bool confirmar =
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    "Preço Insuficiente!",
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
              content: const Text(
                "A margem de lucro definida pode não ser suficiente para cobrir seus custos fixos. Deseja salvar este produto mesmo assim?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text(
                    "Salvar mesmo assim",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmar) return; // Cancela o salvamento se o usuário não confirmar
    }

    Produto novoProduto = Produto(
      codigo: codigoLido,
      nome: nomeController.text,
      lote: loteController.text,
      quantidade: qtd,
      valorCompra: valor,
      markup: markup,
      valorVenda: valorVenda,
      origem:
          tipoProdutoSelecionado, // <-- Alterado de 'tipoProduto' para 'origem'
      dataValidade: _dataValidadeSelecionada,
      dataEntrada: DateTime.now(), // <-- Registro automático do momento da entrada
    );

    await SupabaseHelper.insertProduto(novoProduto);

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
      codigoManualController.clear();
      nomeController.clear();
      loteController.clear();
      quantidadeController.clear();
      valorCompraController.clear();
      markupController.text = '2.0';
      valorVendaController.clear();
      tipoProdutoSelecionado = 'Revendido';
      _alertaMargem = false;
      _dataValidadeSelecionada = null;
    });

    scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leitor CIC 2026')),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Card de Entrada Direta / Leitor USB / Digitação Rápida (Essencial no Web & Mobile)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade300, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: Color(0xFF0D47A1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: codigoManualController,
                      decoration: const InputDecoration(
                        hintText: 'Digite ou Bipe (Leitor USB) o EAN/GS1...',
                        border: InputBorder.none,
                        isDense: true,
                        hintStyle: TextStyle(fontSize: 13),
                      ),
                      keyboardType: TextInputType.text,
                      onSubmitted: (val) {
                        final code = val.trim();
                        if (code.isNotEmpty) {
                          setState(() => codigoLido = code);
                          scannerController.stop();
                          validarGS1(code);
                        }
                      },
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final code = codigoManualController.text.trim();
                      if (code.isNotEmpty) {
                        setState(() => codigoLido = code);
                        scannerController.stop();
                        validarGS1(code);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Consultar', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // Aviso explicativo de câmera para Versão Web / PC
            if (kIsWeb)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.black87),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Dica Web/PC: Use o campo acima com Leitor USB ou digite o código se a câmera do navegador estiver bloqueada.",
                        style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(
              height: 200,
              child: MobileScanner(
                controller: scannerController,
                onDetect: (cap) {
                  if (cap.barcodes.isEmpty) return;
                  final barcode = cap.barcodes.first;
                  final code = barcode.rawValue ?? "";

                  if (codigoLido == 'A aguardar leitura...') {
                    setState(() => codigoLido = code);
                    scannerController.stop();
                    
                    if (barcode.format == BarcodeFormat.qrCode) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Formato QR Code reconhecido com sucesso"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                    
                    validarGS1(code);
                  }
                },
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (kIsWeb)
                  TextButton.icon(
                    onPressed: () {
                      scannerController.start();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Solicitando acesso à câmera ao navegador..."),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.videocam, size: 16, color: Colors.blue),
                    label: const Text("Câmera Web", style: TextStyle(color: Colors.blue)),
                  )
                else
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
                    "Limpar",
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
                  DropdownButtonFormField<String>(
                    value: tipoProdutoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Produto',
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
                      setState(() {
                        tipoProdutoSelecionado = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: loteController,
                          decoration: const InputDecoration(labelText: 'Lote de Fabricação'),
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
                          decoration: const InputDecoration(
                            labelText: 'Quantidade em Estoque',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selecionarDataValidade(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Data de Validade',
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _dataValidadeSelecionada == null
                                        ? 'Selecionar'
                                        : '${_dataValidadeSelecionada!.day.toString().padLeft(2, '0')}/${_dataValidadeSelecionada!.month.toString().padLeft(2, '0')}/${_dataValidadeSelecionada!.year}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _dataValidadeSelecionada == null ? Theme.of(context).hintColor : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.calendar_month, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Data de Entrada',
                          ),
                          child: Text(
                            'Hoje (Automático)',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Bloco Financeiro do Cintra (Com Alerta de Margem)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _alertaMargem
                          ? Colors.red.withOpacity(0.05)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: _alertaMargem
                          ? Border.all(color: Colors.red, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Precificação",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _alertaMargem ? Colors.red : Colors.blue,
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
                                  labelText: 'Custo Unitário (R\$)',
                                  prefixText: 'R\$ ',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: markupController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: 'Margem de Lucro (Markup)',
                                  enabledBorder: _alertaMargem
                                      ? const UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_alertaMargem)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              "⚠️ Risco de Prejuízo: Margem muito baixa para cobrir custos fixos!",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: valorVendaController,
                          readOnly: true,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _alertaMargem ? Colors.red : Colors.green,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Preço de Venda Sugerido (R\$)',
                            prefixText: 'R\$ ',
                            filled: true,
                            fillColor: _alertaMargem
                                ? Colors.red.shade50
                                : Colors.white,
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
                      backgroundColor: _alertaMargem ? Colors.red : null,
                      foregroundColor: _alertaMargem ? Colors.white : null,
                    ),
                    child: Text(
                      _alertaMargem
                          ? "ATENÇÃO: Salvar com Risco"
                          : "Salvar no Banco de Dados",
                    ),
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
