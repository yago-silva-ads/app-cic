import '../estoque/estoque.dart';
import '../qualidade.dart';
import '../tempo/fuso_loja.dart';
import '../tempo/periodo.dart';
import '../vendas/apuracao.dart';
import '../vendas/eventos.dart';

const String versaoContratoAbc = 'abc-v1';

/// Limites da classificação, em percentual inteiro. Comparação exata por
/// multiplicação cruzada; nunca por percentual arredondado.
const int limiteClasseA = 80;
const int limiteClasseB = 95;

/// Estoque disponível igual ou abaixo deste valor gera alerta para classe A.
const int limiteRupturaUnidades = 5;

enum ClasseAbc { A, B, C }

enum ModoAbc { realizado, projetado }

/// Classe pelo acumulado ANTES do item: o item que atravessa um limite fica
/// na faixa em que começou. Total positivo zero → C (sem divisão por zero).
ClasseAbc classificar({required int acumuladoAntes, required int totalPositivo}) {
  if (totalPositivo <= 0) return ClasseAbc.C;
  if (acumuladoAntes * 100 < limiteClasseA * totalPositivo) return ClasseAbc.A;
  if (acumuladoAntes * 100 < limiteClasseB * totalPositivo) return ClasseAbc.B;
  return ClasseAbc.C;
}

class ItemCurvaAbc {
  const ItemCurvaAbc({
    required this.posicao,
    required this.produtoId,
    required this.nome,
    required this.arquivado,
    required this.quantidade,
    required this.valorBaseCentavos,
    required this.custoCentavos,
    required this.lucroBrutoCentavos,
    required this.acumuladoAntesCentavos,
    required this.acumuladoDepoisCentavos,
    required this.totalPositivoCentavos,
    required this.classe,
    required this.estoqueDisponivel,
    required this.valorCompleto,
  });

  final int posicao;
  final String produtoId;
  final String nome;
  final bool arquivado;

  /// Realizado: quantidade vendida líquida. Projetado: estoque disponível.
  final int quantidade;

  /// Realizado: receita líquida. Projetado: faturamento potencial.
  final int valorBaseCentavos;

  /// CMV (realizado) ou custo atual do estoque (projetado). `null` = ausente.
  final int? custoCentavos;
  final int? lucroBrutoCentavos;
  final int acumuladoAntesCentavos;
  final int acumuladoDepoisCentavos;
  final int totalPositivoCentavos;
  final ClasseAbc classe;

  /// `null` = estoque desconhecido (não é zero).
  final int? estoqueDisponivel;

  /// Falso se o valor base está subestimado por preço histórico ausente.
  final bool valorCompleto;

  /// Contribuição usada no ABC: receitas zero/negativas não contam.
  int get contribuicaoCentavos => valorBaseCentavos > 0 ? valorBaseCentavos : 0;

  /// Participação no faturamento (%). Antigo `percentualGiro` — não é giro de
  /// estoque. Só para exibição.
  double get participacaoPercentual =>
      totalPositivoCentavos == 0 ? 0 : contribuicaoCentavos * 100 / totalPositivoCentavos;

  double get acumuladoPercentual =>
      totalPositivoCentavos == 0 ? 0 : acumuladoDepoisCentavos * 100 / totalPositivoCentavos;

  /// Margem bruta = lucro / receita × 100, só com receita > 0 e custo conhecido.
  double? get margemBrutaPercentual {
    final lucro = lucroBrutoCentavos;
    if (lucro == null || valorBaseCentavos <= 0) return null;
    return lucro * 100 / valorBaseCentavos;
  }

  /// Markup = lucro / custo × 100. Não confundir com margem.
  double? get markupPercentual {
    final lucro = lucroBrutoCentavos;
    final custo = custoCentavos;
    if (lucro == null || custo == null || custo <= 0) return null;
    return lucro * 100 / custo;
  }

  Map<String, Object?> toJson() => {
    'posicao': posicao,
    'produtoId': produtoId,
    'nome': nome,
    'arquivado': arquivado,
    'quantidade': quantidade,
    'valorBaseCentavos': valorBaseCentavos,
    'custoCentavos': custoCentavos,
    'lucroBrutoCentavos': lucroBrutoCentavos,
    'acumuladoAntesCentavos': acumuladoAntesCentavos,
    'acumuladoDepoisCentavos': acumuladoDepoisCentavos,
    'classe': classe.name,
    'estoqueDisponivel': estoqueDisponivel,
    'valorCompleto': valorCompleto,
  };
}

class AlertaRuptura {
  const AlertaRuptura({
    required this.produtoId,
    required this.nome,
    required this.estoqueDisponivel,
    required this.periodo,
    required this.teorico,
  });

