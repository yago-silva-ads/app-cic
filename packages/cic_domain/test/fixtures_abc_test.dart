// Roda todas as fixtures compartilhadas de fixtures/abc-v1. A versão Web deve
// carregar os mesmos arquivos e chegar exatamente nos mesmos centavos/classes.
import 'dart:convert';
import 'dart:io';

import 'package:cic_domain/cic_domain.dart';
import 'package:test/test.dart';

void main() {
  final arquivos =
      Directory(
          'fixtures/abc-v1',
        ).listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('há fixtures abc-v1', () => expect(arquivos, isNotEmpty));

  for (final arquivo in arquivos) {
    final j = jsonDecode(arquivo.readAsStringSync()) as Map<String, Object?>;
    test('${arquivo.uri.pathSegments.last}: ${j['descricao']}', () {
      final r = calcularFixture(j);
      final esperado = (j['esperado'] as Map).cast<String, Object?>();

      expect(r.versaoContrato, 'abc-v1');
      expect(r.valorLiquidoTotalCentavos, esperado['valorLiquidoTotalCentavos']);
      expect(r.totalPositivoCentavos, esperado['totalPositivoCentavos']);
      final itensEsperados = (esperado['itens'] as List).cast<Map>();
      expect(
        r.itens.map((i) => i.produtoId).toList(),
        itensEsperados.map((i) => i['produtoId']).toList(),
        reason: 'ordem',
      );
      for (var k = 0; k < itensEsperados.length; k++) {
        final e = itensEsperados[k];
        final i = r.itens[k];
        expect(i.quantidade, e['quantidade'], reason: '${i.produtoId} quantidade');
        expect(i.valorBaseCentavos, e['valorBaseCentavos'], reason: '${i.produtoId} valor');
        expect(
          i.acumuladoDepoisCentavos,
          e['acumuladoDepoisCentavos'],
          reason: '${i.produtoId} acumulado',
        );
        expect(i.classe.name, e['classe'], reason: '${i.produtoId} classe');
        expect(i.lucroBrutoCentavos, e['lucroBrutoCentavos'], reason: '${i.produtoId} lucro');
      }
      expect(r.alertas.map((a) => a.id).toList(), esperado['alertas']);
      expect((r.problemas.map((p) => p.codigo.name).toList()..sort()), esperado['problemas']);
    });
  }
}

ResultadoCurvaAbc calcularFixture(Map<String, Object?> j, {PeriodoAbc? periodo}) {
  final servico = CurvaAbcService(
    fuso: FusoLoja(j['fuso'] as String),
    relogio: RelogioFixo(DateTime.parse(j['relogioUtc'] as String)),
  );
  return servico.calcular(
    periodo: periodo ?? PeriodoAbc.deCodigo(j['periodo'] as String),
    estoque: SnapshotEstoque.fromJson((j['estoque'] as Map).cast()),
    eventos: [for (final e in j['eventos'] as List) EventoComercial.fromJson((e as Map).cast())],
  );
}
