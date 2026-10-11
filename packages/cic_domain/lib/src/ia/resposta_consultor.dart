/// Contrato da resposta estruturada do consultor (chat e análise).
library;

const String versaoContratoIa = 'ia-v1';

enum TipoResposta { objetiva, lista, analise, indisponivel }

/// De onde veio o texto. Rastreável e visível: fallback nunca se passa por IA.
enum OrigemResposta { deterministica, ia, fallbackSeguro }

class RespostaConsultor {
  const RespostaConsultor({
    required this.resposta,
    required this.tipo,
    required this.origem,
    required this.snapshotVersion,
    required this.atualizadoEm,
    this.periodo,
    this.metricas = const {},
    this.fontes = const [],
    this.alertas = const [],
    this.dadosAusentes = const [],
    this.aviso,
  });

  final String resposta;
  final TipoResposta tipo;
  final OrigemResposta origem;
  final String? periodo;
  final Map<String, num> metricas;

  /// IDs de produto/registro em que a resposta se apoia. Precisam existir no
  /// snapshot; ID inexistente = alucinação.
  final List<String> fontes;
  final List<String> alertas;
  final List<String> dadosAusentes;
  final String snapshotVersion;
  final DateTime atualizadoEm;

  /// Ex.: "Consultor de IA indisponível; mostrando dados calculados."
  final String? aviso;

  /// Valida o schema da saída da IA. Lança [FormatException] em qualquer
  /// campo ausente ou de tipo errado: JSON inválido não vira resposta.
  factory RespostaConsultor.daIa(Object? json) {
    if (json is! Map) throw const FormatException('Resposta da IA não é um objeto JSON');
    T campo<T>(String nome) {
      final v = json[nome];
      if (v is! T) throw FormatException('Campo "$nome" ausente ou inválido');
      return v;
    }

    List<String> lista(String nome) {
      final v = json[nome] ?? const [];
      if (v is! List || v.any((e) => e is! String)) {
        throw FormatException('Campo "$nome" deve ser lista de strings');
      }
      return v.cast<String>();
    }

    final metricas = json['metricas'] ?? const {};
    if (metricas is! Map || metricas.values.any((v) => v is! num)) {
      throw const FormatException('Campo "metricas" deve mapear nome → número');
    }
    final tipo = campo<String>('tipo');
    final atualizadoEm = DateTime.tryParse(campo<String>('atualizadoEm'));
    if (atualizadoEm == null) throw const FormatException('"atualizadoEm" não é ISO-8601');
    final resposta = campo<String>('resposta').trim();
    if (resposta.isEmpty) throw const FormatException('"resposta" vazia');
    return RespostaConsultor(
      resposta: resposta,
      tipo: TipoResposta.values.firstWhere(
        (t) => t.name == tipo,
        orElse: () => throw FormatException('Tipo desconhecido: $tipo'),
      ),
      origem: OrigemResposta.ia,
      periodo: json['periodo'] as String?,
      metricas: metricas.cast<String, num>(),
      fontes: lista('fontes'),
      alertas: lista('alertas'),
      dadosAusentes: lista('dadosAusentes'),
      snapshotVersion: campo<String>('snapshotVersion'),
      atualizadoEm: atualizadoEm.toUtc(),
    );
  }

  RespostaConsultor comAviso(String aviso, {OrigemResposta? origem}) => RespostaConsultor(
    resposta: resposta,
    tipo: tipo,
    origem: origem ?? this.origem,
    snapshotVersion: snapshotVersion,
    atualizadoEm: atualizadoEm,
    periodo: periodo,
    metricas: metricas,
    fontes: fontes,
    alertas: alertas,
    dadosAusentes: dadosAusentes,
    aviso: aviso,
  );

  Map<String, Object?> toJson() => {
    'versaoContrato': versaoContratoIa,
    'resposta': resposta,
    'tipo': tipo.name,
    'origem': origem.name,
    'periodo': periodo,
    'metricas': metricas,
    'fontes': fontes,
    'alertas': alertas,
    'dadosAusentes': dadosAusentes,
    'snapshotVersion': snapshotVersion,
    'atualizadoEm': atualizadoEm.toIso8601String(),
    if (aviso != null) 'aviso': aviso,
  };
}
