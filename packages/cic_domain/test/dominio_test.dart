import 'dart:convert';
import 'dart:io';

import 'package:cic_domain/cic_domain.dart';
import 'package:test/test.dart';

import 'fixtures_abc_test.dart' show calcularFixture;

Map<String, Object?> fixture(String nome) =>
    jsonDecode(File('fixtures/abc-v1/$nome').readAsStringSync()) as Map<String, Object?>;

final agora = DateTime.utc(2026, 10, 11, 15);

Venda venda(
  String id,
  DateTime instante,
  List<ItemVendido> itens, {
  StatusVenda status = StatusVenda.concluida,
  int desconto = 0,
}) => Venda(
  id: id,
  instante: instante,
  itens: itens,
  status: status,
  descontoPedidoCentavos: desconto,
);

ItemVendido item(String itemId, String produtoId, int qtd, int preco, {int? custo, String? nome}) =>
    ItemVendido(
      itemId: itemId,
      produtoId: produtoId,
      quantidade: qtd,
      precoUnitarioCentavos: preco,
      custoUnitarioHistoricoCentavos: custo,
      nomeHistorico: nome,
    );

SnapshotEstoque snapshot(
  List<Produto> produtos,
  List<Lote> lotes, {
  bool carregado = true,
  Set<String> semSaldo = const {},
}) => SnapshotEstoque(
  versao: 'teste',
  atualizadoEm: agora,
  produtos: produtos,
  lotes: lotes,
  carregado: carregado,
  produtosSemSaldoConhecido: semSaldo,
);

CurvaAbcService servico([DateTime? instante]) =>
    CurvaAbcService(fuso: FusoLoja.padrao(), relogio: RelogioFixo(instante ?? agora));

