/// Resultado deterministico da comparacao do preco da loja com o mercado.
enum AcaoPrecoMercado { aumentar, reduzir, manter, revisarDados }

class OfertaMercado {
  const OfertaMercado({required this.precoCentavos, required this.fonte, required this.url, this.coletadaEm});
  final int precoCentavos;
  final String fonte;
  final String url;
  final DateTime? coletadaEm;
}

class AnaliseMercado {
  const AnaliseMercado({required this.acao, required this.precoAtualCentavos, required this.precoSugeridoCentavos, required this.medianaMercadoCentavos, required this.menorPrecoCentavos, required this.maiorPrecoCentavos, required this.ofertasUsadas, required this.confianca, required this.motivo});
  final AcaoPrecoMercado acao;
  final int precoAtualCentavos;
  final int precoSugeridoCentavos;
  final int? medianaMercadoCentavos;
  final int? menorPrecoCentavos;
  final int? maiorPrecoCentavos;
  final int ofertasUsadas;
  final double confianca;
  final String motivo;
}

/// Compara o preco atual com a mediana observada.
/// O custo e usado como piso de protecao: nenhuma recomendacao fica abaixo
/// de 20% de margem bruta quando o custo foi informado.
AnaliseMercado analisarMercado({required int precoAtualCentavos, required List<OfertaMercado> ofertas, int? custoCentavos}) {
  final validas = ofertas.where((o) => o.precoCentavos > 0).toList()..sort((a, b) => a.precoCentavos.compareTo(b.precoCentavos));
  if (precoAtualCentavos <= 0 || validas.length < 2) {
    return AnaliseMercado(
      acao: AcaoPrecoMercado.revisarDados,
      precoAtualCentavos: precoAtualCentavos,
      precoSugeridoCentavos: precoAtualCentavos,
      medianaMercadoCentavos: null,
      menorPrecoCentavos: validas.isEmpty ? null : validas.first.precoCentavos,
      maiorPrecoCentavos: validas.isEmpty ? null : validas.last.precoCentavos,
      ofertasUsadas: validas.length,
      confianca: 0,
      motivo: 'Sao necessarias pelo menos duas ofertas validas e um preco atual para comparar.',
    );
  }
  final mediana = validas.length.isOdd ? validas[validas.length ~/ 2].precoCentavos : ((validas[validas.length ~/ 2 - 1].precoCentavos + validas[validas.length ~/ 2].precoCentavos) ~/ 2);
  final piso = custoCentavos == null ? 0 : (custoCentavos * 1.20).ceil();
  final razao = precoAtualCentavos / mediana;
  final abaixoDoPiso = piso > 0 && precoAtualCentavos < piso;
  final reduzirBloqueadoPeloPiso = razao > 1.10 && piso >= precoAtualCentavos;
  final acao = abaixoDoPiso
      ? AcaoPrecoMercado.aumentar
      : razao < 0.90
          ? AcaoPrecoMercado.aumentar
          : razao > 1.10 && !reduzirBloqueadoPeloPiso
              ? AcaoPrecoMercado.reduzir
              : AcaoPrecoMercado.manter;
  final alvo = acao == AcaoPrecoMercado.manter ? precoAtualCentavos : (mediana < piso ? piso : mediana);
  final confianca = (0.55 + validas.length.clamp(0, 8) * 0.05).clamp(0.0, 0.95).toDouble();
  final motivo = switch (acao) {
    AcaoPrecoMercado.aumentar => abaixoDoPiso ? 'O preco atual esta abaixo do piso minimo de margem; aumente ate esse piso antes de competir.' : 'O preco atual esta mais de 10% abaixo da mediana observada.',
    AcaoPrecoMercado.reduzir => 'O preco atual esta mais de 10% acima da mediana observada.',
    AcaoPrecoMercado.manter => reduzirBloqueadoPeloPiso ? 'O mercado sugere reduzir, mas o piso minimo de margem impede uma reducao segura; mantenha o preco atual.' : 'O preco atual esta dentro de uma faixa competitiva de 10% da mediana.',
    AcaoPrecoMercado.revisarDados => 'Dados insuficientes para recomendar uma alteracao.',
  };
  return AnaliseMercado(
    acao: acao,
    precoAtualCentavos: precoAtualCentavos,
    precoSugeridoCentavos: alvo,
    medianaMercadoCentavos: mediana,
    menorPrecoCentavos: validas.first.precoCentavos,
    maiorPrecoCentavos: validas.last.precoCentavos,
    ofertasUsadas: validas.length,
    confianca: confianca,
    motivo: custoCentavos != null && mediana < piso && !abaixoDoPiso ? '$motivo O piso de margem foi aplicado.' : motivo,
  );
}
