class CustoOperacional {
  final int? id;
  final String nome;
  final double valor;

  CustoOperacional({
    this.id,
    required this.nome,
    required this.valor,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'valor': valor,
      };

  factory CustoOperacional.fromJson(Map<String, dynamic> json) => CustoOperacional(
        id: json['id'] as int?,
        nome: json['nome'] as String,
        valor: json['valor'] as double,
      );
}
