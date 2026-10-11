/// Modelos de dados do app, espelhando o `types.ts` do AI Studio.
/// Valores monetários trafegam em reais (numeric do Supabase); contas e
/// totais do PDV são feitos em centavos inteiros (ver `core/format.dart`).
library;

DateTime? _data(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
double _num(dynamic v, [double padrao = 0]) => v is num ? v.toDouble() : (double.tryParse('$v') ?? padrao);
int _int(dynamic v, [int padrao = 0]) => v is num ? v.toInt() : (int.tryParse('$v') ?? padrao);
String _dia(DateTime? d) => d == null ? '' : d.toIso8601String().split('T').first;

class Produto {
  Produto({
    required this.codigo,
    required this.nome,
    this.lote = '',
    required this.quantidade,
    required this.valorCompra,
    required this.markup,
    required this.valorVenda,
    this.origem = 'Revendido',
    this.categoria = 'Geral',
    this.dataEntrada,
    this.dataValidade,
    this.vendidas = 0,
    this.estoqueMinimo = 5,
    this.unidade = 'un',
    this.ativo = true,
  });

  final String codigo;
  String nome;
  String lote;

  /// SALDO ATUAL em estoque (nunca "total comprado").
  int quantidade;
  double valorCompra;
  double markup;
  double valorVenda;
  String origem;
  String categoria;
  DateTime? dataEntrada;
  DateTime? dataValidade;
  int vendidas;
  int estoqueMinimo;
  String unidade;
  bool ativo;

  factory Produto.fromJson(Map<String, dynamic> j) => Produto(
    codigo: '${j['codigo']}',
    nome: '${j['nome'] ?? ''}',
    lote: '${j['lote'] ?? ''}',
    quantidade: _int(j['quantidade']),
    valorCompra: _num(j['valor_compra']),
    markup: _num(j['markup'], 1),
    valorVenda: _num(j['valor_venda']),
    origem: '${j['origem'] ?? 'Revendido'}',
    categoria: '${j['categoria'] ?? 'Geral'}',
    dataEntrada: _data(j['data_entrada']),
    dataValidade: _data(j['data_validade']),
    vendidas: _int(j['vendidas']),
    estoqueMinimo: _int(j['estoque_minimo'], 5),
    unidade: '${j['unidade'] ?? 'un'}',
    ativo: j['ativo'] != false,
  );

  /// Payload para `salvar_produto`. Nunca inclui `empresa_id`: a loja é a do JWT.
  Map<String, dynamic> toRpc() => {
    'codigo': codigo,
    'nome': nome,
    'lote': lote,
    'quantidade': quantidade,
    'valor_compra': valorCompra,
    'markup': markup,
    'valor_venda': valorVenda,
    'origem': origem,
    'categoria': categoria,
    'data_entrada': _dia(dataEntrada ?? DateTime.now()),
    'data_validade': dataValidade == null ? '' : _dia(dataValidade),
    'estoque_minimo': estoqueMinimo,
    'unidade': unidade,
  };

  double get lucroUnitario => valorVenda - valorCompra;
  double get custoTotal => valorCompra * quantidade;
  double get retornoTotal => valorVenda * quantidade;
  int? get diasParaVencer =>
      dataValidade?.difference(DateTime.now()).inDays.toInt();
  bool get estoqueBaixo => quantidade <= estoqueMinimo;
}

enum TipoCusto { fixo, variavel }

class CustoOperacional {
  CustoOperacional({this.id, required this.nome, required this.valor, this.tipo = TipoCusto.fixo, this.categoria});

  final String? id;
  String nome;
  double valor;
  TipoCusto tipo;
  String? categoria;

  factory CustoOperacional.fromJson(Map<String, dynamic> j) => CustoOperacional(
    id: j['id']?.toString(),
    nome: '${j['nome'] ?? ''}',
    valor: _num(j['valor']),
    tipo: '${j['tipo'] ?? 'FIXO'}'.toUpperCase() == 'VARIAVEL' ? TipoCusto.variavel : TipoCusto.fixo,
    categoria: j['categoria']?.toString(),
  );
}

class Alerta {
  Alerta({
    required this.id,
    required this.tipo,
    this.produtoCodigo,
    required this.mensagem,
    required this.severidade,
    required this.lido,
    required this.criadoEm,
  });

  final int id;
  final String tipo;
  final String? produtoCodigo;
  final String mensagem;
  final String severidade;
  bool lido;
  final DateTime criadoEm;

  factory Alerta.fromJson(Map<String, dynamic> j) => Alerta(
    id: _int(j['id']),
    tipo: '${j['tipo']}',
    produtoCodigo: j['produto_codigo']?.toString(),
    mensagem: '${j['mensagem']}',
    severidade: '${j['severidade'] ?? 'MEDIO'}',
    lido: j['lido'] == true,
    criadoEm: _data(j['criado_em']) ?? DateTime.now(),
  );
}

class Movimentacao {
  Movimentacao({
    required this.id,
    required this.tipo,
    required this.motivo,
    required this.produtoCodigo,
    required this.produtoNome,
    required this.quantidade,
    required this.valorUnitario,
    required this.valorTotal,
    required this.dataHora,
    this.documento,
    this.observacao,
  });

  final String id;
  final String tipo; // ENTRADA | SAIDA
  final String motivo;
  final String produtoCodigo;
  final String produtoNome;
  final int quantidade;
  final double valorUnitario;
  final double valorTotal;
  final DateTime dataHora;
  final String? documento;
  final String? observacao;

  bool get entrada => tipo == 'ENTRADA';

  factory Movimentacao.fromJson(Map<String, dynamic> j) => Movimentacao(
    id: '${j['id']}',
    tipo: '${j['tipo']}',
    motivo: '${j['motivo']}',
    produtoCodigo: '${j['produto_codigo']}',
    produtoNome: '${j['produto_nome']}',
    quantidade: _int(j['quantidade']),
    valorUnitario: _num(j['valor_unitario']),
    valorTotal: _num(j['valor_total']),
    dataHora: _data(j['criado_em']) ?? DateTime.now(),
    documento: j['documento']?.toString(),
    observacao: j['observacao']?.toString(),
  );
}

/// Uma linha de `historico_vendas` (um item de uma venda).
class VendaItemHistorico {
  VendaItemHistorico({
    required this.id,
    this.vendaId,
    required this.produtoCodigo,
    this.nomeProduto,
    required this.quantidade,
    required this.valorUnitario,
    this.custoUnitario,
    required this.data,
    this.metodoPagamento,
    this.desconto = 0,
  });

  final String id;
  final String? vendaId;
  final String produtoCodigo;
  final String? nomeProduto;
  final int quantidade;
  final double valorUnitario;
  final double? custoUnitario;
  final DateTime data;
  final String? metodoPagamento;
  final double desconto;

  factory VendaItemHistorico.fromJson(Map<String, dynamic> j) => VendaItemHistorico(
    id: '${j['id']}',
    vendaId: j['venda_id']?.toString(),
    produtoCodigo: '${j['produto_codigo']}',
    nomeProduto: j['nome_produto']?.toString(),
    quantidade: _int(j['quantidade_vendida']),
    valorUnitario: _num(j['valor_unitario']),
    custoUnitario: j['custo_unitario'] == null ? null : _num(j['custo_unitario']),
    data: _data(j['data_venda']) ?? DateTime.now(),
    metodoPagamento: j['metodo_pagamento']?.toString(),
    desconto: _num(j['desconto']),
  );
}

class ItemCarrinho {
  ItemCarrinho({required this.produto, this.quantidade = 1});
  final Produto produto;
  int quantidade;
  int get subtotalCentavos => (produto.valorVenda * 100).round() * quantidade;
}

class Usuario {
  Usuario({required this.id, required this.email, required this.nome, required this.lojaNome});
  final String id;
  final String email;
  final String nome;
  final String lojaNome;
}
