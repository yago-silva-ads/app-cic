import '../abc/curva_abc.dart';
import '../dinheiro.dart';
import '../estoque/estoque.dart';
import '../tempo/periodo.dart';
import 'erros_ia.dart';
import 'guarda_aterramento.dart';
import 'resposta_consultor.dart';

String _rotuloPeriodo(PeriodoAbc p) => switch (p) {
  PeriodoAbc.hoje => 'hoje',
  PeriodoAbc.seteDias => 'nos últimos 7 dias',
  PeriodoAbc.mes => 'nos últimos 30 dias',
  PeriodoAbc.todos => 'em todo o histórico',
  PeriodoAbc.projetado => 'no cenário projetado do estoque atual',
};

String _plural(int n, String singular, String plural) =>
    '${formatarInteiro(n)} ${n == 1 ? singular : plural}';

/// Respostas para perguntas objetivas, calculadas sem IA. Funcionam com o
/// provedor fora do ar e servem de fallback seguro.
class RespostasDeterministicas {
  const RespostasDeterministicas();

  RespostaConsultor estoqueAtual(ResumoEstoque e) {
    final ausentes = <String>[
      if (!e.completo)
        'Saldo desconhecido de ${_plural(e.produtosSemSaldoConhecido, 'produto', 'produtos')}',
    ];
    final texto = StringBuffer(
      'Você tem ${_plural(e.produtosComSaldo, 'produto', 'produtos')} com saldo e '
      '${_plural(e.unidadesDisponiveis, 'unidade disponível', 'unidades disponíveis')}; '
      '${formatarInteiro(e.produtosCadastrados)} cadastrados.',
    );
    if (!e.completo) texto.write(' ${ausentes.first}, então o total é parcial.');
    return RespostaConsultor(
      resposta: texto.toString(),
      tipo: TipoResposta.objetiva,
      origem: OrigemResposta.deterministica,
      snapshotVersion: e.snapshotVersion,
      atualizadoEm: e.atualizadoEm,
      metricas: {
        'produtosComSaldo': e.produtosComSaldo,
        'unidadesDisponiveis': e.unidadesDisponiveis,
        'produtosCadastrados': e.produtosCadastrados,
      },
      dadosAusentes: ausentes,
    );
  }

  /// Receita REALIZADA. Nunca troca em silêncio para o projetado.
  RespostaConsultor faturamento(ResultadoCurvaAbc r) {
    _exigirRealizado(r);
    final rotulo = _rotuloPeriodo(r.periodo);
    final unidades = r.quantidadeTotal;
    final texto = r.semMovimento
        ? 'Não há vendas registradas $rotulo. Quer ver outro período?'
        : 'Você faturou ${formatarCentavos(r.valorLiquidoTotalCentavos)} $rotulo, '
              'em ${_plural(unidades, 'unidade vendida', 'unidades vendidas')}.';
    return _resposta(
      r,
      texto,
      TipoResposta.objetiva,
      metricas: {'receitaLiquidaCentavos': r.valorLiquidoTotalCentavos, 'unidades': unidades},
    );
  }

  RespostaConsultor maisVendido(ResultadoCurvaAbc r) {
    _exigirRealizado(r);
    final rotulo = _rotuloPeriodo(r.periodo);
    final comVenda = r.itens.where((i) => i.quantidade > 0).toList();
    if (comVenda.isEmpty) {
      return _resposta(r, 'Não há vendas registradas $rotulo.', TipoResposta.objetiva);
    }
    final porValor = r.itens.first;
    final porUnidades =
        ([...comVenda]..sort((a, b) {
              final c = b.quantidade.compareTo(a.quantidade);
              return c != 0 ? c : a.produtoId.compareTo(b.produtoId);
            }))
            .first;
    final texto = porValor.produtoId == porUnidades.produtoId
        ? '${porValor.nome} foi o mais vendido $rotulo: '
              '${_plural(porValor.quantidade, 'unidade', 'unidades')} e '
              '${formatarCentavos(porValor.valorBaseCentavos)}.'
        : 'Em faturamento, ${porValor.nome} lidera $rotulo com '
              '${formatarCentavos(porValor.valorBaseCentavos)}. '
              'Em unidades, ${porUnidades.nome} lidera com '
              '${_plural(porUnidades.quantidade, 'unidade', 'unidades')}.';
    return _resposta(
      r,
      texto,
      TipoResposta.objetiva,
      fontes: {porValor.produtoId, porUnidades.produtoId}.toList(),
    );
  }

