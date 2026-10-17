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

  test('mantém preço quando reduzir quebraria o piso de margem', () {
    final r = analisarMercado(precoAtualCentavos: 1200, custoCentavos: 1000, ofertas: const [
      OfertaMercado(precoCentavos: 700, fonte: 'A', url: 'https://a'),
      OfertaMercado(precoCentavos: 800, fonte: 'B', url: 'https://b'),
      OfertaMercado(precoCentavos: 900, fonte: 'C', url: 'https://c'),
    ]);
    expect(r.acao, AcaoPrecoMercado.manter);
    expect(r.precoSugeridoCentavos, 1200);
    expect(r.motivo, contains('piso mínimo de margem'));
  });

  test('aumenta até o piso quando o preço atual está abaixo dele', () {
    final r = analisarMercado(precoAtualCentavos: 1000, custoCentavos: 1000, ofertas: const [
      OfertaMercado(precoCentavos: 700, fonte: 'A', url: 'https://a'),
      OfertaMercado(precoCentavos: 800, fonte: 'B', url: 'https://b'),
      OfertaMercado(precoCentavos: 900, fonte: 'C', url: 'https://c'),
    ]);
    expect(r.acao, AcaoPrecoMercado.aumentar);
    expect(r.precoSugeridoCentavos, 1200);
  });
}
