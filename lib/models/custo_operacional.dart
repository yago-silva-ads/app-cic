class CustoOperacional {
  final String? id; // UUID no Supabase (era int? — corrigido)
  final String nome;
  final double valor;
  final DateTime? criadoEm; // Data de registro do custo (preenchida pelo Supabase)

  CustoOperacional({this.id, required this.nome, required this.valor, this.criadoEm});

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'nome': nome,
        'valor': valor,
      };

  factory CustoOperacional.fromJson(Map<String, dynamic> json) => CustoOperacional(
        id: json['id']?.toString(), // Supabase retorna UUID como String
        nome: json['nome'] as String? ?? '',
        valor: (json['valor'] as num?)?.toDouble() ?? 0.0,
        criadoEm: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
            : null,
      );
}