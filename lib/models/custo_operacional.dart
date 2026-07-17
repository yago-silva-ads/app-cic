class CustoOperacional {
  final String? id; // UUID no Supabase (era int? — corrigido)
  final String nome;
  final double valor;

  CustoOperacional({this.id, required this.nome, required this.valor});

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'nome': nome,
        'valor': valor,
      };

  factory CustoOperacional.fromJson(Map<String, dynamic> json) => CustoOperacional(
        id: json['id']?.toString(), // Supabase retorna UUID como String
        nome: json['nome'] as String? ?? '',
        valor: (json['valor'] as num?)?.toDouble() ?? 0.0,
      );
}