import '../abc/curva_abc.dart';

/// Situação de reposição de um produto, calculada só com vendas e saldo reais.
enum SituacaoPrevisao {
  /// Vendeu no período e não tem saldo: está perdendo venda agora.
  ruptura,

  /// Acaba em até [PrevisaoDemanda.diasCriticos] dias no ritmo atual.
  critico,

  /// Acaba antes do horizonte de reposição ([PrevisaoDemanda.diasAlvo]).
  atencao,
  ok,

  /// Tem saldo e não vendeu nada no período: dinheiro parado.
  parado,

  /// Saldo desconhecido: não dá para prever sem inventar.
  semDados,
}

class ItemPrevisao {
  const ItemPrevisao({
    required this.produtoId,
    required this.nome,
    required this.classe,
    required this.estoque,
    required this.vendidosNoPeriodo,
    required this.mediaDiariaCentesimos,
    required this.coberturaDias,
    required this.reposicaoSugerida,
    required this.situacao,
  });

  final String produtoId;
  final String nome;
  final ClasseAbc classe;
  final int? estoque;
  final int vendidosNoPeriodo;

  /// Média de unidades vendidas por dia × 100 (inteiro: 1,25 un/dia = 125).
  final int mediaDiariaCentesimos;

  /// Dias até zerar no ritmo atual. `null` sem venda ou sem saldo conhecido.
  final int? coberturaDias;

  /// Unidades para cobrir o horizonte de reposição, descontando o saldo (0 se não precisa).
  final int reposicaoSugerida;
  final SituacaoPrevisao situacao;

  double get mediaDiaria => mediaDiariaCentesimos / 100;

  Map<String, Object?> toJson() => {
    'produtoId': produtoId,
    'nome': nome,
    'classe': classe.name,
    'estoque': estoque,
    'vendidosNoPeriodo': vendidosNoPeriodo,
    'mediaDiaria': mediaDiaria,
    'coberturaDias': coberturaDias,
    'reposicaoSugerida': reposicaoSugerida,
    'situacao': situacao.name,
  };
}

class ResultadoPrevisao {
  const ResultadoPrevisao({required this.diasJanela, required this.diasAlvo, required this.itens});

  final int diasJanela;
  final int diasAlvo;
  final List<ItemPrevisao> itens;

  Iterable<ItemPrevisao> de(SituacaoPrevisao s) => itens.where((i) => i.situacao == s);

  Map<String, Object?> toJson() => {
    'metodo': 'média móvel de $diasJanela dias (vendas reais) e horizonte de $diasAlvo dias',
    'diasJanela': diasJanela,
    'diasAlvo': diasAlvo,
    'itens': [for (final i in itens) i.toJson()],
  };
}

/// Previsão de demanda por média móvel: vendas reais da janela ÷ dias da janela.
/// Nada é estimado fora disso; sem saldo conhecido, o item fica [SituacaoPrevisao.semDados].
class PrevisaoDemanda {
  const PrevisaoDemanda({this.diasAlvo = 14, this.diasCriticos = 7});

  /// Horizonte de reposição: o estoque deveria durar ao menos isso.
  final int diasAlvo;
  final int diasCriticos;

  ResultadoPrevisao calcular(ResultadoCurvaAbc abc, {int diasJanela = 30}) {
    final itens = <ItemPrevisao>[];
    for (final i in abc.itens) {
      if (i.arquivado) continue;
      final vendidos = i.quantidade > 0 ? i.quantidade : 0;
      final media = (vendidos * 100 / diasJanela).round();
      final estoque = i.estoqueDisponivel;
      int? cobertura;
      var reposicao = 0;
      SituacaoPrevisao situacao;
      if (estoque == null) {
        situacao = SituacaoPrevisao.semDados;
      } else if (vendidos == 0) {
        situacao = estoque > 0 ? SituacaoPrevisao.parado : SituacaoPrevisao.ok;
      } else {
        // Divisão inteira: dias completos até zerar (conservador).
        cobertura = estoque <= 0 ? 0 : (estoque * diasJanela) ~/ vendidos;
        final necessario = (vendidos * diasAlvo + diasJanela - 1) ~/ diasJanela; // teto
        reposicao = necessario - estoque > 0 ? necessario - estoque : 0;
        situacao = estoque <= 0
            ? SituacaoPrevisao.ruptura
            : cobertura <= diasCriticos
            ? SituacaoPrevisao.critico
            : cobertura < diasAlvo
            ? SituacaoPrevisao.atencao
            : SituacaoPrevisao.ok;
      }
      itens.add(ItemPrevisao(
        produtoId: i.produtoId,
        nome: i.nome,
        classe: i.classe,
        estoque: estoque,
        vendidosNoPeriodo: vendidos,
        mediaDiariaCentesimos: media,
        coberturaDias: cobertura,
        reposicaoSugerida: reposicao,
        situacao: situacao,
      ));
    }
    // Mais urgente primeiro; dentro da mesma situação, quem acaba antes.
    itens.sort((a, b) {
      final s = a.situacao.index.compareTo(b.situacao.index);
      if (s != 0) return s;
      return (a.coberturaDias ?? 1 << 30).compareTo(b.coberturaDias ?? 1 << 30);
    });
    return ResultadoPrevisao(diasJanela: diasJanela, diasAlvo: diasAlvo, itens: itens);
  }
}
