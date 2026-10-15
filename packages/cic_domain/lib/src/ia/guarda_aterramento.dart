import '../abc/curva_abc.dart';
import '../estoque/estoque.dart';
import '../estoque/previsao.dart';
import '../tempo/fuso_loja.dart';
import '../tempo/periodo.dart';
import 'resposta_consultor.dart';

/// Tudo o que a IA pode citar: números, produtos, classes e datas que saíram
/// dos serviços determinísticos para ESTE snapshot. O que não estiver aqui é
/// tratado como alucinação.
class ContextoAterramento {
  ContextoAterramento._(this.snapshotVersion);

  final String snapshotVersion;
  final Map<String, String> _nomes = {};
  final Map<String, ClasseAbc> _classes = {};
  final Set<String> _ids = {};
  final Set<int> _centavos = {};
  final _fatosGerais = _FatosNumericos();
  final Map<String, _FatosNumericos> _fatosPorProduto = {};

  /// Números "soltos" em centésimos (12,5 → 1250) para comparar sem float.
  final Set<int> _numeros = {};
  final List<double> _percentuais = [];
  final List<(DataCivil, DataCivil)> _intervalosDatas = [];

  /// [abc] pode trazer vários períodos (ex.: hoje e mês) do mesmo snapshot.
  factory ContextoAterramento.de({
    required String snapshotVersion,
    ResumoEstoque? estoque,
    List<ResultadoCurvaAbc> abc = const [],
    FusoLoja? fuso,
    ResultadoPrevisao? previsao,
  }) {
    final c = ContextoAterramento._(snapshotVersion);
    for (final n in const [1, 7, 30, limiteRupturaUnidades]) {
      c._addNumero(n);
      c._fatosGerais.addNumero(n);
    }
    c._percentuais.addAll(
      const [5, 15, limiteClasseA * 1.0, limiteClasseB * 1.0, 100],
    );
    c._fatosGerais.percentuais.add(100);
    if (estoque != null) {
      for (final n in [
        estoque.produtosCadastrados,
        estoque.produtosComSaldo,
        estoque.produtosSemSaldoConhecido,
        estoque.unidadesFisicas,
        estoque.unidadesDisponiveis,
        estoque.quantidadeLotes,
      ]) {
        c._addNumero(n);
        c._fatosGerais.addNumero(n);
      }
      if (fuso != null) {
        final d = fuso.dataCivilDe(estoque.atualizadoEm);
        c._intervalosDatas.add((d, d));
      }
    }
    for (final r in abc) {
      for (final valor in [
        r.valorLiquidoTotalCentavos,
        r.totalPositivoCentavos,
        r.totalNegativoCentavos,
        r.lucroBrutoTotalCentavos,
      ]) {
        c._addCentavos(valor);
        c._fatosGerais.addCentavos(valor);
      }
      for (final n in [r.itens.length, r.quantidadeTotal]) {
        c._addNumero(n);
        c._fatosGerais.addNumero(n);
      }
      for (final resumo in r.resumoPorClasse.values) {
        c._addNumero(resumo.produtos);
        c._addCentavos(resumo.valorCentavos);
        if (r.totalPositivoCentavos > 0) {
          c._percentuais.add(resumo.valorCentavos * 100 / r.totalPositivoCentavos);
        }
      }
      final janela = r.janela;
      if (janela != null) {
        c._intervalosDatas.add((janela.primeiraData ?? DataCivil(1, 1, 1), janela.ultimaData));
      }
      for (final i in r.itens) {
        c._nomes[i.produtoId] = i.nome;
        c._ids.add(i.produtoId);
        final fatos = c._fatosPorProduto.putIfAbsent(
          i.produtoId, _FatosNumericos.new,
        );
        // A mesma loja pode ter o produto em classes diferentes por período;
        // só guardamos a classe se houver um único resultado.
        if (abc.length == 1) c._classes[i.produtoId] = i.classe;
        c._addNumero(i.posicao);
        c._addNumero(i.quantidade);
        c._addNumero(i.estoqueDisponivel);
        c._addCentavos(i.valorBaseCentavos);
        c._addCentavos(i.custoCentavos);
        c._addCentavos(i.lucroBrutoCentavos);
        fatos.addNumero(i.posicao);
        fatos.addNumero(i.quantidade);
        fatos.addNumero(i.estoqueDisponivel);
        fatos.addCentavos(i.valorBaseCentavos);
        fatos.addCentavos(i.custoCentavos);
        fatos.addCentavos(i.lucroBrutoCentavos);
        // No ABC projetado, valor e custo são preço/custo atuais × unidades.
        // No realizado, o agregado não permite inferir preço unitário.
        if (r.modo == ModoAbc.projetado && i.quantidade > 0) {
          if (i.valorBaseCentavos % i.quantidade == 0) {
            final preco = i.valorBaseCentavos ~/ i.quantidade;
            c._addCentavos(preco);
            fatos.addCentavos(preco);
          }
          final custo = i.custoCentavos;
          if (custo != null && custo % i.quantidade == 0) {
            final unitario = custo ~/ i.quantidade;
            c._addCentavos(unitario);
            fatos.addCentavos(unitario);
          }
        }
        c._percentuais.addAll([
          i.participacaoPercentual,
          i.acumuladoPercentual,
          ?i.margemBrutaPercentual,
          ?i.markupPercentual,
        ]);
        fatos.percentuais.addAll([
          i.participacaoPercentual,
          i.acumuladoPercentual,
          ?i.margemBrutaPercentual,
          ?i.markupPercentual,
        ]);
      }
      for (final a in r.alertas) {
        c._ids.add(a.id);
      }
    }
    if (previsao != null) {
      for (final n in [previsao.diasJanela, previsao.diasAlvo]) {
        c._addNumero(n);
        c._fatosGerais.addNumero(n);
      }
      for (final i in previsao.itens) {
        c._nomes.putIfAbsent(i.produtoId, () => i.nome);
        c._ids.add(i.produtoId);
        c._addNumero(i.estoque);
        c._addNumero(i.vendidosNoPeriodo);
        c._addNumero(i.coberturaDias);
        c._addNumero(i.reposicaoSugerida);
        c._numeros.add(i.mediaDiariaCentesimos); // ex.: 1,25 un/dia
        final fatos = c._fatosPorProduto.putIfAbsent(
          i.produtoId, _FatosNumericos.new,
        );
        fatos.addNumero(i.estoque);
        fatos.addNumero(i.vendidosNoPeriodo);
        fatos.addNumero(i.coberturaDias);
        fatos.addNumero(i.reposicaoSugerida);
        fatos.numeros.add(i.mediaDiariaCentesimos);
      }
    }
    return c;
  }

