class Produto {
  final String codigo;
  final String nome;
  final String lote;
  final int quantidade;
  final double valorCompra;
  final double markup;
  final double valorVenda;
  final String origem; // ✅ Adicionado
  final Map<String, double>? insumos; // ✅ Adicionado (para produtos fabricados)

  Produto({
    required this.codigo,
    required this.nome,
    required this.lote,
    required this.quantidade,
    required this.valorCompra,
    required this.markup,
    required this.valorVenda,
    required this.origem,
    this.insumos,
  });

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'nome': nome,
        'lote': lote,
        'quantidade': quantidade,
        'valorCompra': valorCompra,
        'markup': markup,
        'valorVenda': valorVenda,
        'origem': origem,
      };

  factory Produto.fromJson(Map<String, dynamic> json) => Produto(
        codigo: json['codigo'],
        nome: json['nome'],
        lote: json['lote'],
        quantidade: json['quantidade'],
        valorCompra: json['valorCompra'],
        markup: json['markup'] ?? 2.0,
        valorVenda: json['valorVenda'] ?? 0.0,
        origem: json['origem'] ?? 'Revendido',
        insumos: (json['insumos'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as num).toDouble())),
      );

  double calcularCustoFabricado(List<Produto> todoEstoque) {
    if (origem != 'Fabricado' || insumos == null || insumos!.isEmpty) {
      return valorCompra;
    }

    double custoCalculado = 0.0;
    insumos!.forEach((codigoInsumo, qtdUsada) {
      final insumo = todoEstoque.firstWhere(
        (p) => p.codigo == codigoInsumo,
        orElse: () => Produto(
          codigo: '',
          nome: '',
          lote: '',
          quantidade: 0,
          valorCompra: 0,
          markup: 0,
          valorVenda: 0,
          origem: 'Desconhecido',
        ),
      );
      custoCalculado += (insumo.valorCompra * qtdUsada);
    });
    return custoCalculado;
  }
}
