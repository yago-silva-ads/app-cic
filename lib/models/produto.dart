class Produto {
  final String codigo;
  final String nome;
  final String lote;
  final int quantidade;
  final double valorCompra;
  final double markup; // <-- VOLTOU!
  final double valorVenda;
  final String tipoProduto; // Novo campo: 'revendido' ou 'produzido'

  Produto({
    required this.codigo,
    required this.nome,
    required this.lote,
    required this.quantidade,
    required this.valorCompra,
    required this.markup,
    required this.valorVenda,
    required this.tipoProduto,
  });

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'nome': nome,
        'lote': lote,
        'quantidade': quantidade,
        'valorCompra': valorCompra,
        'markup': markup,
        'valorVenda': valorVenda,
        'tipoProduto': tipoProduto,
      };

  factory Produto.fromJson(Map<String, dynamic> json) => Produto(
        codigo: json['codigo'],
        nome: json['nome'],
        lote: json['lote'],
        quantidade: json['quantidade'],
        valorCompra: json['valorCompra'],
        markup: json['markup'] ?? 2.0,
        valorVenda: json['valorVenda'] ?? 0.0,
        tipoProduto: json['tipoProduto'] ?? 'revendido', // Default para compatibilidade
      );
}