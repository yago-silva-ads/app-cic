import 'package:app_cic/core/convite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Convite LeadForge', () {
    test('aceita slug da loja e limite de 80 caracteres', () {
      expect(validarConvite('mercadinho-bom-preco'), 'mercadinho-bom-preco');
      final limite = List.filled(80, 'a').join();
      expect(validarConvite(limite), limite);
    });

    test('ignora ausente, vazio, script e mais de 80 caracteres', () {
      for (final slug in [null, '', '<script>', List.filled(81, 'a').join()]) {
        expect(validarConvite(slug), isNull, reason: 'Slug: $slug');
      }
    });

    test('rejeita caracteres fora de a-z, 0-9 e hífen sem normalizar', () {
      for (final slug in ['Loja', 'loja_1', ' loja', 'loja ', 'café', 'loja\n', 'loja/1']) {
        expect(validarConvite(slug), isNull, reason: 'Slug: $slug');
      }
      expect(validarConvite('loja-123'), 'loja-123');
    });
  });
}
