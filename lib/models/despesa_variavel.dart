class DespesaVariavel {
  final String? id; // UUID no Supabase
  final String nome;
  final double valor;
  final DateTime? criadoEm; // Data de registro (preenchida pelo Supabase)

  DespesaVariavel({this.id, required this.nome, required this.valor, this.criadoEm});

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'nome': nome,
        'valor': valor,
      };

  factory DespesaVariavel.fromJson(Map<String, dynamic> json) => DespesaVariavel(
        id: json['id']?.toString(),
        nome: json['nome'] as String? ?? '',
        valor: (json['valor'] as num?)?.toDouble() ?? 0.0,
        criadoEm: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
            : null,
      );
}
