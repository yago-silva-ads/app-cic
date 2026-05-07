// lib/web/web_camera_widget_web.dart
// Implementação para Flutter Web (usa dart:html)
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui' as ui; // ignore: avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';

typedef OnCodeDetected = void Function(String code);

class WebCameraWidget extends StatefulWidget {
  final double width;
  final double height;
  final OnCodeDetected? onCodeDetected;

  const WebCameraWidget({super.key, this.width = 640, this.height = 480, this.onCodeDetected});

  @override
  State<WebCameraWidget> createState() => _WebCameraWidgetState();
}

class _WebCameraWidgetState extends State<WebCameraWidget> {
  late html.VideoElement _video;
  late html.CanvasElement _canvas;
  late String _viewId;
  late String _canvasId;
  html.MediaStream? _stream;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _viewId = 'webcam-${DateTime.now().millisecondsSinceEpoch}';
    _canvasId = 'webcam-canvas-${DateTime.now().millisecondsSinceEpoch}';

    _video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..width = widget.width.toInt()
      ..height = widget.height.toInt();

    _canvas = html.CanvasElement(width: widget.width.toInt(), height: widget.height.toInt())
      ..id = _canvasId;

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final container = html.DivElement();
      container.append(_video);
      return container;
    });

    _startCamera();
  }

  Future<void> _startCamera() async {
    try {
      final constraints = {
        'video': {
          'facingMode': 'environment',
          'width': {'ideal': widget.width.toInt()},
          'height': {'ideal': widget.height.toInt()},
        }
      };
      _stream = await html.window.navigator.mediaDevices!.getUserMedia(constraints);
      _video.srcObject = _stream;
      _video.play();
      _startScanningLoop();
    } catch (e) {
      debugPrint('Erro ao iniciar câmera web: $e');
    }
  }

  void _startScanningLoop() {
    if (_scanning) return;
    _scanning = true;
    void tick(num _) {
      if (!_scanning) return;
      _captureToCanvas();
      final result = js.context.callMethod('decodeFromCanvas', [_canvasId]);
      if (result != null && result is String && result.isNotEmpty) {
        widget.onCodeDetected?.call(result);
      }
      html.window.requestAnimationFrame(tick);
    }

    html.window.requestAnimationFrame(tick);
  }

  void _captureToCanvas() {
    final ctx = _canvas.context2D;
    ctx.drawImageScaled(_video, 0, 0, _canvas.width!, _canvas.height!);
  }

  @override
  void dispose() {
    _scanning = false;
    if (_stream != null) {
      for (final t in _stream!.getTracks()) {
        t.stop();
      }
    }
    _video.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(width: widget.width, height: widget.height, child: HtmlElementView(viewType: _viewId)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capturar agora'),
              onPressed: () {
                _captureToCanvas();
                final result = js.context.callMethod('decodeFromCanvas', [_canvasId]);
                if (result != null && result is String && result.isNotEmpty) {
                  widget.onCodeDetected?.call(result);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum código detectado')));
                }
              },
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Parar câmera'),
              onPressed: () {
                _scanning = false;
                if (_stream != null) {
                  for (final t in _stream!.getTracks()) {
                    t.stop();
                  }
                }
                _video.srcObject = null;
              },
            ),
          ],
        ),
      ],
    );
  }
}
