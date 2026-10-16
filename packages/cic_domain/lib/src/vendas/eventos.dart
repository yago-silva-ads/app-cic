/// Fatos econômicos que alimentam o realizado. Instantes sempre em UTC.
library;

sealed class EventoComercial {
  const EventoComercial({required this.id, required this.instante});

  final String id;
  final DateTime instante;

  static EventoComercial fromJson(Map<String, Object?> j) {
    final instante = DateTime.parse(j['instante'] as String).toUtc();
    final id = j['id'] as String;
    return switch (j['tipo']) {
      'venda' => Venda(
        id: id,
        instante: instante,
        status: StatusVenda.values.byName(j['status'] as String? ?? 'concluida'),
        descontoPedidoCentavos: j['descontoPedidoCentavos'] as int? ?? 0,
        itens: [for (final i in j['itens'] as List) ItemVendido.fromJson((i as Map).cast())],
      ),
      'devolucao' => Devolucao(
        id: id,
        instante: instante,
        vendaId: j['vendaId'] as String,
        itemId: j['itemId'] as String,
        quantidade: j['quantidade'] as int,
        valorEstornadoCentavos: j['valorEstornadoCentavos'] as int?,
      ),
      'movimentacao' => MovimentacaoEstoque(
        id: id,
        instante: instante,
        produtoId: j['produtoId'] as String,
        quantidade: j['quantidade'] as int,
        motivo: MotivoMovimentacao.values.byName(j['motivo'] as String),
        eventoOrigemId: j['eventoOrigemId'] as String?,
        precoUnitarioHistoricoCentavos: j['precoUnitarioHistoricoCentavos'] as int?,
        custoUnitarioHistoricoCentavos: j['custoUnitarioHistoricoCentavos'] as int?,
        nomeHistorico: j['nomeHistorico'] as String?,
      ),
      'caixa' => MovimentoCaixa(
        id: id,
        instante: instante,
        tipo: TipoMovimentoCaixa.values.byName(j['tipoCaixa'] as String),
        valorCentavos: j['valorCentavos'] as int,
      ),
      final t => throw FormatException('Tipo de evento desconhecido: $t'),
    };
  }
}

enum StatusVenda { concluida, cancelada }

class ItemVendido {
  const ItemVendido({
    required this.itemId,
    required this.produtoId,
    required this.quantidade,
    required this.precoUnitarioCentavos,
    this.descontoItemCentavos = 0,
    this.custoUnitarioHistoricoCentavos,
    this.nomeHistorico,
  });

  final String itemId;
  final String produtoId;
  final int quantidade;

  /// Preço praticado NA VENDA (histórico), não o preço atual do cadastro.
  final int precoUnitarioCentavos;
  final int descontoItemCentavos;

  /// CMV unitário registrado na venda. `null` = custo histórico ausente.
  final int? custoUnitarioHistoricoCentavos;

  /// Nome no momento da venda, para produtos depois excluídos do cadastro.
  final String? nomeHistorico;

  int get brutoCentavos => quantidade * precoUnitarioCentavos - descontoItemCentavos;

  factory ItemVendido.fromJson(Map<String, Object?> j) => ItemVendido(
    itemId: j['itemId'] as String,
    produtoId: j['produtoId'] as String,
    quantidade: j['quantidade'] as int,
    precoUnitarioCentavos: j['precoUnitarioCentavos'] as int,
    descontoItemCentavos: j['descontoItemCentavos'] as int? ?? 0,
    custoUnitarioHistoricoCentavos: j['custoUnitarioHistoricoCentavos'] as int?,
    nomeHistorico: j['nomeHistorico'] as String?,
  );
}

/// Venda do PDV. Frete e impostos destacados ficam fora da receita de produto
/// (política abc-v1); o desconto de pedido é rateado entre os itens.
class Venda extends EventoComercial {
  const Venda({
    required super.id,
    required super.instante,
    required this.itens,
    this.status = StatusVenda.concluida,
    this.descontoPedidoCentavos = 0,
  });

  final StatusVenda status;
  final List<ItemVendido> itens;
  final int descontoPedidoCentavos;
}

/// Devolução efetivada: estorno na DATA DA DEVOLUÇÃO, vinculado ao item.
/// Sem [valorEstornadoCentavos], estorna a fração proporcional do líquido.
class Devolucao extends EventoComercial {
  const Devolucao({
    required super.id,
    required super.instante,
    required this.vendaId,
    required this.itemId,
    required this.quantidade,
    this.valorEstornadoCentavos,
  });

  final String vendaId;
  final String itemId;
  final int quantidade;
  final int? valorEstornadoCentavos;
}

enum MotivoMovimentacao {
  /// Saída que é venda. Com [MovimentacaoEstoque.eventoOrigemId] apontando
  /// para uma venda, é a baixa daquela venda e NÃO conta de novo.
  saidaComercial,
  perda,
  consumoInterno,
  ajuste,
  transferencia,
  entrada,
}

class MovimentacaoEstoque extends EventoComercial {
  const MovimentacaoEstoque({
    required super.id,
    required super.instante,
    required this.produtoId,
    required this.quantidade,
    required this.motivo,
    this.eventoOrigemId,
    this.precoUnitarioHistoricoCentavos,
    this.custoUnitarioHistoricoCentavos,
    this.nomeHistorico,
  });

  final String produtoId;
  final int quantidade;
  final MotivoMovimentacao motivo;
  final String? eventoOrigemId;
  final int? precoUnitarioHistoricoCentavos;
  final int? custoUnitarioHistoricoCentavos;
  final String? nomeHistorico;
}

enum TipoMovimentoCaixa { sangria, reforco }

/// Gaveta do caixa. Nunca é receita de vendas.
class MovimentoCaixa extends EventoComercial {
  const MovimentoCaixa({
    required super.id,
    required super.instante,
    required this.tipo,
    required this.valorCentavos,
  });

  final TipoMovimentoCaixa tipo;
  final int valorCentavos;
}
