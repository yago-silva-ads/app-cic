// Regressões dos achados 3, 8 (domínio), 10A e 11 (trava).
// Executar em packages/cic_domain: dart test test/auditoria_adversarial_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:cic_domain/cic_domain.dart';
import 'package:test/test.dart';

import 'fixtures_abc_test.dart' show calcularFixture;

void main() {
  Map<String, Object?> lerFixture() => jsonDecode(
    File('fixtures/abc-v1/01_classes_e_ruptura.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final fixture = lerFixture();
  final abc = calcularFixture(fixture);
  final estoque = const EstoqueService().resumir(
    SnapshotEstoque.fromJson((fixture['estoque'] as Map).cast()),
  );
  final ctx = ContextoAterramento.de(
    snapshotVersion: 'snap-001',
    estoque: estoque,
    abc: [abc],
    fuso: FusoLoja.padrao(),
  );
  final fallback = const RespostasDeterministicas().estoqueAtual(estoque);

  Map<String, Object?> saida(String texto) => {
    'versaoContrato': versaoContratoIa,
    'resposta': texto,
    'tipo': 'analise',
    'periodo': 'hoje',
    'metricas': <String, num>{},
    'fontes': <String>['p-700'],
    'alertas': <String>[],
    'dadosAusentes': <String>[],
    'snapshotVersion': 'snap-001',
    'atualizadoEm': '2026-10-11T14:59:00.000Z',
  };
  List<String> validar(String texto, [ContextoAterramento? contexto]) =>
      verificarAterramento(RespostaConsultor.daIa(saida(texto)), contexto ?? ctx);

  group('achado 3: números e nomes de produtos', () {
    for (final texto in [
      'Há 999kg disponíveis.',
      'Há 999,50kg disponíveis.',
      'Há 999, conforme o estoque.',
      'Há −30 unidades disponíveis.',
      'O faturamento é −R\$ 700,00.',
      'A participação é −70%.',
    ]) {
      test('rejeita: $texto', () => expect(validar(texto), isNotEmpty));
    }
    test('número conhecido colado em unidade continua permitido', () {
      expect(validar('Há 5kg disponíveis.'), isEmpty);
    });
    test('dinheiro brasileiro com milhar e NBSP continua permitido', () {
      expect(validar('O faturamento total é R\$\u00a01.000,00.'), isEmpty);
    });
    test('nome conhecido com embalagem não vira número inventado', () {
      expect(validar('Café 500g tem 5 unidades em estoque.'), isEmpty);
      expect(validar('Café 500g tem 999kg disponíveis.'), isNotEmpty);
    });
    test('remove nome completo com embalagem separada e ignora caixa', () {
      final alterada = lerFixture();
      final produtos = (alterada['estoque'] as Map)['produtos'] as List;
      (produtos.first as Map)['nome'] = 'Café 500 g';
      final contexto = ContextoAterramento.de(
        snapshotVersion: 'snap-001', abc: [calcularFixture(alterada)],
      );
      expect(validar('CAFÉ 500 G tem 5 unidades.', contexto), isEmpty);
      expect(validar('Café 500 gx tem 5 unidades.', contexto), isNotEmpty);
      expect(validar('SuperCafé 500 g tem 5 unidades.', contexto), isNotEmpty);
    });
  });

  group('achado 8: parser e recuperação', () {
    for (final periodo in <Object>[42, true, <String>[], <String, Object>{}]) {
      test('periodo ${periodo.runtimeType} gera FormatException', () {
        final json = saida('Confira o estoque.')..['periodo'] = periodo;
        expect(() => RespostaConsultor.daIa(json), throwsFormatException);
      });
    }
    test('periodo null continua permitido', () {
      final json = saida('Confira o estoque.')..['periodo'] = null;
      expect(RespostaConsultor.daIa(json).periodo, isNull);
    });
    for (final valor in [double.infinity, double.negativeInfinity, double.nan]) {
      test('métrica $valor é rejeitada antes de arredondar', () {
        final json = saida('Confira o estoque.')
          ..['metricas'] = <String, num>{'x': valor};
        expect(() => RespostaConsultor.daIa(json), throwsFormatException);
      });
    }
    test('erro inesperado não escapa de ConsultorSeguro', () async {
      final r = await const ConsultorSeguro().responder(
        requestId: 'erro-inesperado',
        chamarIa: () async => throw StateError('falha simulada'),
        contexto: ctx, fallback: fallback,
      );
      expect(r.origem, OrigemResposta.fallbackSeguro);
      expect(r.resposta, fallback.resposta);
    });
    test('periodo inválido também retorna fallback', () async {
      final r = await const ConsultorSeguro().responder(
        requestId: 'periodo-invalido',
        chamarIa: () async => (saida('Confira o estoque.')..['periodo'] = 42),
        contexto: ctx, fallback: fallback,
      );
      expect(r.origem, OrigemResposta.fallbackSeguro);
      expect(r.resposta, fallback.resposta);
    });
    for (final falharChamada in [false, true]) {
      test('falha de telemetria preserva fallback (erro: $falharChamada)', () async {
        final r = await const ConsultorSeguro().responder(
          requestId: 'telemetria',
          chamarIa: () async {
            if (falharChamada) throw const RespostaInvalidaIa('simulada');
            return saida('Confira o estoque.');
          },
          contexto: ctx, fallback: fallback,
          registrar: (_) => throw StateError('telemetria indisponível'),
        );
        expect(r.origem, OrigemResposta.fallbackSeguro);
        expect(r.resposta, fallback.resposta);
      });
    }
  });

  group('achado 10A: limites da previsão', () {
    for (final janela in [0, -30]) {
      test('janela $janela é rejeitada', () {
        expect(() => const PrevisaoDemanda().calcular(abc, diasJanela: janela),
            throwsArgumentError);
      });
    }
    for (final horizonte in [0, -14]) {
      test('horizonte $horizonte é rejeitado', () {
        expect(() => PrevisaoDemanda(diasAlvo: horizonte).calcular(abc),
            throwsArgumentError);
      });
    }
    for (final critico in [-1, 20]) {
      test('limiar crítico $critico é rejeitado', () {
        expect(() => PrevisaoDemanda(diasCriticos: critico).calcular(abc),
            throwsArgumentError);
      });
    }
    test('janela de um dia e limiares extremos válidos', () {
      for (final critico in [0, 14]) {
        final r = PrevisaoDemanda(diasCriticos: critico).calcular(abc, diasJanela: 1);
        expect(r.diasJanela, 1);
        expect(r.itens.every((i) => i.reposicaoSugerida >= 0), isTrue);
      }
    });
  });

  group('achado 11: datas civis impossíveis', () {
    List<String> validarData(String data, String instante) {
      final snapshot = Map<String, Object?>.from(fixture['estoque'] as Map)
        ..['atualizadoEm'] = instante;
      final contexto = ContextoAterramento.de(
        snapshotVersion: 'snap-001',
        estoque: const EstoqueService().resumir(SnapshotEstoque.fromJson(snapshot)),
        fuso: FusoLoja.padrao(),
      );
      final json = saida('Dados de $data.')..['fontes'] = <String>[];
      return verificarAterramento(RespostaConsultor.daIa(json), contexto);
    }
    test('31/02 não pode ser normalizado para 03/03 autorizado', () {
      expect(validarData('31/02/2026', '2026-03-03T15:00:00Z'),
          contains('data inexistente: 31/02/2026'));
      expect(validarData('03/03/2026', '2026-03-03T15:00:00Z'), isEmpty);
    });
    test('29/02 exige ano bissexto', () {
      expect(validarData('29/02/2026', '2026-03-01T15:00:00Z'),
          contains('data inexistente: 29/02/2026'));
      expect(validarData('29/02/2024', '2024-02-29T15:00:00Z'), isEmpty);
    });
    test('dia zero não pode virar último dia do mês anterior', () {
      expect(validarData('00/03/2026', '2026-02-28T15:00:00Z'),
          contains('data inexistente: 00/03/2026'));
    });
  });
}
