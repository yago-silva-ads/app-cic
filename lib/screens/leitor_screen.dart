import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart' as xml;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';

import '../models/produto.dart';
import '../services/supabase_helper.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_text_field.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// LeitorScreen — Entrada de Produtos v2.0
///
/// Scanner Integrado, Digitação Rápida e Prevenção de Prejuízo
/// ═══════════════════════════════════════════════════════════════════════
class LeitorScreen extends StatefulWidget {
  final bool isEmbedded;
  const LeitorScreen({super.key, this.isEmbedded = false});

  @override
  State<LeitorScreen> createState() => _LeitorScreenState();
}

class _LeitorScreenState extends State<LeitorScreen> {
  String codigoLido = 'Aguardando leitura...';
  bool buscando = false;
  bool _alertaMargem = false;
  bool _salvando = false;

  final MobileScannerController scannerController = MobileScannerController(
    formats: const [BarcodeFormat.all],
  );

  final TextEditingController codigoManualController = TextEditingController();
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController loteController = TextEditingController();
  final TextEditingController quantidadeController = TextEditingController();
  final TextEditingController valorCompraController = TextEditingController();
  final TextEditingController markupController = TextEditingController(text: '2.0');
  final TextEditingController valorVendaController = TextEditingController();

  String tipoProdutoSelecionado = 'Revendido';
  DateTime? _dataValidadeSelecionada;

  @override
  void initState() {
    super.initState();
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
      setState(() => _alertaMargem = false);
      return;
    }

    String valorTexto = valorCompraController.text.replaceAll('.', '').replaceAll(',', '.');
    double? custo = double.tryParse(valorTexto);
    double? markup = double.tryParse(markupController.text.replaceAll(',', '.'));

