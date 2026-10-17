// Copiar para packages/cic_domain/test/auditoria_adversarial_test.dart
// na release-blindada. Executar dentro de packages/cic_domain:
// dart test test/auditoria_adversarial_test.dart
// Não executado na auditoria: Dart/Flutter indisponíveis no PATH.
// Testes de regressão expressam o resultado desejado, não o bug atual.
// Os testes de conteúdo livre exigem a evolução de contrato descrita no relatório;
// mantê-los como critérios de aceitação ao adaptar as APIs ao novo contrato.
import 'dart:convert';
import 'dart:io';

import 'package:cic_domain/cic_domain.dart';
import 'package:test/test.dart';

import 'fixtures_abc_test.dart' show calcularFixture;

void main() {
  final fixture = jsonDecode(
    File('fixtures/abc-v1/01_classes_e_ruptura.json').readAsStringSync(),
  ) as Map<String, Object?>;
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
  List<String> validar(String texto) =>
      verificarAterramento(RespostaConsultor.daIa(saida(texto)), ctx);

  final fallback = const RespostasDeterministicas().estoqueAtual(estoque);

  group('controles que devem continuar funcionando', () {
    test('dinheiro brasileiro, milhar e NBSP', () {
      expect(validar('O faturamento total é R\$\u00a01.000,00.'), isEmpty);
    });
    test('nome com tamanho de embalagem não é quantidade inventada', () {
      expect(validar('Café 500g tem 5 unidades em estoque.'), isEmpty);
    });
    test('valor monetário realmente ausente é rejeitado', () {
      expect(validar('Café 500g faturou R\$ 812,40.'), isNotEmpty);
    });
    test('texto vazio é FormatException', () {
      expect(() => RespostaConsultor.daIa(saida('  ')), throwsFormatException);
    });
    test('tipo desconhecido não vira análise no contrato Dart', () {
      final json = saida('Confira o estoque.')..['tipo'] = 'qualquer';
      expect(() => RespostaConsultor.daIa(json), throwsFormatException);
    });
    test('objeto incompleto produz fallback no consultor', () async {
      final r = await const ConsultorSeguro().responder(
        requestId: 'incompleto', chamarIa: () async => <String, Object?>{},
        contexto: ctx, fallback: fallback,
      );
      expect(r.origem, OrigemResposta.fallbackSeguro);
      expect(r.resposta, fallback.resposta);
    });
  });

  group('regressões de aterramento e escopo — falham antes da correção', () {
    test('não atribui saldo de Fósforo ao Café', () {
      expect(validar('Café 500g tem 40 unidades em estoque.'), isNotEmpty);
    });
    test('não atribui faturamento de Leite ao Café', () {
      expect(validar('Café 500g faturou R\$ 150,00.'), isNotEmpty);
    });
    test('a chave da métrica também deve corresponder ao fato', () {
      final json = saida('Confira o estoque.')
        ..['metricas'] = <String, num>{'estoqueCafe': 40};
      expect(verificarAterramento(RespostaConsultor.daIa(json), ctx), isNotEmpty);
    });
    test('classe antes do nome não escapa da checagem', () {
      expect(validar('Classe C: Café 500g.'), isNotEmpty);
    });
    test('não aceita produto inventado com fontes vazias', () {
      final json = saida('Reponha o Abacaxi Imperial.')..['fontes'] = <String>[];
      expect(verificarAterramento(RespostaConsultor.daIa(json), ctx), isNotEmpty);
    });
    test('não exibe assunto fora do negócio sem números', () {
      final json = saida('Era uma vez um dragão feliz.')..['fontes'] = <String>[];
      expect(verificarAterramento(RespostaConsultor.daIa(json), ctx), isNotEmpty);
    });
    test('unidade colada não oculta quantidade', () {
      expect(validar('Há 999kg disponíveis.'), isNotEmpty);
    });
    test('sinal Unicode não transforma número negativo em positivo', () {
      expect(validar('Há −30 unidades disponíveis.'), isNotEmpty);
    });
    test('percentual ABC não autoriza desconto de mesmo valor', () {
      expect(validar('Dê 100% de desconto no Café 500g.'), isNotEmpty);
    });
  });

  group('parser e recuperação', () {
    test('periodo numérico gera FormatException, não TypeError', () {
      final json = saida('Confira o estoque.')..['periodo'] = 42;
      expect(() => RespostaConsultor.daIa(json), throwsFormatException);
    });
    test('métrica infinita é rejeitada antes de arredondar', () {
      final json = saida('Confira o estoque.')
        ..['metricas'] = <String, num>{'x': double.infinity};
      expect(() => RespostaConsultor.daIa(json), throwsFormatException);
    });
    test('métrica NaN é rejeitada antes de arredondar', () {
      final json = saida('Confira o estoque.')
        ..['metricas'] = <String, num>{'x': double.nan};
      expect(() => RespostaConsultor.daIa(json), throwsFormatException);
    });
    test('erro inesperado não escapa de ConsultorSeguro', () async {
      final r = await const ConsultorSeguro().responder(
        requestId: 'erro-inesperado',
        chamarIa: () async => throw StateError('falha simulada'),
        contexto: ctx, fallback: fallback,
      );
      expect(r.origem, OrigemResposta.fallbackSeguro);
      expect(r.resposta, fallback.resposta);
    });
    test('erro de tipo do parser também retorna fallback', () async {
      final r = await const ConsultorSeguro().responder(
        requestId: 'periodo-invalido',
        chamarIa: () async => saida('Confira o estoque.')..['periodo'] = 42,
        contexto: ctx, fallback: fallback,
      );
      expect(r.origem, OrigemResposta.fallbackSeguro);
    });
  });

  group('limites da previsão', () {
    test('janela zero é rejeitada explicitamente', () {
      expect(() => const PrevisaoDemanda().calcular(abc, diasJanela: 0),
          throwsArgumentError);
    });
    test('janela negativa é rejeitada', () {
      expect(() => const PrevisaoDemanda().calcular(abc, diasJanela: -30),
          throwsArgumentError);
    });
    test('horizonte zero é rejeitado', () {
      expect(() => const PrevisaoDemanda(diasAlvo: 0).calcular(abc),
          throwsArgumentError);
    });
    test('limiar crítico além do horizonte é rejeitado', () {
      expect(() => const PrevisaoDemanda(diasCriticos: 20).calcular(abc),
          throwsArgumentError);
    });
    test('um dia da fixture pode ser calculado sem divisão inválida', () {
      final r = const PrevisaoDemanda().calcular(abc, diasJanela: 1);
      expect(r.diasJanela, 1);
      expect(r.itens.every((i) => i.reposicaoSugerida >= 0), isTrue);
    });
  });

  test('Retry-After não deve agendar espera maior que o orçamento do chat', () async {
    final esperas = <Duration>[];
    final policy = PoliticaRetentativa(
      maxTentativas: 2, timeoutPorTentativa: const Duration(seconds: 18),
    );
    // Sem dormir de verdade. Registra a duração que seria aguardada.
    await expectLater(
      policy.executar<Object?>(
        () async => throw const LimiteRequisicoesIa('429 simulado',
            retryAfter: Duration(seconds: 60)),
        esperar: (duracao) async { esperas.add(duracao); },
      ),
      throwsA(isA<LimiteRequisicoesIa>()),
    );
    expect(esperas.fold<int>(0, (s, d) => s + d.inMilliseconds),
        lessThanOrEqualTo(18000));
    // Critério de evolução da política com deadline global. Se a mitigação
    // escolhida for apenas maxTentativas=1 no app, conservar este teste como
    // pendência do domínio e testar separadamente a configuração do app.
  });
}