void main() {
  group('classificação abc-v1', () {
    test('usa o acumulado ANTES do item, com limites exatos', () {
      expect(classificar(acumuladoAntes: 79, totalPositivo: 100), ClasseAbc.A);
      expect(classificar(acumuladoAntes: 80, totalPositivo: 100), ClasseAbc.B);
      expect(classificar(acumuladoAntes: 94, totalPositivo: 100), ClasseAbc.B);
      expect(classificar(acumuladoAntes: 95, totalPositivo: 100), ClasseAbc.C);
      // 4/5 = 80% exato, sem arredondamento de ponto flutuante.
      expect(classificar(acumuladoAntes: 4, totalPositivo: 5), ClasseAbc.B);
      // 2/3 = 66,67% → A; 19/20 = 95% → C.
      expect(classificar(acumuladoAntes: 2, totalPositivo: 3), ClasseAbc.A);
      expect(classificar(acumuladoAntes: 19, totalPositivo: 20), ClasseAbc.C);
    });

    test('total positivo zero → C, sem divisão por zero', () {
      expect(classificar(acumuladoAntes: 0, totalPositivo: 0), ClasseAbc.C);
    });

    test('produto único com 100% é A', () {
      final r = servico().calcular(
        periodo: PeriodoAbc.hoje,
        estoque: snapshot(
          [const Produto(id: 'p', nome: 'Único')],
          [const Lote(id: 'l', produtoId: 'p', quantidadeFisica: 50)],
        ),
        eventos: [
          venda('v', agora, [item('1', 'p', 1, 999, custo: 1)]),
        ],
      );
      expect(r.itens.single.classe, ClasseAbc.A);
      expect(r.itens.single.participacaoPercentual, 100);
    });

    test('percentuais da fixture obrigatória: 70/85/95/100/100', () {
      final r = calcularFixture(fixture('01_classes_e_ruptura.json'));
      expect(r.itens.map((i) => i.acumuladoPercentual), [70, 85, 95, 100, 100]);
      expect(r.itens.map((i) => i.participacaoPercentual), [70, 15, 10, 5, 0]);
      expect(r.resumoPorClasse[ClasseAbc.A]!.produtos, 2);
      expect(r.itens.first.margemBrutaPercentual, 40);
      expect(r.itens.first.markupPercentual, closeTo(66.67, 0.01));
    });
  });

  group('períodos no fuso da loja', () {
    test('hoje começa à meia-noite da loja, não do UTC', () {
      final r = calcularFixture(fixture('04_limites_de_data.json'), periodo: PeriodoAbc.hoje);
      expect(r.janela!.inicioUtc, DateTime.utc(2026, 10, 11, 3));
      expect(r.itens.single.quantidade, 1, reason: 'só o evento das 12:00 BRT');
    });

    test('mes = 30 datas civis, não mês-calendário', () {
      final j = JanelaPeriodo.resolver(
        periodo: PeriodoAbc.mes,
        fuso: FusoLoja.padrao(),
        relogio: RelogioFixo(agora),
      );
      expect(j.primeiraData, const DataCivil(2026, 9, 12));
      expect(j.ultimaData, const DataCivil(2026, 10, 11));
      expect(j.inicioUtc, DateTime.utc(2026, 9, 12, 3));
    });

    test('todos exclui datas futuras', () {
      final j = JanelaPeriodo.resolver(
        periodo: PeriodoAbc.todos,
        fuso: FusoLoja.padrao(),
        relogio: RelogioFixo(agora),
      );
      expect(j.contem(DateTime.utc(2000)), isTrue);
      expect(j.contem(agora.add(const Duration(milliseconds: 1))), isFalse);
    });

    test('o resultado depende do fuso da loja, não do aparelho', () {
      final instante = DateTime.utc(2026, 10, 11, 2, 30);
      expect(FusoLoja.padrao().dataCivilDe(instante), const DataCivil(2026, 10, 10));
      expect(FusoLoja('Asia/Tokyo').dataCivilDe(instante), const DataCivil(2026, 10, 11));
    });

    test('dia que começou no horário de verão histórico (04/11/2018)', () {
      final fuso = FusoLoja.padrao();
      final inicio = fuso.inicioDoDiaUtc(const DataCivil(2018, 11, 4));
      expect(fuso.dataCivilDe(inicio), const DataCivil(2018, 11, 4));
      expect(
        fuso.dataCivilDe(inicio.subtract(const Duration(milliseconds: 1))),
        const DataCivil(2018, 11, 3),
      );
    });

    test('fuso inexistente falha em vez de usar o do aparelho', () {
      expect(() => FusoLoja('America/Atlantida'), throwsArgumentError);
    });

    test('projetado não tem janela temporal', () {
      expect(
        () => JanelaPeriodo.resolver(
          periodo: PeriodoAbc.projetado,
          fuso: FusoLoja.padrao(),
          relogio: RelogioFixo(agora),
        ),
        throwsArgumentError,
      );
    });
  });

  group('valores realizados', () {
    test('mudança de preço/custo após a venda não altera o histórico', () {
      final j = fixture('01_classes_e_ruptura.json');
      final estoque = (j['estoque'] as Map).cast<String, Object?>();
      for (final p in (estoque['produtos'] as List).cast<Map>()) {
        p['precoVendaAtualCentavos'] = 1;
        p['custoAtualCentavos'] = 99999;
      }
      final r = calcularFixture(j);
      expect(r.itens.first.valorBaseCentavos, 70000);
      expect(r.itens.first.lucroBrutoCentavos, 28000);
    });

    test('custo histórico ausente não vira lucro', () {
      final r = servico().calcular(
        periodo: PeriodoAbc.hoje,
        estoque: snapshot([const Produto(id: 'p', nome: 'Sem custo')], const []),
        eventos: [
          venda('v', agora, [item('1', 'p', 2, 500)]),
        ],
      );
      expect(r.itens.single.lucroBrutoCentavos, isNull);
      expect(r.itens.single.margemBrutaPercentual, isNull);
      expect(r.lucroBrutoTotalCentavos, isNull);
      expect(r.problemas.single.codigo, CodigoQualidade.custoHistoricoAusente);
    });

    test('desconto de pedido rateado fecha exatamente com o total', () {
      expect(ratearProporcional(100, [2000, 1000]), [67, 33]);
      expect(ratearProporcional(10, [1, 1, 1]), [4, 3, 3]);
      final partes = ratearProporcional(9999, [333, 777, 1, 0, 5000]);
      expect(partes.fold<int>(0, (a, b) => a + b), 9999);
      expect(partes[3], 0);
    });

    test('devoluções parciais somam exatamente o líquido; excesso é limitado', () {
      final ontem = agora.subtract(const Duration(days: 1));
      final r = servico().calcular(
        periodo: PeriodoAbc.todos,
        estoque: snapshot([const Produto(id: 'p', nome: 'P')], const []),
        eventos: [
          venda('v', ontem, [item('1', 'p', 3, 1000, custo: 100)], desconto: 1),
          Devolucao(id: 'd1', instante: agora, vendaId: 'v', itemId: '1', quantidade: 1),
          Devolucao(id: 'd2', instante: agora, vendaId: 'v', itemId: '1', quantidade: 1),
          Devolucao(id: 'd3', instante: agora, vendaId: 'v', itemId: '1', quantidade: 5),
        ],
      );
      // 2999 líquidos; três devoluções estornam 999 + 1000 + 1000.
      expect(r.itens.single.valorBaseCentavos, 0);
      expect(r.itens.single.quantidade, 0);
      expect(r.itens.single.lucroBrutoCentavos, 0);
      expect(r.problemas.map((p) => p.codigo), [CodigoQualidade.devolucaoAcimaDoVendido]);
    });

    test('devolução hoje de venda de ontem: receita negativa reportada à parte, fica C', () {
      final ontem = agora.subtract(const Duration(days: 1));
      final r = servico().calcular(
        periodo: PeriodoAbc.hoje,
        estoque: snapshot(
          [const Produto(id: 'a', nome: 'A'), const Produto(id: 'b', nome: 'B')],
          const [Lote(id: 'l', produtoId: 'b', quantidadeFisica: 100)],
        ),
        eventos: [
          venda('v0', ontem, [item('1', 'a', 1, 800, custo: 100)]),
          Devolucao(id: 'd', instante: agora, vendaId: 'v0', itemId: '1', quantidade: 1),
          venda('v1', agora, [item('1', 'b', 1, 1000, custo: 100)]),
        ],
      );
      final a = r.itens.firstWhere((i) => i.produtoId == 'a');
      expect(a.valorBaseCentavos, -800);
      expect(a.classe, ClasseAbc.C);
      expect(r.totalPositivoCentavos, 1000);
      expect(r.valorLiquidoTotalCentavos, 200);
      expect(r.totalNegativoCentavos, -800);
    });

    test('produto arquivado ou excluído com vendas mantém identidade histórica', () {
      final r = servico().calcular(
        periodo: PeriodoAbc.hoje,
        estoque: snapshot([const Produto(id: 'arq', nome: 'Arquivado', arquivado: true)], const []),
        eventos: [
          venda('v', agora, [
            item('1', 'arq', 1, 500, custo: 100),
            item('2', 'sumiu', 1, 300, custo: 100, nome: 'Produto excluído'),
          ]),
        ],
      );
      expect(r.itens.map((i) => i.nome), ['Arquivado', 'Produto excluído']);
      expect(r.itens.last.estoqueDisponivel, isNull, reason: 'desconhecido, não zero');
      expect(r.alertas, isEmpty, reason: 'fora de linha não gera reposição');
    });
  });

  group('estoque', () {
    test('três SKUs com 10, 5 e 0 → 3 cadastrados, 2 com saldo, 15 unidades', () {
      final resumo = const EstoqueService().resumir(
        snapshot(
          [
            const Produto(id: 'a', nome: 'A'),
            const Produto(id: 'b', nome: 'B'),
            const Produto(id: 'c', nome: 'C'),
          ],
          const [
            Lote(id: 'la', produtoId: 'a', quantidadeFisica: 10),
            Lote(id: 'lb', produtoId: 'b', quantidadeFisica: 5),
            Lote(id: 'lc', produtoId: 'c', quantidadeFisica: 0),
          ],
        ),
      );
      expect(resumo.produtosCadastrados, 3);
      expect(resumo.produtosComSaldo, 2);
      expect(resumo.unidadesDisponiveis, 15);
      expect(
        const RespostasDeterministicas().estoqueAtual(resumo).resposta,
        'Você tem 2 produtos com saldo e 15 unidades disponíveis; 3 cadastrados.',
      );
    });

    test('vários lotes do mesmo produto somam; validade fica por lote; código preserva zeros', () {
      final snap = SnapshotEstoque.fromJson({
        'versao': 'x',
        'atualizadoEm': '2026-10-11T15:00:00Z',
        'produtos': [
          {'id': 'p', 'nome': 'Iogurte', 'codigoBarras': '0012345678905'},
        ],
        'lotes': [
          {'id': 'l1', 'produtoId': 'p', 'quantidadeFisica': 4, 'validade': '2026-11-01'},
          {
            'id': 'l2',
            'produtoId': 'p',
            'quantidadeFisica': 6,
            'quantidadeReservada': 2,
            'validade': '2026-10-20',
          },
          {'id': 'l3', 'produtoId': 'p', 'quantidadeFisica': 0, 'validade': '2026-10-12'},
        ],
      });
      final saldo = const EstoqueService().saldos(snap)['p']!;
      expect(snap.produtos.single.codigoBarras, '0012345678905');
      expect(saldo.fisico, 10);
      expect(saldo.disponivel, 8);
      expect(saldo.quantidadeLotes, 3);
      expect(saldo.proximaValidade, const DataCivil(2026, 10, 20), reason: 'lote vazio ignorado');
      final resumo = const EstoqueService().resumir(snap);
      expect((resumo.produtosCadastrados, resumo.quantidadeLotes), (1, 3));
    });

    test('falha de carregamento não é estoque zero', () {
      final resumo = const EstoqueService().resumir(
        snapshot([const Produto(id: 'a', nome: 'A')], const [], carregado: false),
      );
      expect(resumo.completo, isFalse);
      expect(resumo.produtosSemSaldoConhecido, 1);
      expect(resumo.problemas.single.codigo, CodigoQualidade.estoqueDesconhecido);
      expect(const RespostasDeterministicas().estoqueAtual(resumo).dadosAusentes, isNotEmpty);
    });

    test('estoque negativo vira inconsistência e alerta para classe A', () {
      final r = servico().calcular(
        periodo: PeriodoAbc.hoje,
        estoque: snapshot(
          [const Produto(id: 'a', nome: 'A')],
          const [Lote(id: 'l', produtoId: 'a', quantidadeFisica: -2)],
        ),
        eventos: [
          venda('v', agora, [item('1', 'a', 1, 100, custo: 10)]),
        ],
      );
      expect(r.alertas.single.estoqueDisponivel, -2);
      expect(r.problemas.map((p) => p.codigo), contains(CodigoQualidade.estoqueNegativo));
    });

    test('classe A com estoque desconhecido avisa dado ausente em vez de alertar', () {
      final r = servico().calcular(
        periodo: PeriodoAbc.hoje,
        estoque: snapshot(
          [const Produto(id: 'a', nome: 'A')],
          const [],
          semSaldo: {'a'},
        ),
        eventos: [
          venda('v', agora, [item('1', 'a', 1, 100, custo: 10)]),
        ],
      );
      expect(r.alertas, isEmpty);
      expect(r.problemas.single.codigo, CodigoQualidade.estoqueDesconhecido);
    });
  });

  group('projetado', () {
    test('potencial = disponível × preço atual; alerta é teórico', () {
      final r = servico().calcular(
        periodo: PeriodoAbc.projetado,
        estoque: snapshot(
          [
            const Produto(
              id: 'a',
              nome: 'A',
              precoVendaAtualCentavos: 1000,
              custoAtualCentavos: 600,
            ),
            const Produto(id: 'b', nome: 'B', precoVendaAtualCentavos: 100),
          ],
          const [
            Lote(id: 'la', produtoId: 'a', quantidadeFisica: 4),
            Lote(id: 'lb', produtoId: 'b', quantidadeFisica: 10),
          ],
        ),
      );
      expect(r.modo, ModoAbc.projetado);
      expect(r.janela, isNull);
      expect(r.itens.first.valorBaseCentavos, 4000);
      expect(r.itens.first.lucroBrutoCentavos, 1600);
      expect(r.itens.last.lucroBrutoCentavos, isNull);
      expect(r.alertas.single.teorico, isTrue);
      expect(r.problemas.single.codigo, CodigoQualidade.custoAtualAusente);
    });

    test('projetado com total zero → todos C (não vira tudo A)', () {
      final r = servico().calcular(
        periodo: PeriodoAbc.projetado,
        estoque: snapshot(
          [
            const Produto(id: 'a', nome: 'A', precoVendaAtualCentavos: 0, custoAtualCentavos: 0),
            const Produto(id: 'b', nome: 'B', precoVendaAtualCentavos: 500, custoAtualCentavos: 1),
          ],
          const [Lote(id: 'la', produtoId: 'a', quantidadeFisica: 3)],
        ),
      );
      expect(r.itens.map((i) => i.classe), everyElement(ClasseAbc.C));
      expect(r.alertas, isEmpty);
    });
  });

  group('alertas de ruptura', () {
    test('repor resolve; lido não resolve; não duplica a cada recálculo', () {
      final j = fixture('01_classes_e_ruptura.json');
      final t0 = agora;
      var estados = conciliarAlertas(const [], calcularFixture(j).alertas, t0);
      expect(estados.single.alerta.id, 'ruptura:p-700:hoje');

      estados = [estados.single.marcarLido()];
      estados = conciliarAlertas(estados, calcularFixture(j).alertas, t0);
      expect(estados, hasLength(1));
      expect(estados.single.lido, isTrue);
      expect(estados.single.resolvido, isFalse, reason: 'lido não resolve a falta física');

      final lotes = ((j['estoque'] as Map)['lotes'] as List).cast<Map>();
      lotes.firstWhere((l) => l['produtoId'] == 'p-700')['quantidadeFisica'] = 6;
      final depois = calcularFixture(j);
      expect(depois.alertas, isEmpty);
      final t1 = t0.add(const Duration(minutes: 5));
      estados = conciliarAlertas(estados, depois.alertas, t1);
      expect(estados.single.resolvidoEm, t1);
    });
  });

  test('formatação pt-BR', () {
    expect(formatarCentavos(123456), r'R$ 1.234,56');
    expect(formatarCentavos(-5), r'-R$ 0,05');
    expect(formatarCentavos(100000000), r'R$ 1.000.000,00');
    expect(formatarInteiro(1500), '1.500');
  });
}
