class Aquisicao {
  final String? id;
  final String produtoCodigo;
  final DateTime dataAquisicao;
  final int quantidade;
  final double valorUnitario;
  final String? fornecedor;
  final String? observacao;
  final String? empresaId;

  Aquisicao({
    this.id,
    required this.produtoCodigo,
    required this.dataAquisicao,
    required this.quantidade,
    required this.valorUnitario,
    this.fornecedor,
    this.observacao,
    this.empresaId,
  });

  /// Custo total da aquisição (quantidade * valor unitário)
  double get custoTotal => quantidade * valorUnitario;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'produto_codigo': produtoCodigo,
        'data_aquisicao': dataAquisicao.toIso8601String().split('T')[0],
        'quantidade': quantidade,
        'valor_unitario': valorUnitario,
        if (fornecedor != null && fornecedor!.isNotEmpty) 'fornecedor': fornecedor,
        if (observacao != null && observacao!.isNotEmpty) 'observacao': observacao,
        if (empresaId != null) 'empresa_id': empresaId,
      };

  factory Aquisicao.fromJson(Map<String, dynamic> json) => Aquisicao(
        id: json['id']?.toString(),
        produtoCodigo: json['produto_codigo'] ?? '',
        dataAquisicao: json['data_aquisicao'] != null
            ? DateTime.parse(json['data_aquisicao'])
            : DateTime.now(),
        quantidade: (json['quantidade'] as num?)?.toInt() ?? 0,
        valorUnitario: (json['valor_unitario'] as num?)?.toDouble() ?? 0.0,
        fornecedor: json['fornecedor'] as String?,
        observacao: json['observacao'] as String?,
        empresaId: json['empresa_id'] as String?,
      );
}