  RespostaConsultor resumoAbc(ResultadoCurvaAbc r) {
    final resumo = r.resumoPorClasse;
    String classe(ClasseAbc c) =>
        '${c.name}: ${_plural(resumo[c]!.produtos, 'produto', 'produtos')}';
    final prefixo = r.modo == ModoAbc.projetado
        ? 'Curva ABC projetada (teórica, pelo estoque atual)'
        : 'Curva ABC ${_rotuloPeriodo(r.periodo)}';
    final texto = r.totalPositivoCentavos == 0
        ? '$prefixo: sem valor positivo no período, todos os produtos ficam em C.'
        : '$prefixo: ${ClasseAbc.values.map(classe).join(', ')}. '
              'Base: ${formatarCentavos(r.totalPositivoCentavos)}.';
    return _resposta(r, texto, TipoResposta.objetiva);
  }

  RespostaConsultor produtosAcabando(ResultadoCurvaAbc r, {int limite = 5}) {
    final alertas = r.alertas;
    if (alertas.isEmpty) {
      return _resposta(
        r,
        'Nenhum produto classe A está com 5 unidades ou menos.',
        TipoResposta.objetiva,
      );
    }
    final linhas = [for (final a in alertas.take(limite)) '- ${a.acao}'];
    final resto = alertas.length - linhas.length;
    final texto = [
      if (r.modo == ModoAbc.projetado) 'Pela classificação teórica do estoque:',
      ...linhas,
      if (resto > 0) 'Mais $resto em "Ver detalhes".',
    ].join('\n');
    return _resposta(
      r,
      texto,
      TipoResposta.lista,
      alertas: [for (final a in alertas) a.id],
      fontes: [for (final a in alertas) a.produtoId],
    );
  }

  void _exigirRealizado(ResultadoCurvaAbc r) {
    if (r.modo != ModoAbc.realizado) {
      throw ArgumentError('Receita e mais vendido usam apenas o realizado');
    }
  }

  RespostaConsultor _resposta(
    ResultadoCurvaAbc r,
    String texto,
    TipoResposta tipo, {
    Map<String, num> metricas = const {},
    List<String> fontes = const [],
    List<String> alertas = const [],
  }) => RespostaConsultor(
    resposta: texto,
    tipo: tipo,
    origem: OrigemResposta.deterministica,
    periodo: r.periodo.codigo,
    snapshotVersion: r.snapshotVersion,
    atualizadoEm: r.atualizadoEm,
    metricas: metricas,
    fontes: fontes,
    alertas: alertas,
    dadosAusentes: [
      for (final p in r.problemas)
        '${p.codigo.name}${p.produtoId == null ? '' : ':${p.produtoId}'}',
    ],
  );
}

/// Registro de uma chamada, sem chaves nem dados pessoais.
class RegistroChamadaIa {
  const RegistroChamadaIa({
    required this.requestId,
    required this.duracao,
    required this.origem,
    this.erro,
  });

  final String requestId;
  final Duration duracao;
  final OrigemResposta origem;
  final String? erro;
}

/// Descarta respostas que chegam fora de ordem: só a última pergunta vale.
class ControleRequisicoes {
  int _atual = 0;

  int iniciar() => ++_atual;

  bool ehAtual(int token) => token == _atual;
}

/// Chama a IA, valida schema e aterramento e, em qualquer falha, devolve o
/// [fallback] calculado com aviso visível. Nunca devolve número da IA que não
/// esteja no [contexto].
class ConsultorSeguro {
  const ConsultorSeguro({this.politica = const PoliticaRetentativa()});

  final PoliticaRetentativa politica;

  Future<RespostaConsultor> responder({
    required String requestId,
    required Future<Object?> Function() chamarIa,
    required ContextoAterramento contexto,
    required RespostaConsultor fallback,
    void Function(RegistroChamadaIa)? registrar,
    Future<void> Function(Duration)? esperar,
  }) async {
    final cronometro = Stopwatch()..start();
    try {
      final json = esperar == null
          ? await politica.executar(chamarIa)
          : await politica.executar(chamarIa, esperar: esperar);
      final RespostaConsultor resposta;
      try {
        resposta = RespostaConsultor.daIa(json);
      } on FormatException catch (e) {
        throw RespostaInvalidaIa(e.message);
      }
      final violacoes = verificarAterramento(resposta, contexto);
      if (violacoes.isNotEmpty) throw RespostaNaoAterradaIa(violacoes);
      registrar?.call(
        RegistroChamadaIa(
          requestId: requestId,
          duracao: cronometro.elapsed,
          origem: OrigemResposta.ia,
        ),
      );
      return resposta;
    } on ErroIa catch (e) {
      registrar?.call(
        RegistroChamadaIa(
          requestId: requestId,
          duracao: cronometro.elapsed,
          origem: OrigemResposta.fallbackSeguro,
          erro: e.toString(),
        ),
      );
      return fallback.comAviso(
        '${e.mensagemUsuario} Mostrando só os dados calculados.',
        origem: OrigemResposta.fallbackSeguro,
      );
    }
  }
}
