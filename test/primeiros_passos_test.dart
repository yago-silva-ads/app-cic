import 'package:app_cic/core/primeiros_passos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loja vazia tem todos os passos pendentes', () {
    final p = PrimeirosPassos(chavePix: '  ', codigosProdutos: [], vendas: 0);
    expect([p.pix, p.produtos, p.primeiraVenda, p.concluido], [false, false, false, false]);
  });

  test('exige três produtos distintos, não três unidades ou repetições', () {
    final p = PrimeirosPassos(chavePix: 'loja@exemplo.com', codigosProdutos: ['1', '1', '2', ''], vendas: 1);
    expect(p.pix, isTrue);
    expect(p.produtos, isFalse);
    expect(p.primeiraVenda, isTrue);
    expect(p.concluido, isFalse);
  });

  test('só conclui quando os três requisitos reais estão satisfeitos', () {
    for (var mascara = 0; mascara < 8; mascara++) {
      final pix = (mascara & 1) != 0;
      final produtos = (mascara & 2) != 0;
      final venda = (mascara & 4) != 0;
      final p = PrimeirosPassos(chavePix: pix ? 'chave' : '',
          codigosProdutos: produtos ? ['1', '2', '3'] : ['1', '2'], vendas: venda ? 1 : 0);
      expect(p.pix, pix);
      expect(p.produtos, produtos);
      expect(p.primeiraVenda, venda);
      expect(p.concluido, mascara == 7);
    }
  });
}
