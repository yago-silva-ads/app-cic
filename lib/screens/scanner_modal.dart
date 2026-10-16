import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/gs1.dart';
import '../core/theme.dart';
import '../ui/widgets.dart';
import 'leitor_web_stub.dart' if (dart.library.js_interop) 'leitor_web_js.dart';

/// Abre a câmera para ler código de barras / QR. Devolve o código lido ou
/// null se cancelado. Sempre oferece digitação manual (iPhone sem permissão de
/// câmera, etiqueta rasgada, leitor USB que "digita" o código).
///
/// Na Web (iPhone/Safari) usa o leitor de `web/scanner.js`: resolução alta,
/// zoom, foco contínuo e "Foto do código" pela câmera nativa (macro).
Future<String?> abrirScanner(BuildContext context) async {
  if (kIsWeb && leitorWebDisponivel) {
    final r = await abrirLeitorWeb();
    if (r != '__DIGITAR__') return r;
    if (!context.mounted) return null;
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _ScannerPage(somenteDigitar: true),
      ),
    );
  }
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _ScannerPage(),
    ),
  );
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage({this.somenteDigitar = false});
  final bool somenteDigitar;

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  final _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    // Resolução alta: códigos pequenos legíveis sem encostar o celular.
    cameraResolution: const Size(1920, 1080),
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.itf,
      BarcodeFormat.qrCode,
    ],
  );
  final _manual = TextEditingController();
  bool _resolvido = false;
  String? _aviso;
  String? _ultimoRejeitado;

  @override
  void dispose() {
    _ctrl.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _aceitar(String codigo) {
    if (_resolvido) return;
    _resolvido = true;
    Navigator.of(context).pop(codigo);
  }

  void _lido(BarcodeCapture cap) {
    for (final b in cap.barcodes) {
      final raw = (b.rawValue ?? '').trim();
      if (raw.isEmpty) continue;
      final numerico = RegExp(r'^\d+$').hasMatch(raw);
      // Código numérico de comprimento GTIN com dígito verificador errado = má leitura.
      if (numerico &&
          [8, 12, 13, 14].contains(raw.length) &&
          !gtinValido(raw)) {
        if (_ultimoRejeitado != raw) {
          _ultimoRejeitado = raw;
          setState(
            () =>
                _aviso = 'Leitura inválida ($raw). Aproxime e firme o código.',
          );
        }
        continue;
      }
      _aceitar(raw);
      return;
    }
  }

  /// Lê o código de uma foto (útil para códigos pequenos ou com pouca luz).
  Future<void> _lerFoto() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.image);
      final caminho = r?.files.single.path;
      if (caminho == null) return;
      final achou = await _ctrl.analyzeImage(caminho);
      if (!achou && mounted) {
        setState(
          () => _aviso =
              'Não achei código na foto. Enquadre só o código, com boa luz.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _aviso = 'Não foi possível ler a foto.');
    }
  }

  void _confirmarManual() {
    final t = _manual.text.trim();
    if (t.isEmpty) {
      setState(() => _aviso = 'Digite o código de barras.');
      return;
    }
    if (RegExp(r'^\d+$').hasMatch(t) &&
        [8, 12, 13, 14].contains(t.length) &&
        !gtinValido(t)) {
      setState(
        () => _aviso =
            'O dígito verificador desse código não confere. Confira a digitação.',
      );
      return;
    }
    _aceitar(t);
  }

  @override
  Widget build(BuildContext context) {
    // Tema escuro fixo: a câmera ocupa a tela.
    final c = CicPalette.escuro;
    return Theme(
      data: construirTema(c),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text(
            'Bipar código de barras',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          actions: widget.somenteDigitar
              ? null
              : [
                  IconButton(
                    tooltip: 'Ler de uma foto',
                    onPressed: _lerFoto,
                    icon: const Icon(LucideIcons.image, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Lanterna',
                    onPressed: () => _ctrl.toggleTorch(),
                    icon: const Icon(LucideIcons.flashlight, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Trocar câmera',
                    onPressed: () => _ctrl.switchCamera(),
                    icon: const Icon(LucideIcons.switchCamera, size: 20),
                  ),
                ],
        ),
        body: Column(
          children: [
            if (widget.somenteDigitar)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _aviso ??
                          'Digite os números que aparecem embaixo do código de barras.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _aviso == null
                            ? Colors.white70
                            : const Color(0xFFFBBF24),
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _ctrl,
                      onDetect: _lido,
                      errorBuilder: (context, erro, _) => Container(
                        color: const Color(0xFF111111),
                        padding: const EdgeInsets.all(24),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.cameraOff,
                                color: Colors.white54,
                                size: 42,
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Não foi possível usar a câmera',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Permita o acesso à câmera nas configurações do navegador (no iPhone: Ajustes > Safari > Câmera) ou digite o código abaixo.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 280,
                          height: 160,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFD4A843),
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      child: Text(
                        _aviso ?? 'Aponte para o código de barras',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _aviso == null
                              ? Colors.white70
                              : const Color(0xFFFBBF24),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              color: const Color(0xFF111111),
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                14 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CicCampo(
                      controller: _manual,
                      dica: 'Ou digite o código de barras',
                      teclado: TextInputType.number,
                      onSubmitted: (_) => _confirmarManual(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CicBotao('Usar', onPressed: _confirmarManual),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
