class Produto {
  final String codigo;
  final String nome;
  final String lote;
  final int quantidade;
  final double valorCompra;
<<<<<<< HEAD
  final double markup; // <-- VOLTOU!
  final double valorVenda;
  final String tipoProduto; // Novo campo: 'revendido' ou 'produzido'
=======
  final double markup;
  final double valorVenda;
  final String origem; // ✅ Adicionado
  final DateTime? dataEntrada; // ✅ Adicionado (Rastreio de entrada)
  final DateTime? dataValidade; // ✅ Adicionado (Validade FIFO)
  final Map<String, dynamic>? insumos; // ✅ Adicionado (para produtos fabricados)
  final int vendidas; // ✅ Adicionado (unidades vendidas)
  final String? empresaId; // 🔒 Multi-tenant: ID da empresa (auth.uid())
>>>>>>> fix/ui-overflow-and-ia-bearer

  Produto({
    required this.codigo,
    required this.nome,
    required this.lote,
    required this.quantidade,
    required this.valorCompra,
    required this.markup,
    required this.valorVenda,
<<<<<<< HEAD
    required this.tipoProduto,
=======
    required this.origem,
    this.dataEntrada,
    this.dataValidade,
    this.insumos,
    this.vendidas = 0,
    this.empresaId,
>>>>>>> fix/ui-overflow-and-ia-bearer
  });

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'nome': nome,
        'lote': lote,
        'quantidade': quantidade,
        'valorCompra': valorCompra,
        'markup': markup,
        'valorVenda': valorVenda,
<<<<<<< HEAD
        'tipoProduto': tipoProduto,
=======
        'origem': origem,
        'data_entrada': dataEntrada?.toIso8601String().split('T')[0],
        'data_validade': dataValidade?.toIso8601String().split('T')[0],
        'vendidas': vendidas,

        if (empresaId != null) 'empresa_id': empresaId,
>>>>>>> fix/ui-overflow-and-ia-bearer
      };

  factory Produto.fromJson(Map<String, dynamic> json) => Produto(
        codigo: json['codigo'],
        nome: json['nome'],
        lote: json['lote'],
        quantidade: json['quantidade'],
        valorCompra: json['valorCompra'],
        markup: json['markup'] ?? 2.0,
        valorVenda: json['valorVenda'] ?? 0.0,
<<<<<<< HEAD
        tipoProduto: json['tipoProduto'] ?? 'revendido', // Default para compatibilidade
=======
        origem: json['origem'] ?? 'Revendido',
        dataEntrada: json['data_entrada'] != null ? DateTime.tryParse(json['data_entrada']) : null,
        dataValidade: json['data_validade'] != null ? DateTime.tryParse(json['data_validade']) : null,
        insumos: (json['insumos'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as num).toDouble())),
        vendidas: json['vendidas'] ?? 0,
        empresaId: json['empresa_id'],
>>>>>>> fix/ui-overflow-and-ia-bearer
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