  final String produtoId;
  final String nome;
  final int estoqueDisponivel;
  final PeriodoAbc periodo;

  /// Verdadeiro no projetado: classificação teórica, não campeão de vendas.
  final bool teorico;

  /// Estável por produto+período: o mesmo alerta não duplica a cada render.
  String get id => 'ruptura:$produtoId:${periodo.codigo}';

  String get acao => estoqueDisponivel <= 0
      ? 'Repor $nome com urgência: sem saldo disponível.'
      : 'Repor $nome: restam $estoqueDisponivel unidades.';

  Map<String, Object?> toJson() => {
    'id': id,
    'produtoId': produtoId,
    'nome': nome,
    'estoqueDisponivel': estoqueDisponivel,
    'periodo': periodo.codigo,
    'teorico': teorico,
    'acao': acao,
  };
}

class ResumoClasse {
  const ResumoClasse(this.produtos, this.valorCentavos);

  final int produtos;
  final int valorCentavos;

  Map<String, Object?> toJson() => {'produtos': produtos, 'valorCentavos': valorCentavos};
}

class ResultadoCurvaAbc {
  const ResultadoCurvaAbc({
    required this.modo,
    required this.periodo,
    required this.janela,
    required this.fuso,
    required this.snapshotVersion,
    required this.atualizadoEm,
    required this.geradoEm,
    required this.demonstracao,
    required this.itens,
    required this.alertas,
    required this.problemas,
  });

  final String versaoContrato = versaoContratoAbc;
  final ModoAbc modo;
  final PeriodoAbc periodo;

  /// `null` no projetado.
  final JanelaPeriodo? janela;
  final String fuso;
  final String snapshotVersion;
  final DateTime atualizadoEm;
  final DateTime geradoEm;
  final bool demonstracao;
  final List<ItemCurvaAbc> itens;
  final List<AlertaRuptura> alertas;
  final List<ProblemaDados> problemas;

  /// Receita líquida total (pode ser menor que o denominador ABC por estornos).
  int get valorLiquidoTotalCentavos => itens.fold(0, (s, i) => s + i.valorBaseCentavos);

  /// Realizado: unidades vendidas líquidas. Projetado: unidades disponíveis.
  int get quantidadeTotal => itens.fold(0, (s, i) => s + i.quantidade);

  /// Denominador ABC: soma só das contribuições positivas.
  int get totalPositivoCentavos => itens.fold(0, (s, i) => s + i.contribuicaoCentavos);

  /// Soma dos valores negativos (estornos acima da receita), reportada à parte.
  int get totalNegativoCentavos =>
      itens.fold(0, (s, i) => s + (i.valorBaseCentavos < 0 ? i.valorBaseCentavos : 0));

  /// `null` se algum item com valor tem custo ausente: lucro não é inventado.
  int? get lucroBrutoTotalCentavos {
    var total = 0;
    for (final i in itens) {
      if (i.valorBaseCentavos == 0 && i.quantidade == 0) continue;
      final l = i.lucroBrutoCentavos;
      if (l == null) return null;
      total += l;
    }
    return total;
  }

  bool get semMovimento =>
      modo == ModoAbc.realizado &&
      itens.every((i) => i.quantidade == 0 && i.valorBaseCentavos == 0);

  Map<ClasseAbc, ResumoClasse> get resumoPorClasse => {
    for (final c in ClasseAbc.values)
      c: ResumoClasse(
        itens.where((i) => i.classe == c).length,
        itens.where((i) => i.classe == c).fold(0, (s, i) => s + i.contribuicaoCentavos),
      ),
  };

  Map<String, Object?> toJson() => {
    'versaoContrato': versaoContrato,
    'modo': modo.name,
    'periodo': periodo.codigo,
    'janela': janela?.toJson(),
    'fuso': fuso,
    'snapshotVersion': snapshotVersion,
    'atualizadoEm': atualizadoEm.toIso8601String(),
    'geradoEm': geradoEm.toIso8601String(),
    'demonstracao': demonstracao,
    'quantidadeTotal': quantidadeTotal,
    'valorLiquidoTotalCentavos': valorLiquidoTotalCentavos,
    'totalPositivoCentavos': totalPositivoCentavos,
    'totalNegativoCentavos': totalNegativoCentavos,
    'lucroBrutoTotalCentavos': lucroBrutoTotalCentavos,
    'resumoPorClasse': {for (final e in resumoPorClasse.entries) e.key.name: e.value.toJson()},
    'itens': [for (final i in itens) i.toJson()],
    'alertas': [for (final a in alertas) a.toJson()],
    'problemas': [for (final p in problemas) p.toJson()],
  };
}

class CurvaAbcService {
  CurvaAbcService({required this.fuso, required this.relogio});

