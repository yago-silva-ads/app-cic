/// PIX "Copia e Cola" (BR Code / EMVCo) conforme o Manual do Bacen.
/// Porte fiel de `services/pix.ts`.
library;

String _normalizar(String texto, int max) {
  const de = 'ÁÀÂÃÄáàâãäÉÈÊËéèêëÍÌÎÏíìîïÓÒÔÕÖóòôõöÚÙÛÜúùûüÇçÑñ';
  const para = 'AAAAAaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNn';
  final sb = StringBuffer();
  for (final r in texto.runes) {
    final ch = String.fromCharCode(r);
    final i = de.indexOf(ch);
    sb.write(i >= 0 ? para[i] : ch);
  }
  final limpo = sb.toString().replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
  return limpo.length > max ? limpo.substring(0, max) : limpo;
}

String _campo(String id, String valor) => '$id${valor.length.toString().padLeft(2, '0')}$valor';

String _crc16(String payload) {
  var crc = 0xFFFF;
  for (final u in payload.codeUnits) {
    crc ^= u << 8;
    for (var j = 0; j < 8; j++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}

String gerarPayloadPix({
  required String chave,
  required String nomeRecebedor,
  required String cidadeRecebedor,
  required double valor,
  String identificador = '***',
}) {
  final nome = _normalizar(nomeRecebedor.isEmpty ? 'RECEBEDOR' : nomeRecebedor, 25);
  final cidade = _normalizar(cidadeRecebedor.isEmpty ? 'BRASIL' : cidadeRecebedor, 15);
  final txidBruto = _normalizar(identificador.isEmpty ? '***' : identificador, 25);
  final txid = txidBruto.isEmpty ? '***' : txidBruto;

  final conta = _campo('26', _campo('00', 'br.gov.bcb.pix') + _campo('01', chave.trim()));
  final extra = _campo('62', _campo('05', txid));

  final raw = StringBuffer()
    ..write(_campo('00', '01'))
    ..write(conta)
    ..write(_campo('52', '0000'))
    ..write(_campo('53', '986'));
  if (valor > 0) raw.write(_campo('54', valor.toStringAsFixed(2)));
  raw
    ..write(_campo('58', 'BR'))
    ..write(_campo('59', nome))
    ..write(_campo('60', cidade))
    ..write(extra)
    ..write('6304');
  final corpo = raw.toString();
  return '$corpo${_crc16(corpo)}';
}
