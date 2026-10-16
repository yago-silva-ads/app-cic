import 'dart:async';

/// Falhas do consultor de IA. Cada uma tem mensagem curta para o usuário e
/// diz se vale retentar. Erro nunca deve parecer sucesso.
sealed class ErroIa implements Exception {
  const ErroIa(this.detalheTecnico);

  /// Para log (sem chaves nem dados pessoais).
  final String detalheTecnico;

  String get mensagemUsuario;
  bool get podeRetentar;

  /// Mapeia status HTTP do backend `/api/ia/*`.
  static ErroIa deStatusHttp(int status, {Duration? retryAfter}) => switch (status) {
    408 || 504 => TempoEsgotadoIa('HTTP $status'),
    429 => LimiteRequisicoesIa('HTTP 429', retryAfter: retryAfter),
    502 || 503 => ProvedorIndisponivelIa('HTTP $status'),
    _ => ProvedorIndisponivelIa('HTTP $status', retentavel: false),
  };

  @override
  String toString() => '$runtimeType($detalheTecnico)';
}

class TempoEsgotadoIa extends ErroIa {
  const TempoEsgotadoIa(super.detalheTecnico);

  @override
  String get mensagemUsuario => 'O consultor demorou demais para responder. Tente de novo.';

  @override
  bool get podeRetentar => true;
}

class LimiteRequisicoesIa extends ErroIa {
  const LimiteRequisicoesIa(super.detalheTecnico, {this.retryAfter});

  final Duration? retryAfter;

  @override
  String get mensagemUsuario => 'Muitas perguntas seguidas. Aguarde alguns segundos.';

  @override
  bool get podeRetentar => true;
}

class ProvedorIndisponivelIa extends ErroIa {
  const ProvedorIndisponivelIa(super.detalheTecnico, {this.retentavel = true});

  final bool retentavel;

  @override
  String get mensagemUsuario => 'O consultor de IA está indisponível agora.';

  @override
  bool get podeRetentar => retentavel;
}

class SemConexaoIa extends ErroIa {
  const SemConexaoIa(super.detalheTecnico);

  @override
  String get mensagemUsuario => 'Sem conexão com o servidor. Verifique a internet.';

  @override
  bool get podeRetentar => true;
}

/// JSON fora do contrato. Não adianta retentar a mesma pergunta às cegas.
class RespostaInvalidaIa extends ErroIa {
  const RespostaInvalidaIa(super.detalheTecnico);

  @override
  String get mensagemUsuario => 'O consultor respondeu em formato inválido.';

  @override
  bool get podeRetentar => false;
}

/// A IA citou número, produto ou classe que não existe no resultado calculado.
class RespostaNaoAterradaIa extends ErroIa {
  RespostaNaoAterradaIa(this.violacoes) : super(violacoes.join('; '));

  final List<String> violacoes;

  @override
  String get mensagemUsuario =>
      'A resposta do consultor não bateu com os dados calculados e foi descartada.';

  @override
  bool get podeRetentar => false;
}

/// Retentativas limitadas com backoff, só para erros retentáveis.
class PoliticaRetentativa {
  const PoliticaRetentativa({
    this.maxTentativas = 3,
    this.atrasoBase = const Duration(milliseconds: 800),
    this.timeoutPorTentativa = const Duration(seconds: 20),
  });

  final int maxTentativas;
  final Duration atrasoBase;
  final Duration timeoutPorTentativa;

  Future<T> executar<T>(
    Future<T> Function() chamada, {
    Future<void> Function(Duration) esperar = _esperarReal,
  }) async {
    for (var tentativa = 1; ; tentativa++) {
      try {
        return await chamada().timeout(timeoutPorTentativa);
      } on TimeoutException {
        if (tentativa >= maxTentativas) throw const TempoEsgotadoIa('timeout local');
      } on ErroIa catch (e) {
        if (!e.podeRetentar || tentativa >= maxTentativas) rethrow;
        if (e is LimiteRequisicoesIa && e.retryAfter != null) {
          await esperar(e.retryAfter!);
          continue;
        }
      }
      await esperar(atrasoBase * (1 << (tentativa - 1)));
    }
  }

  static Future<void> _esperarReal(Duration d) => Future<void>.delayed(d);
}