  final FusoLoja fuso;
  final Relogio relogio;
  final _estoque = const EstoqueService();
  final _apuracao = const ApuracaoRealizado();

  ResultadoCurvaAbc calcular({
    required PeriodoAbc periodo,
    required SnapshotEstoque estoque,
    Iterable<EventoComercial> eventos = const [],
  }) => periodo.ehRealizado ? _realizado(periodo, estoque, eventos) : _projetado(estoque);

  ResultadoCurvaAbc _realizado(
    PeriodoAbc periodo,
    SnapshotEstoque estoque,
    Iterable<EventoComercial> eventos,
  ) {
    final janela = JanelaPeriodo.resolver(periodo: periodo, fuso: fuso, relogio: relogio);
    final apuracao = _apuracao.apurar(eventos, janela);
    final saldos = _estoque.saldos(estoque);
    final problemas = [...apuracao.problemas];

    final linhas = <_Linha>[];
    // Produtos ativos entram mesmo sem venda (ficam C). Arquivados e excluídos
    // do cadastro só entram se tiveram vendas, preservando a identidade.
    final ids = <String>{
      for (final p in estoque.produtos)
        if (!p.arquivado) p.id,
      ...apuracao.porProduto.keys,
    };
    for (final id in ids) {
      final saldo = saldos[id];
      final fato = apuracao.porProduto[id];
      final receita = fato?.receitaLiquidaCentavos ?? 0;
      final cmvOk = fato?.cmvCompleto ?? true;
      final cmv = fato?.cmvCentavos ?? 0;
      linhas.add(
        _Linha(
          produtoId: id,
          nome: saldo?.produto.nome ?? fato?.nomeHistorico ?? id,
          arquivado: saldo?.produto.arquivado ?? true,
          quantidade: fato?.quantidadeLiquida ?? 0,
          valor: receita,
          custo: cmvOk ? cmv : null,
          lucro: cmvOk ? receita - cmv : null,
          estoque: saldo?.disponivel,
          valorCompleto: fato?.receitaCompleta ?? true,
        ),
      );
    }
    // Faturamento líquido desc, quantidade líquida desc, ID asc.
    linhas.sort((a, b) {
      var c = b.valor.compareTo(a.valor);
      if (c != 0) return c;
      c = b.quantidade.compareTo(a.quantidade);
      return c != 0 ? c : a.produtoId.compareTo(b.produtoId);
    });
    return _montar(ModoAbc.realizado, periodo, janela, estoque, linhas, problemas);
  }

  ResultadoCurvaAbc _projetado(SnapshotEstoque estoque) {
    final problemas = <ProblemaDados>[];
    final linhas = <_Linha>[];
    for (final s in _estoque.saldos(estoque).values) {
      final p = s.produto;
      if (p.arquivado) continue;
      final disp = s.disponivel;
      final preco = p.precoVendaAtualCentavos;
      if (disp == null) {
        problemas.add(ProblemaDados(CodigoQualidade.estoqueDesconhecido, produtoId: p.id));
      } else if (preco == null) {
        problemas.add(ProblemaDados(CodigoQualidade.precoAtualAusente, produtoId: p.id));
      }
      final qtd = disp != null && disp > 0 ? disp : 0;
      final custoAtual = p.custoAtualCentavos;
      if (custoAtual == null && qtd > 0) {
        problemas.add(ProblemaDados(CodigoQualidade.custoAtualAusente, produtoId: p.id));
      }
      final valor = preco == null ? 0 : qtd * preco;
      final custo = custoAtual == null ? null : qtd * custoAtual;
      linhas.add(
        _Linha(
          produtoId: p.id,
          nome: p.nome,
          arquivado: false,
          quantidade: qtd,
          valor: valor,
          custo: custo,
          lucro: custo == null ? null : valor - custo,
          estoque: disp,
          valorCompleto: disp != null && preco != null,
        ),
      );
    }
    linhas.sort((a, b) {
      final c = b.valor.compareTo(a.valor);
      return c != 0 ? c : a.produtoId.compareTo(b.produtoId);
    });
    return _montar(ModoAbc.projetado, PeriodoAbc.projetado, null, estoque, linhas, problemas);
  }

