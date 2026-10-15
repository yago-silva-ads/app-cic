import 'package:cic_domain/cic_domain.dart';
import 'package:test/test.dart';

ItemCurvaAbc _item(String id, String nome, {required int vendidos, required int? estoque, ClasseAbc classe = ClasseAbc.A}) =>
    ItemCurvaAbc(
      posicao: 1, produtoId: id, nome: nome, arquivado: false, quantidade: vendidos,
      valorBaseCentavos: vendidos * 1000, custoCentavos: vendidos * 600, lucroBrutoCentavos: vendidos * 400,
      acumuladoAntesCentavos: 0, acumuladoDepoisCentavos: vendidos * 1000, totalPositivoCentavos: 100000,
      classe: classe, estoqueDisponivel: estoque, valorCompleto: true,
    );

ResultadoCurvaAbc _abc(List<ItemCurvaAbc> itens) => ResultadoCurvaAbc(
  modo: ModoAbc.realizado, periodo: PeriodoAbc.mes, janela: null, fuso: 'America/Sao_Paulo',
  snapshotVersion: 'snap-1', atualizadoEm: DateTime.utc(2026, 10, 15), geradoEm: DateTime.utc(2026, 10, 15),
  demonstracao: false, itens: itens, alertas: const [], problemas: const [],
);

void main() {
  final abc = _abc([
    _item('7891', 'Leite Integral', vendidos: 60, estoque: 8), // 2/dia → acaba em 4 dias
    _item('7892', 'Café 500g', vendidos: 30, estoque: 0), // vendia e zerou
    _item('7893', 'Vinagre', vendidos: 0, estoque: 40, classe: ClasseAbc.C), // parado
    _item('7894', 'Arroz 5kg', vendidos: 15, estoque: 30), // 0,5/dia → 60 dias
    _item('7895', 'Sem saldo conhecido', vendidos: 5, estoque: null),
  ]);
  final p = const PrevisaoDemanda().calcular(abc);
  ItemPrevisao de(String id) => p.itens.firstWhere((i) => i.produtoId == id);

  test('classifica pela cobertura real e ordena o mais urgente primeiro', () {
    expect(de('7892').situacao, SituacaoPrevisao.ruptura);
    expect(de('7891').situacao, SituacaoPrevisao.critico);
    expect(de('7891').coberturaDias, 4);
    expect(de('7891').mediaDiaria, 2.0);
    expect(de('7894').situacao, SituacaoPrevisao.ok);
    expect(de('7893').situacao, SituacaoPrevisao.parado);
    expect(de('7895').situacao, SituacaoPrevisao.semDados);
    expect(p.itens.first.produtoId, '7892');
  });

  test('reposição cobre o horizonte de 14 dias descontando o saldo', () {
    expect(de('7891').reposicaoSugerida, 28 - 8); // 2/dia × 14 = 28
    expect(de('7892').reposicaoSugerida, 14); // 1/dia × 14
    expect(de('7894').reposicaoSugerida, 0);
    expect(de('7895').reposicaoSugerida, 0); // sem saldo conhecido não sugere nada
  });

  test('a IA pode citar os números da previsão, mas não números inventados', () {
    final ctx = ContextoAterramento.de(snapshotVersion: 'snap-1', abc: [abc], previsao: p);
    RespostaConsultor r(String texto) => RespostaConsultor(
      resposta: texto, tipo: TipoResposta.analise, origem: OrigemResposta.ia,
      snapshotVersion: 'snap-1', atualizadoEm: DateTime.utc(2026, 10, 15),
    );
    expect(verificarAterramento(r('Leite Integral acaba em 4 dias; compre 20 unidades.'), ctx), isEmpty);
    expect(verificarAterramento(r('Leite Integral acaba em 9 dias.'), ctx), isNotEmpty);
    expect(verificarAterramento(r('Compre 77 unidades de Café 500g.'), ctx), isNotEmpty);
  });

  test('previsão vai no payload da IA', () {
    final c = ConsultaIa(
      pergunta: 'quando acaba o leite?', periodo: PeriodoAbc.mes, fuso: 'America/Sao_Paulo',
      snapshotVersion: 'snap-1', atualizadoEm: DateTime.utc(2026, 10, 15), demonstracao: false, abc: abc, previsao: p,
    ).toJson();
    expect((c['previsao'] as Map)['diasAlvo'], 14);
  });

  test('resposta fora do escopo é aceita no contrato', () {
    final r = RespostaConsultor.daIa({
      'resposta': 'Posso ajudar só com o seu negócio: estoque, vendas, custos e preços.',
      'tipo': 'fora_do_escopo', 'fontes': <String>[], 'alertas': <String>[], 'dadosAusentes': <String>[],
      'metricas': <String, num>{}, 'snapshotVersion': 'snap-1', 'atualizadoEm': '2026-10-15T00:00:00Z',
    });
    expect(r.tipo, TipoResposta.foraDoEscopo);
  });
}