  void _addNumero(int? n) {
    if (n != null) _numeros.add(n * 100);
  }

  void _addCentavos(int? centavos) {
    if (centavos == null) return;
    _centavos.add(centavos);
    _numeros.add(centavos); // "700 reais" ou "700,50" sem o R$.
  }

  bool _percentualPermitido(double p, int casas) {
    final tolerancia = 0.5 / _pow10(casas) + 1e-9;
    return _percentuais.any((x) => (x - p).abs() <= tolerancia);
  }

  bool _dataPermitida(DataCivil d) =>
      _intervalosDatas.any((i) => d.compareTo(i.$1) >= 0 && d.compareTo(i.$2) <= 0);
}

class _FatosNumericos {
  final Set<int> numeros = {};
  final Set<int> centavos = {};
  final List<double> percentuais = [];

  void addNumero(int? valor) {
    if (valor != null) numeros.add(valor * 100);
  }

  void addCentavos(int? valor) {
    if (valor == null) return;
    centavos.add(valor);
    numeros.add(valor);
  }

  bool permitePercentual(double valor, int casas) {
    final tolerancia = 0.5 / _pow10(casas) + 1e-9;
    return percentuais.any((p) => (p - valor).abs() <= tolerancia);
  }
}

int _pow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

final _reData = RegExp(r'\b(\d{1,2})/(\d{1,2})/(\d{4})\b');
final _reDinheiro = RegExp(r'(-?)\s*R\$\s*(-?)(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{1,2}))?');
final _rePercentual = RegExp(r'(-?\d+)(?:,(\d+))?\s*%');
final _reNumero = RegExp(r'(?<![\w,])(-?)(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d+))?(?![\d%]|,\d)');
final _reSentenca = RegExp(r'[.!?](\s|$)');
final _reItemLista = RegExp(r'^\s*(?:[-•*]|\d+[.)])\s+', multiLine: true);
final _reLimiteFrase = RegExp(r'(?<=[.!?;])\s+|\n+');

RegExp _padraoNome(String nome) => RegExp(
  r'(?<![\p{L}\p{N}_])' +
      RegExp.escape(nome.replaceAll(' ', ' ')) +
      r'(?![\p{L}\p{N}_])',
  caseSensitive: false,
  unicode: true,
);

