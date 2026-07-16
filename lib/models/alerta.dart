/// Model Dart para alertas do sistema.
///
/// Representa um alerta gerado automaticamente pelos triggers do banco
/// (validade, estoque baixo, prejuízo) ou pela IA (sugestões).
/// Isolado por tenant via RLS no Supabase.
class Alerta {
  final int id;
  final String tipo; // VALIDADE, ESTOQUE_BAIXO, PREJUIZO, IA_SUGESTAO
  final String? produtoCodigo;
  final String mensagem;
  final String severidade; // BAIXO, MEDIO, ALTO, CRITICO
  final bool lido;
  final DateTime criadoEm;

  Alerta({
    required this.id,
    required this.tipo,
    this.produtoCodigo,
    required this.mensagem,
    required this.severidade,
    this.lido = false,
    required this.criadoEm,
  });

  factory Alerta.fromJson(Map<String, dynamic> json) => Alerta(
        id: json['id'],
        tipo: json['tipo'],
        produtoCodigo: json['produto_codigo'],
        mensagem: json['mensagem'],
        severidade: json['severidade'] ?? 'MEDIO',
        lido: json['lido'] ?? false,
        criadoEm: DateTime.parse(json['criado_em']),
      );

  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'tipo': tipo,
        'produto_codigo': produtoCodigo,
        'mensagem': mensagem,
        'severidade': severidade,
        'lido': lido,
      };

  /// Retorna o ícone emoji correspondente ao tipo do alerta
  String get icone {
    switch (tipo) {
      case 'VALIDADE':
        return '📅';
      case 'ESTOQUE_BAIXO':
        return '📦';
      case 'PREJUIZO':
        return '💸';
      case 'IA_SUGESTAO':
        return '🤖';
      default:
        return '⚠️';
    }
  }

  /// Retorna a cor associada à severidade (para uso na UI)
  /// CRITICO = vermelho, ALTO = laranja, MEDIO = amarelo, BAIXO = azul
  String get corHex {
    switch (severidade) {
      case 'CRITICO':
        return '#FF1744';
      case 'ALTO':
        return '#FF9100';
      case 'MEDIO':
        return '#FFD600';
      case 'BAIXO':
        return '#2979FF';
      default:
        return '#FFD600';
    }
  }

  /// Retorna true se o alerta é crítico ou alto (para pop-up automático)
  bool get isUrgente => severidade == 'CRITICO' || severidade == 'ALTO';

  /// Label amigável do tipo
  String get tipoLabel {
    switch (tipo) {
      case 'VALIDADE':
        return 'Validade';
      case 'ESTOQUE_BAIXO':
        return 'Estoque Baixo';
      case 'PREJUIZO':
        return 'Prejuízo';
      case 'IA_SUGESTAO':
        return 'Sugestão IA';
      default:
        return tipo;
    }
  }
}
