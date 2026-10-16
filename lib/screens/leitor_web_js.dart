import 'dart:js_interop';

@JS('cicScanner.abrir')
external JSPromise<JSString?> _abrir();

/// Abre o leitor web (web/scanner.js). Retorna o código, `__DIGITAR__` ou null.
Future<String?> abrirLeitorWeb() async {
  try {
    final r = await _abrir().toDart;
    return r?.toDart;
  } catch (_) {
    return null;
  }
}

bool get leitorWebDisponivel => true;
