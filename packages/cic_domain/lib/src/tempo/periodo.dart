import 'fuso_loja.dart';

/// Períodos do contrato abc-v1. `projetado` não é um intervalo de tempo:
/// é o cenário teórico do estoque atual, separado do realizado.
enum PeriodoAbc {
  hoje('hoje'),
  seteDias('seteDias'),
  mes('mes'),
  todos('todos'),
  projetado('projetado');

  const PeriodoAbc(this.codigo);

  final String codigo;

  bool get ehRealizado => this != PeriodoAbc.projetado;

  static PeriodoAbc deCodigo(String codigo) => PeriodoAbc.values.firstWhere(
    (p) => p.codigo == codigo,
    orElse: () => throw FormatException('Período desconhecido: $codigo'),
  );
}

/// Intervalo civil resolvido no fuso da loja.
///
/// Regra de inclusão (igual em Web e Dart): `inicioUtc <= instante <= fimUtc`,
/// com precisão de milissegundo. `fimUtc` é o instante atual do relógio, então
/// datas futuras ficam sempre de fora.
class JanelaPeriodo {
  const JanelaPeriodo._({
    required this.periodo,
    required this.fuso,
    required this.inicioUtc,
    required this.fimUtc,
    required this.primeiraData,
    required this.ultimaData,
  });

  final PeriodoAbc periodo;
  final String fuso;

  /// `null` em `todos`: sem limite inferior.
  final DateTime? inicioUtc;
  final DateTime fimUtc;
  final DataCivil? primeiraData;
  final DataCivil ultimaData;

  /// `hoje` = 1 data civil, `seteDias` = 7, `mes` = 30 (não é mês-calendário).
  static const Map<PeriodoAbc, int> datasCivisPorPeriodo = {
    PeriodoAbc.hoje: 1,
    PeriodoAbc.seteDias: 7,
    PeriodoAbc.mes: 30,
  };

  factory JanelaPeriodo.resolver({
    required PeriodoAbc periodo,
    required FusoLoja fuso,
    required Relogio relogio,
  }) {
    if (!periodo.ehRealizado) {
      throw ArgumentError.value(
        periodo,
        'periodo',
        'Projetado não tem janela temporal; use o snapshot de estoque',
      );
    }
    final agora = relogio.agoraUtc();
    final hoje = fuso.dataCivilDe(agora);
    final datas = datasCivisPorPeriodo[periodo];
    if (datas == null) {
      return JanelaPeriodo._(
        periodo: periodo,
        fuso: fuso.nome,
        inicioUtc: null,
        fimUtc: agora,
        primeiraData: null,
        ultimaData: hoje,
      );
    }
    final primeira = hoje.somarDias(-(datas - 1));
    return JanelaPeriodo._(
      periodo: periodo,
      fuso: fuso.nome,
      inicioUtc: fuso.inicioDoDiaUtc(primeira),
      fimUtc: agora,
      primeiraData: primeira,
      ultimaData: hoje,
    );
  }

  bool contem(DateTime instante) {
    final t = instante.toUtc();
    if (t.isAfter(fimUtc)) return false;
    final inicio = inicioUtc;
    return inicio == null || !t.isBefore(inicio);
  }

  Map<String, Object?> toJson() => {
    'periodo': periodo.codigo,
    'fuso': fuso,
    'inicioUtc': inicioUtc?.toIso8601String(),
    'fimUtc': fimUtc.toIso8601String(),
    'primeiraData': primeiraData?.toString(),
    'ultimaData': ultimaData.toString(),
  };
}
