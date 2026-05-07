import 'package:flutter/material.dart';

typedef OnCodeDetected = void Function(String code);

class WebCameraWidget extends StatelessWidget {
  final double width;
  final double height;
  final OnCodeDetected? onCodeDetected;

  const WebCameraWidget({super.key, this.width = 640, this.height = 480, this.onCodeDetected});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
