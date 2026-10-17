class PrimeirosPassos {
  PrimeirosPassos({required String chavePix, required Iterable<String> codigosProdutos, required int vendas})
      : pix = chavePix.trim().isNotEmpty,
        produtos = codigosProdutos.where((codigo) => codigo.trim().isNotEmpty).toSet().length >= 3,
        primeiraVenda = vendas > 0;

  final bool pix;
  final bool produtos;
  final bool primeiraVenda;

  bool get concluido => pix && produtos && primeiraVenda;
}