void _verificarFatosDaFrase(
  String frase,
  ContextoAterramento ctx,
  List<String> violacoes,
) {
  final citados = <String>{};
  var semNomes = frase.replaceAll(' ', ' ');
  final nomes = ctx._nomes.entries.where((e) => e.value.trim().isNotEmpty).toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));
  for (final entrada in nomes) {
    final padrao = _padraoNome(entrada.value);
    for (final m in padrao.allMatches(semNomes)) {
      citados.add(entrada.key);
      final classe = ctx._classes[entrada.key];
      if (classe != null) {
        final antes = semNomes.substring(0, m.start);
        final rotulo = RegExp(
          r'\b(?:classe|curva)\s+([abc])\s*[:\-]?\s*$',
          caseSensitive: false,
        ).firstMatch(antes);
        if (rotulo != null && rotulo[1]!.toUpperCase() != classe.name) {
          violacoes.add(
            '${entrada.value} citado como ${rotulo[1]!.toUpperCase()}, calculado ${classe.name}',
          );
        }
      }
    }
    semNomes = semNomes.replaceAll(padrao, ' ');
  }
  if (citados.isEmpty) return;

  bool permiteNumero(int valor) =>
      ctx._fatosGerais.numeros.contains(valor) ||
      citados.any((id) => ctx._fatosPorProduto[id]?.numeros.contains(valor) ?? false);
  bool permiteCentavos(int valor) =>
      ctx._fatosGerais.centavos.contains(valor) ||
      citados.any((id) => ctx._fatosPorProduto[id]?.centavos.contains(valor) ?? false);
  bool permitePercentual(double valor, int casas) =>
      ctx._fatosGerais.permitePercentual(valor, casas) ||
      citados.any((id) =>
          ctx._fatosPorProduto[id]?.permitePercentual(valor, casas) ?? false);

  var texto = semNomes.replaceAll('−', '-').replaceAll(_reData, ' ');
  texto = texto.replaceAllMapped(_reDinheiro, (m) {
    final negativo = m[1] == '-' || m[2] == '-';
    final reais = int.parse(m[3]!.replaceAll('.', ''));
    final centavos = int.parse((m[4] ?? '0').padRight(2, '0'));
    final valor = (reais * 100 + centavos) * (negativo ? -1 : 1);
    if (ctx._centavos.contains(valor) && !permiteCentavos(valor)) {
      violacoes.add('número de outro produto: ${m[0]!.trim()}');
    }
    return ' ';
  });
  texto = texto.replaceAllMapped(_rePercentual, (m) {
    final casas = m[2]?.length ?? 0;
    final percentual = double.parse('${m[1]}.${m[2] ?? '0'}');
    if (ctx._percentualPermitido(percentual, casas) &&
        !permitePercentual(percentual, casas)) {
      violacoes.add('número de outro produto: ${m[0]}');
    }
    return ' ';
  });
  for (final m in _reNumero.allMatches(texto)) {
    final decimais = m[3] ?? '';
    if (decimais.length > 2) continue; // Já é rejeitado pela checagem global.
    final inteiro = int.parse(m[2]!.replaceAll('.', ''));
    final valor = (inteiro * 100 + int.parse(decimais.padRight(2, '0'))) *
        (m[1] == '-' ? -1 : 1);
    if (ctx._numeros.contains(valor) && !permiteNumero(valor)) {
      violacoes.add('número de outro produto: ${m[0]}');
    }
  }
}