  ResultadoCurvaAbc _montar(
    ModoAbc modo,
    PeriodoAbc periodo,
    JanelaPeriodo? janela,
    SnapshotEstoque estoque,
    List<_Linha> linhas,
    List<ProblemaDados> problemas,
  ) {
    final totalPositivo = linhas.fold<int>(0, (s, l) => s + (l.valor > 0 ? l.valor : 0));
    var acumulado = 0;
    final itens = <ItemCurvaAbc>[];
    final alertas = <AlertaRuptura>[];
    for (var k = 0; k < linhas.length; k++) {
      final l = linhas[k];
      final antes = acumulado;
      final contribuicao = l.valor > 0 ? l.valor : 0;
      acumulado += contribuicao;
      final classe = contribuicao == 0
          ? ClasseAbc.C
          : classificar(acumuladoAntes: antes, totalPositivo: totalPositivo);
      itens.add(
        ItemCurvaAbc(
          posicao: k + 1,
          produtoId: l.produtoId,
          nome: l.nome,
          arquivado: l.arquivado,
          quantidade: l.quantidade,
          valorBaseCentavos: l.valor,
          custoCentavos: l.custo,
          lucroBrutoCentavos: l.lucro,
          acumuladoAntesCentavos: antes,
          acumuladoDepoisCentavos: acumulado,
          totalPositivoCentavos: totalPositivo,
          classe: classe,
          estoqueDisponivel: l.estoque,
          valorCompleto: l.valorCompleto,
        ),
      );
      if (classe != ClasseAbc.A || l.arquivado) continue;
      final est = l.estoque;
      if (est == null) {
        if (modo == ModoAbc.realizado) {
          problemas.add(
            ProblemaDados(
              CodigoQualidade.estoqueDesconhecido,
              produtoId: l.produtoId,
              detalhe: 'classe A sem saldo conhecido; alerta não avaliado',
            ),
          );
        }
        continue;
      }
      if (est < 0) {
        problemas.add(
          ProblemaDados(
            CodigoQualidade.estoqueNegativo,
            produtoId: l.produtoId,
            detalhe: 'saldo disponível $est',
          ),
        );
      }
      if (est <= limiteRupturaUnidades) {
        alertas.add(
          AlertaRuptura(
            produtoId: l.produtoId,
            nome: l.nome,
            estoqueDisponivel: est,
            periodo: periodo,
            teorico: modo == ModoAbc.projetado,
          ),
        );
      }
    }
    return ResultadoCurvaAbc(
      modo: modo,
      periodo: periodo,
      janela: janela,
      fuso: fuso.nome,
      snapshotVersion: estoque.versao,
      atualizadoEm: estoque.atualizadoEm,
      geradoEm: relogio.agoraUtc(),
      demonstracao: estoque.demonstracao,
      itens: itens,
      alertas: alertas,
      problemas: problemas,
    );
  }
}

class _Linha {
  _Linha({
    required this.produtoId,
    required this.nome,
    required this.arquivado,
    required this.quantidade,
    required this.valor,
    required this.custo,
    required this.lucro,
    required this.estoque,
    required this.valorCompleto,
  });

  final String produtoId;
  final String nome;
  final bool arquivado;
  final int quantidade;
  final int valor;
  final int? custo;
  final int? lucro;
  final int? estoque;
  final bool valorCompleto;
}

/// Estado persistido de um alerta. "Lido" e "resolvido" são independentes:
/// marcar como lido não resolve a falta física.
class EstadoAlerta {
  const EstadoAlerta({
    required this.alerta,
    required this.criadoEm,
    this.lido = false,
    this.resolvidoEm,
  });

  final AlertaRuptura alerta;
  final DateTime criadoEm;
  final bool lido;
  final DateTime? resolvidoEm;

  bool get resolvido => resolvidoEm != null;

  EstadoAlerta marcarLido() =>
      EstadoAlerta(alerta: alerta, criadoEm: criadoEm, lido: true, resolvidoEm: resolvidoEm);
}

/// Atualiza alertas ativos com o resultado mais recente: mantém o mesmo ID
/// (sem duplicar), preserva "lido", resolve o que saiu da condição.
List<EstadoAlerta> conciliarAlertas(
  List<EstadoAlerta> anteriores,
  List<AlertaRuptura> atuais,
  DateTime agoraUtc,
) {
  final porId = {for (final a in atuais) a.id: a};
  final resultado = <EstadoAlerta>[];
  final vistos = <String>{};
  for (final antigo in anteriores) {
    final novo = porId[antigo.alerta.id];
    if (antigo.resolvido) {
      if (novo == null) resultado.add(antigo);
      continue; // Reincidência vira um alerta novo, abaixo.
    }
    if (novo == null) {
      resultado.add(
        EstadoAlerta(
          alerta: antigo.alerta,
          criadoEm: antigo.criadoEm,
          lido: antigo.lido,
          resolvidoEm: agoraUtc,
        ),
      );
    } else {
      vistos.add(novo.id);
      resultado.add(EstadoAlerta(alerta: novo, criadoEm: antigo.criadoEm, lido: antigo.lido));
    }
  }
  for (final a in atuais) {
    if (!vistos.contains(a.id)) resultado.add(EstadoAlerta(alerta: a, criadoEm: agoraUtc));
  }
  return resultado;
}
