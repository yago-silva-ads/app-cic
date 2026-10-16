/// Problemas de dados detectados pelo domínio. Nunca são convertidos em zero:
/// viajam junto do resultado para a UI e para a IA dizerem o que falta.
enum CodigoQualidade {
  estoqueDesconhecido,
  estoqueNegativo,
  reservaMaiorQueFisico,
  custoHistoricoAusente,
  custoAtualAusente,
  precoAtualAusente,
  precoHistoricoAusente,
  devolucaoSemVendaOriginal,
  devolucaoAcimaDoVendido,
  devolucaoDeVendaCancelada,
  movimentacaoVinculadaSemVenda,
  eventoDuplicado,
  produtoDesconhecido,
}

class ProblemaDados {
  const ProblemaDados(this.codigo, {this.produtoId, this.eventoId, this.detalhe});

  final CodigoQualidade codigo;
  final String? produtoId;
  final String? eventoId;
  final String? detalhe;

  Map<String, Object?> toJson() => {
    'codigo': codigo.name,
    if (produtoId != null) 'produtoId': produtoId,
    if (eventoId != null) 'eventoId': eventoId,
    if (detalhe != null) 'detalhe': detalhe,
  };

  @override
  String toString() => 'ProblemaDados(${toJson()})';
}