/// Confere a resposta da IA contra o contexto calculado. Lista vazia = ok.
List<String> verificarAterramento(RespostaConsultor r, ContextoAterramento ctx) {
  final violacoes = <String>[];
  if (r.snapshotVersion != ctx.snapshotVersion) {
    violacoes.add('snapshot ${r.snapshotVersion} difere do atual ${ctx.snapshotVersion}');
  }
  for (final f in r.fontes) {
    if (!ctx._ids.contains(f)) violacoes.add('fonte inexistente: $f');
  }
  for (final e in r.metricas.entries) {
    final centesimos = (e.value * 100).round();
    if (!ctx._numeros.contains(centesimos) &&
        !ctx._centavos.contains(e.value) &&
        !ctx._percentualPermitido(e.value.toDouble(), 2)) {
      violacoes.add('métrica ${e.key}=${e.value} não calculada');
    }
  }

  for (final frase in r.resposta.split(_reLimiteFrase)) {
    _verificarFatosDaFrase(frase, ctx, violacoes);
  }

  var texto = r.resposta.replaceAll(' ', ' ');
  // Embalagens fazem parte do nome (ex.: Café 500g), não são afirmações
  // quantitativas. Remover nomes inteiros, maiores primeiro, sem esconder
  // números de produtos desconhecidos ou de palavras apenas parecidas.
  final nomes = ctx._nomes.values.where((n) => n.trim().isNotEmpty).toSet().toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final nome in nomes) {
    texto = texto.replaceAll(_padraoNome(nome), ' ');
  }
  texto = texto.replaceAll('−', '-');
  texto = texto.replaceAllMapped(_reData, (m) {
    final d = DataCivil(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    final normalizada = DateTime.utc(d.ano, d.mes, d.dia);
    if (normalizada.year != d.ano || normalizada.month != d.mes || normalizada.day != d.dia) {
      violacoes.add('data inexistente: ${m[0]}');
      return ' ';
    }
    if (!ctx._dataPermitida(d)) violacoes.add('data fora do snapshot: ${m[0]}');
    return ' ';
  });
  texto = texto.replaceAllMapped(_reDinheiro, (m) {
    final negativo = m[1] == '-' || m[2] == '-';
    final reais = int.parse(m[3]!.replaceAll('.', ''));
    final cents = int.parse((m[4] ?? '0').padRight(2, '0'));
    final valor = (reais * 100 + cents) * (negativo ? -1 : 1);
    if (!ctx._centavos.contains(valor)) violacoes.add('valor não calculado: ${m[0]!.trim()}');
    return ' ';
  });
  texto = texto.replaceAllMapped(_rePercentual, (m) {
    final casas = m[2]?.length ?? 0;
    final p = double.parse('${m[1]}.${m[2] ?? '0'}');
    if (!ctx._percentualPermitido(p, casas)) violacoes.add('percentual não calculado: ${m[0]}');
    return ' ';
  });
  for (final m in _reNumero.allMatches(texto)) {
    final inteiro = int.parse(m[2]!.replaceAll('.', ''));
    final dec = m[3] ?? '';
    // Mais de 2 casas decimais nunca vem dos serviços.
    final centesimos = dec.length > 2
        ? null
        : (inteiro * 100 + int.parse(dec.padRight(2, '0'))) * (m[1] == '-' ? -1 : 1);
    if (centesimos == null || !ctx._numeros.contains(centesimos)) {
      violacoes.add('número não calculado: ${m[0]}');
    }
  }

  // Produto citado com classe diferente da calculada.
  final minusculo = r.resposta.toLowerCase();
  ctx._classes.forEach((id, classe) {
    final nome = ctx._nomes[id]!.toLowerCase();
    if (nome.length < 3) return;
    for (var i = minusculo.indexOf(nome); i >= 0; i = minusculo.indexOf(nome, i + 1)) {
      final fim = (i + nome.length + 40).clamp(0, minusculo.length);
      final trecho = minusculo.substring(i + nome.length, fim);
      final m = RegExp(r'^[^.;\n]*?\b(?:classe|curva)\s+([abc])\b').firstMatch(trecho);
      if (m != null && m[1]!.toUpperCase() != classe.name) {
        violacoes.add(
          '${ctx._nomes[id]} citado como ${m[1]!.toUpperCase()}, calculado ${classe.name}',
        );
      }
    }
  });

  // Política de tamanho.
  if (r.tipo == TipoResposta.objetiva && _reSentenca.allMatches(r.resposta.trim()).length > 2) {
    violacoes.add('resposta objetiva com mais de duas frases');
  }
  if (r.tipo == TipoResposta.lista && _reItemLista.allMatches(r.resposta).length > 5) {
    violacoes.add('lista inicial com mais de cinco itens');
  }
  return violacoes;
}

/// Dados enviados ao backend `/api/ia/*`. Sem tenantId: o servidor usa a loja
/// autenticada e reconcilia com a persistência; estes números servem de
/// contexto, não de fonte financeira autoritativa.
class ConsultaIa {
  const ConsultaIa({
    required this.pergunta,
    required this.periodo,
    required this.fuso,
    required this.snapshotVersion,
    required this.atualizadoEm,
    required this.demonstracao,
    this.estoque,
    this.abc,
    this.previsao,
  });

  final String pergunta;
  final PeriodoAbc periodo;
  final String fuso;
  final String snapshotVersion;
  final DateTime atualizadoEm;
  final bool demonstracao;
  final ResumoEstoque? estoque;
  final ResultadoCurvaAbc? abc;
  final ResultadoPrevisao? previsao;

  Map<String, Object?> toJson() => {
    'versaoContrato': versaoContratoIa,
    'pergunta': pergunta,
    'periodo': periodo.codigo,
    'timezone': fuso,
    'snapshotVersion': snapshotVersion,
    'atualizadoEm': atualizadoEm.toIso8601String(),
    'demonstracao': demonstracao,
    'metricas': {
      if (estoque != null) 'estoque': estoque!.toJson(),
      if (abc != null) 'curvaAbc': abc!.toJson(),
    },
    if (previsao != null) 'previsao': previsao!.toJson(),
    'qualidade': {
      'estoqueCompleto': estoque?.completo,
      'problemas': [
        ...?estoque?.problemas.map((p) => p.toJson()),
        ...?abc?.problemas.map((p) => p.toJson()),
      ],
    },
  };
}