    if (custo != null && markup != null) {
      double venda = custo * markup;
      valorVendaController.text = venda.toStringAsFixed(2).replaceAll('.', ',');
      setState(() => _alertaMargem = markup < 1.3);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text("Produto não encontrado. Digite o nome."), backgroundColor: AppColors.warning),
        );
      }
    });
  }

  Future<void> _selecionarDataValidade(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataValidadeSelecionada ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.goldForBrightness(Theme.of(context).brightness),
              onPrimary: Colors.white,
              surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              onSurface: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dataValidadeSelecionada = picked);
    }
  }

  void salvar() async {
    if (_salvando) return;

    String codigoFinal = codigoLido;
    if (codigoFinal == 'Aguardando leitura...' && codigoManualController.text.trim().isNotEmpty) {
      codigoFinal = codigoManualController.text.trim();
    }

    if (codigoFinal == 'Aguardando leitura...' || codigoFinal.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("Bipe ou digite o código de barras!"), backgroundColor: AppColors.warning),
      );
      return;
    }

    if (nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("Preencha o Nome do Produto!"), backgroundColor: AppColors.warning),
      );
      return;
    }

    double? parseDoubleLocal(String text) {
      String limpo = text.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.');
      return double.tryParse(limpo);
    }

    int? qtd = int.tryParse(quantidadeController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    double? valor = parseDoubleLocal(valorCompraController.text);
    double? markup = parseDoubleLocal(markupController.text);
    double? valorVenda = parseDoubleLocal(valorVendaController.text);

    if (qtd == null || valor == null || valorVenda == null || markup == null || qtd <= 0 || valor <= 0 || markup <= 0 || valorVenda <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("Quantidades e valores devem ser maiores que zero!"), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_alertaMargem) {
      bool confirmar = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text("Preço Insuficiente!", style: TextStyle(color: AppColors.error)),
            ],
          ),
          content: const Text("A margem de lucro definida pode não ser suficiente para cobrir seus custos fixos. Salvar mesmo assim?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              child: const Text("Salvar mesmo assim"),
            ),
          ],
        ),
      ) ?? false;

      if (!confirmar) return;
    }

    setState(() => _salvando = true);

    try {
      Produto novoProduto = Produto(
        codigo: codigoFinal,
        nome: nomeController.text.trim(),
        lote: loteController.text.trim().isEmpty ? 'S/L' : loteController.text.trim(),
        quantidade: qtd,
        valorCompra: valor,
        markup: markup,
        valorVenda: valorVenda,
        origem: tipoProdutoSelecionado,
        dataValidade: _dataValidadeSelecionada,
        dataEntrada: DateTime.now(),
      );

      await SupabaseHelper.insertProduto(novoProduto);
      _limpar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("Produto salvo com sucesso!"), backgroundColor: AppColors.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Falha ao salvar: $e"), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _limpar() {
    setState(() {
      codigoLido = 'Aguardando leitura...';
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

  Future<void> _importarXML() async {
    try {
      var result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['xml']);
      if (result != null && result.isNotEmpty) {
        String xmlString;
        if (kIsWeb) {
          // No web support fallback without bytes?
          xmlString = '';
        } else {
          xmlString = await File(result.first.path!).readAsString();
        }

        final document = xml.XmlDocument.parse(xmlString);
        final dets = document.findAllElements('det');
        if (dets.isNotEmpty) {
          final prod = dets.first.findElements('prod').first;
          final cEAN = prod.findElements('cEAN').isEmpty ? '' : prod.findElements('cEAN').first.innerText;
          final xProd = prod.findElements('xProd').isEmpty ? '' : prod.findElements('xProd').first.innerText;
          final vUnCom = prod.findElements('vUnCom').isEmpty ? '' : prod.findElements('vUnCom').first.innerText;

          setState(() {
            if (cEAN.isNotEmpty && cEAN != 'SEM GTIN') {
              codigoLido = cEAN;
              codigoManualController.text = cEAN;
            }
            nomeController.text = xProd;
            if (vUnCom.isNotEmpty) {
              double custo = double.parse(vUnCom);
              valorCompraController.text = custo.toStringAsFixed(2).replaceAll('.', ',');
              _calcularVendaEmTempoReal();
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text("XML importado!"), backgroundColor: AppColors.success),
          );
        } else {
          throw Exception("Nenhum produto encontrado no XML.");
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro XML: $e"), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = AppColors.goldForBrightness(Theme.of(context).brightness);
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final contentBody = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barcode / Scanner area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        MobileScanner(
                          controller: scannerController,
                          onDetect: (cap) {
                            if (cap.barcodes.isNotEmpty) {
                              final code = cap.barcodes.first.rawValue ?? "";
                              if (codigoLido == 'Aguardando leitura...') {
                                setState(() => codigoLido = code);
                                scannerController.stop();
                                _consultarService(code);
                              }
                            }
                          },
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: gold.withValues(alpha: 0.5), width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: codigoManualController,
                        hint: 'Digite ou Bipe o EAN',
                        prefixIcon: Icons.qr_code,
                        onFieldSubmitted: (val) {
                          if (val.isNotEmpty) {
                            setState(() => codigoLido = val);
                            scannerController.stop();
                            _consultarService(val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _importarXML,
                      icon: const Icon(Icons.receipt_long),
                      style: IconButton.styleFrom(
                        backgroundColor: gold.withValues(alpha: 0.1),
                        foregroundColor: gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Código Lido: $codigoLido",
                  style: TextStyle(fontWeight: FontWeight.bold, color: gold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Formulário
          CustomTextField(
            controller: nomeController,
            label: 'Nome do Produto',
            hint: 'Ex: Fone de Ouvido Bluetooth',
            prefixIcon: Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: tipoProdutoSelecionado,
            decoration: InputDecoration(
              labelText: 'Tipo de Produto',
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderCol)),
            ),
            dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            items: const [
              DropdownMenuItem(value: 'Revendido', child: Text('Revendido')),
              DropdownMenuItem(value: 'Fabricado', child: Text('Fabricado')),
            ],
            onChanged: (val) => setState(() => tipoProdutoSelecionado = val!),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: quantidadeController,
                  label: 'Qtd.',
                  hint: '0',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  controller: loteController,
                  label: 'Lote',
                  hint: 'S/L',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          InkWell(
            onTap: () => _selecionarDataValidade(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderCol),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dataValidadeSelecionada == null
                        ? 'Selecionar Validade'
                        : 'Validade: ${DateFormat('dd/MM/yyyy').format(_dataValidadeSelecionada!)}',
                    style: TextStyle(
                      color: _dataValidadeSelecionada == null 
                          ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                          : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                  ),
                  const Icon(Icons.calendar_month, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Precificação e Margem (Anti-falência)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _alertaMargem ? AppColors.errorBgDark : cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _alertaMargem ? AppColors.error : borderCol,
                width: _alertaMargem ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.monetization_on_outlined, color: _alertaMargem ? AppColors.error : gold),
                    const SizedBox(width: 8),
                    Text(
                      "Precificação",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _alertaMargem ? AppColors.error : gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: valorCompraController,
                        label: 'Custo (R\$)',
                        hint: '0,00',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: markupController,
                        label: 'Markup',
                        hint: '2.0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: valorVendaController,
                  label: 'Preço Venda (R\$)',
                  hint: '0,00',
                  readOnly: true,
                ),
                if (_alertaMargem)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Risco de Prejuízo! Margem muito baixa.",
                            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _salvando ? null : salvar,
            style: ElevatedButton.styleFrom(
              backgroundColor: _alertaMargem ? AppColors.error : gold,
              foregroundColor: _alertaMargem ? Colors.white : AppColors.darkBackground,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _salvando
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    _alertaMargem ? "ATENÇÃO: Salvar com Risco" : "Salvar Produto",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return contentBody;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Entrada de Produto')),
      body: contentBody,
    );
  }
}
