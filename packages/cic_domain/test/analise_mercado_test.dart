import 'package:cic_domain/cic_domain.dart';
import 'package:test/test.dart';

void main() {
  const ofertas = [
    OfertaMercado(precoCentavos: 1000, fonte: 'A', url: 'https://a'),
    OfertaMercado(precoCentavos: 1200, fonte: 'B', url: 'https://b'),
    OfertaMercado(precoCentavos: 1300, fonte: 'C', url: 'https://c'),
  ];

  test('recomenda aumentar quando a loja está muito abaixo do mercado', () {
    final r = analisarMercado(precoAtualCentavos: 800, custoCentavos: 500, ofertas: ofertas);
    expect(r.acao, AcaoPrecoMercado.aumentar);
    expect(r.precoSugeridoCentavos, 1200);
  });

  test('recomenda reduzir sem romper o piso de margem', () {
    final r = analisarMercado(precoAtualCentavos: 1800, custoCentavos: 1100, ofertas: ofertas);
    expect(r.acao, AcaoPrecoMercado.reduzir);
    expect(r.precoSugeridoCentavos, 1320);
  });

  test('não recomenda com uma única oferta', () {
    final r = analisarMercado(precoAtualCentavos: 1000, ofertas: ofertas.take(1).toList());
    expect(r.acao, AcaoPrecoMercado.revisarDados);
  });
}
