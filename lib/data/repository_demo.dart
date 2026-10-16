import 'dart:math';

import 'conta.dart';
import 'models.dart';
import 'repository.dart';

/// Loja de demonstração (build com `--dart-define=DEMO=true`): tudo em memória,
/// sem login e sem banco. Serve para o cliente experimentar o app e para gravar
/// os tutoriais. Nada aqui é enviado ao servidor, exceto a pergunta ao assistente.
class DemoRepository implements CicRepository {
  DemoRepository() {
    _semear();
  }

  final List<Produto> _produtos = [];
  final List<VendaItemHistorico> _vendas = [];
  final List<Movimentacao> _movs = [];
  final List<CustoOperacional> _custos = [
    CustoOperacional(id: 'c1', nome: 'Aluguel', valor: 1800, categoria: 'Imóvel'),
    CustoOperacional(id: 'c2', nome: 'Energia', valor: 420, categoria: 'Contas'),
    CustoOperacional(id: 'c3', nome: 'Internet e maquininha', valor: 150, categoria: 'Contas'),
    CustoOperacional(id: 'c4', nome: 'Sacolas e embalagens', valor: 90, tipo: TipoCusto.variavel, categoria: 'Insumos'),
  ];
  final List<Alerta> _alertas = [];
  final List<Map<String, dynamic>> _relatorios = [];
  Map<String, dynamic> _conta = {};
  SessaoCaixa? _sessao;
  int _seq = 1000;

  String _id() => '${_seq++}';

  void _semear() {
    final hoje = DateTime.now();
    DateTime dia(int d) => DateTime(hoje.year, hoje.month, hoje.day).add(Duration(days: d));
    // (código, nome, categoria, saldo, custo, venda, mínimo, validade em dias, vendas/dia)
    final base = <(String, String, String, int, double, double, int, int?, double)>[
      ('7891000100103', 'Leite Integral 1L', 'Laticínios', 8, 3.90, 5.99, 12, 9, 2.0),
      ('7896005800105', 'Café Torrado 500g', 'Mercearia', 0, 14.50, 21.90, 6, 200, 1.0),
      ('7896006716115', 'Arroz Tipo 1 5kg', 'Mercearia', 30, 21.00, 28.90, 8, 300, 0.5),
      ('7894900011517', 'Refrigerante Cola 2L', 'Bebidas', 25, 6.20, 9.49, 10, 120, 1.3),
      ('7896004000107', 'Pão de Forma 500g', 'Padaria', 4, 5.10, 8.49, 6, 4, 0.4),
      ('7896036090244', 'Vinagre de Álcool 750ml', 'Mercearia', 40, 1.80, 3.49, 5, 400, 0.0),
      ('7891910000197', 'Açúcar Refinado 1kg', 'Mercearia', 22, 3.60, 5.29, 8, 365, 0.8),
      ('7896102502230', 'Feijão Carioca 1kg', 'Mercearia', 18, 6.40, 8.99, 8, 240, 0.7),
      ('7891150037526', 'Detergente 500ml', 'Limpeza', 35, 1.70, 2.79, 10, 700, 0.6),
      ('7898080640017', 'Ovos Brancos (dúzia)', 'Hortifruti', 6, 8.50, 12.90, 5, 12, 0.9),
    ];
    final rnd = Random(7);
    for (final (cod, nome, cat, saldo, custo, venda, minimo, validade, porDia) in base) {
      var vendidas = 0;
      for (var d = -29; d <= 0; d++) {
        var qtd = (porDia + rnd.nextDouble() - 0.5).round();
        if (porDia == 0) qtd = 0;
        if (qtd <= 0) continue;
        vendidas += qtd;
        final quando = dia(d).add(Duration(hours: 8 + rnd.nextInt(11), minutes: rnd.nextInt(60)));
        final idVenda = 'v${_id()}';
        _vendas.add(VendaItemHistorico(
          id: _id(), vendaId: idVenda, produtoCodigo: cod, nomeProduto: nome, quantidade: qtd,
          valorUnitario: venda, custoUnitario: custo, data: quando,
          metodoPagamento: const ['PIX', 'DINHEIRO', 'DEBITO', 'CREDITO'][rnd.nextInt(4)],
        ));
        _movs.add(Movimentacao(
          id: _id(), tipo: 'SAIDA', motivo: 'VENDA', produtoCodigo: cod, produtoNome: nome, quantidade: qtd,
          valorUnitario: venda, valorTotal: venda * qtd, dataHora: quando, documento: idVenda,
        ));
      }
      _produtos.add(Produto(
        codigo: cod, nome: nome, categoria: cat, quantidade: saldo, valorCompra: custo,
        markup: venda / custo, valorVenda: venda, estoqueMinimo: minimo, vendidas: vendidas,
        dataEntrada: dia(-30), dataValidade: validade == null ? null : dia(validade),
      ));
      _movs.add(Movimentacao(
        id: _id(), tipo: 'ENTRADA', motivo: 'COMPRA', produtoCodigo: cod, produtoNome: nome,
        quantidade: saldo + vendidas, valorUnitario: custo, valorTotal: custo * (saldo + vendidas),
        dataHora: dia(-30).add(const Duration(hours: 7)), documento: 'NF 1234',
      ));
    }
    _produtos.sort((a, b) => a.nome.compareTo(b.nome));
    _vendas.sort((a, b) => b.data.compareTo(a.data));
    _movs.sort((a, b) => b.dataHora.compareTo(a.dataHora));
    _gerarAlertas();
  }

  void _gerarAlertas() {
    var id = _alertas.length + 1;
    final ja = {for (final a in _alertas) '${a.tipo}:${a.produtoCodigo}'};
    for (final p in _produtos) {
      void add(String tipo, String msg, String sev) {
        if (ja.add('$tipo:${p.codigo}')) {
          _alertas.insert(0, Alerta(id: id++, tipo: tipo, produtoCodigo: p.codigo, mensagem: msg, severidade: sev, lido: false, criadoEm: DateTime.now()));
        }
      }
      if (p.quantidade <= 0) {
        add('ESTOQUE_ZERADO', '${p.nome} acabou no estoque.', 'ALTO');
      } else if (p.estoqueBaixo) {
        add('ESTOQUE_BAIXO', '${p.nome} está com só ${p.quantidade} ${p.unidade}.', 'MEDIO');
      }
      final dv = p.diasParaVencer;
      if (dv != null && dv <= 7) add('VALIDADE', '${p.nome} vence em $dv dias.', dv <= 3 ? 'ALTO' : 'MEDIO');
    }
  }

  Produto _produto(String codigo) => _produtos.firstWhere(
        (p) => p.codigo == codigo,
        orElse: () => throw ErroCic('Produto $codigo não encontrado no seu estoque.', codigo: 'PRODUTO_NAO_ENCONTRADO'),
      );

  @override
  String get uid => 'demo';

  @override
  Future<List<Produto>> produtos({bool incluirArquivados = false}) async =>
      [for (final p in _produtos) if (incluirArquivados || p.ativo) p];

  @override
  Future<int> salvarProduto(Produto p, {bool somar = true, String? documento, String? observacao}) async {
    final i = _produtos.indexWhere((x) => x.codigo == p.codigo);
    final antes = i < 0 ? 0 : _produtos[i].quantidade;
    final saldo = somar ? antes + p.quantidade : p.quantidade;
    p.quantidade = saldo;
    if (i < 0) {
      _produtos.add(p);
      _produtos.sort((a, b) => a.nome.compareTo(b.nome));
    } else {
      p.vendidas = _produtos[i].vendidas;
      _produtos[i] = p;
    }
    final delta = saldo - antes;
    if (delta != 0) {
      _movs.insert(0, Movimentacao(
        id: _id(), tipo: delta > 0 ? 'ENTRADA' : 'SAIDA', motivo: delta > 0 ? 'COMPRA' : 'AJUSTE',
        produtoCodigo: p.codigo, produtoNome: p.nome, quantidade: delta.abs(), valorUnitario: p.valorCompra,
        valorTotal: p.valorCompra * delta.abs(), dataHora: DateTime.now(), documento: documento, observacao: observacao,
      ));
    }
    _gerarAlertas();
    return saldo;
  }

  @override
  Future<bool> removerOuArquivarProduto(String codigo) async {
    final p = _produto(codigo);
    if (_vendas.any((v) => v.produtoCodigo == codigo)) {
      p.ativo = false;
      return false;
    }
    _produtos.remove(p);
    return true;
  }

  @override
  Future<int> ajustarEstoque({
    required String codigo,
    required int delta,
    required String motivo,
    String? documento,
    String? observacao,
    double? valorUnitario,
  }) async {
    final p = _produto(codigo);
    if (p.quantidade + delta < 0) {
      throw ErroCic('Estoque insuficiente para o código $codigo: saldo atual ${p.quantidade}.', codigo: 'ESTOQUE_INSUFICIENTE');
    }
    p.quantidade += delta;
    final v = valorUnitario ?? p.valorCompra;
    _movs.insert(0, Movimentacao(
      id: _id(), tipo: delta >= 0 ? 'ENTRADA' : 'SAIDA', motivo: motivo, produtoCodigo: codigo, produtoNome: p.nome,
      quantidade: delta.abs(), valorUnitario: v, valorTotal: v * delta.abs(), dataHora: DateTime.now(),
      documento: documento, observacao: observacao,
    ));
    _gerarAlertas();
    return p.quantidade;
  }

  @override
  Future<Set<String>> documentosJaLancados(List<String> documentos) async =>
      {for (final m in _movs) if (m.documento != null && documentos.contains(m.documento)) m.documento!};

  @override
  Future<String> registrarVenda({
    required List<ItemCarrinho> itens,
    required String formaPagamento,
    String? operador,
    double descontoPct = 0,
  }) async {
    if (itens.isEmpty) throw ErroCic('Adicione ao menos um item.', codigo: 'ITENS_VAZIOS');
    for (final i in itens) {
      final p = _produto(i.produto.codigo);
      if (p.quantidade < i.quantidade) {
        throw ErroCic('Estoque insuficiente para o código ${p.codigo}: saldo atual ${p.quantidade}.', codigo: 'ESTOQUE_INSUFICIENTE');
      }
    }
    final idVenda = 'v${_id()}';
    final agora = DateTime.now();
    for (final i in itens) {
      final p = _produto(i.produto.codigo);
      p.quantidade -= i.quantidade;
      p.vendidas += i.quantidade;
      _vendas.insert(0, VendaItemHistorico(
        id: _id(), vendaId: idVenda, produtoCodigo: p.codigo, nomeProduto: p.nome, quantidade: i.quantidade,
        valorUnitario: p.valorVenda, custoUnitario: p.valorCompra, data: agora, metodoPagamento: formaPagamento,
        desconto: descontoPct,
      ));
      _movs.insert(0, Movimentacao(
        id: _id(), tipo: 'SAIDA', motivo: 'VENDA', produtoCodigo: p.codigo, produtoNome: p.nome,
        quantidade: i.quantidade, valorUnitario: p.valorVenda, valorTotal: p.valorVenda * i.quantidade,
        dataHora: agora, documento: idVenda,
      ));
    }
    _gerarAlertas();
    return idVenda;
  }

  @override
  Future<List<VendaItemHistorico>> vendas({DateTime? desde}) async =>
      [for (final v in _vendas) if (desde == null || !v.data.isBefore(desde)) v];

  @override
  Future<List<Movimentacao>> movimentacoes({int limite = 500}) async => _movs.take(limite).toList();

  @override
  Future<List<CustoOperacional>> custos() async => List.of(_custos);

  @override
  Future<void> salvarCusto(CustoOperacional c) async {
    final i = c.id == null ? -1 : _custos.indexWhere((x) => x.id == c.id);
    final novo = CustoOperacional(
      id: c.id ?? _id(), nome: c.nome, valor: c.valor, tipo: c.tipo, categoria: c.categoria, observacao: c.observacao,
    );
    if (i < 0) {
      _custos.add(novo);
    } else {
      _custos[i] = novo;
    }
  }

  @override
  Future<void> removerCusto(String id) async => _custos.removeWhere((c) => c.id == id);

  @override
  Future<List<Alerta>> alertas() async => List.of(_alertas);

  @override
  Future<void> marcarAlertaLido(int id) async {
    for (final a in _alertas) {
      if (a.id == id) a.lido = true;
    }
  }

  @override
  Future<void> marcarTodosAlertasLidos() async {
    for (final a in _alertas) {
      a.lido = true;
    }
  }

  @override
  Future<void> salvarRelatorioIa({required String conteudo, String tipo = 'SOB_DEMANDA', Map<String, dynamic>? metricas}) async {
    _relatorios.insert(0, {
      'id': _seq++, 'tipo': tipo, 'conteudo_markdown': conteudo, 'metricas': metricas,
      'criado_em': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> relatoriosIa({int limite = 20}) async => _relatorios.take(limite).toList();

  @override
  Future<void> excluirRelatorioIa(int id) async => _relatorios.removeWhere((r) => r['id'] == id);

  @override
  Future<Map<String, dynamic>> conta() async => Map.of(_conta);

  @override
  Future<void> salvarConta(Map<String, dynamic> dados) async => _conta = Map.of(dados);

  @override
  Future<SessaoCaixa> sessaoCaixaAtual(ContaEstabelecimento conta) async =>
      _sessao ??= SessaoCaixa(id: 's1', abertaEm: DateTime.now(), operador: conta.operador, fundoTroco: conta.fundoTrocoPadrao);

  @override
  Future<SessaoCaixa> abrirNovaSessaoCaixa(String operador, double fundoTroco) async =>
      _sessao = SessaoCaixa(id: _id(), abertaEm: DateTime.now(), operador: operador, fundoTroco: fundoTroco);

  @override
  Future<SessaoCaixa> registrarMovimentoCaixa(String sessaoId, MovimentoCaixa mov) async {
    final s = _sessao!;
    if (s.fechada) throw ErroCic('Este turno já foi fechado.');
    return _sessao = SessaoCaixa(
      id: s.id, abertaEm: s.abertaEm, operador: s.operador, fundoTroco: s.fundoTroco, movimentos: [mov, ...s.movimentos],
    );
  }

  @override
  Future<void> fecharSessaoCaixa(String sessaoId) async {
    final s = _sessao!;
    _sessao = SessaoCaixa(
      id: s.id, abertaEm: s.abertaEm, operador: s.operador, fundoTroco: s.fundoTroco, movimentos: s.movimentos, fechada: true,
    );
  }

  @override
  Future<ContaEstabelecimento> contaEstabelecimento({String nomeLojaPadrao = ''}) async =>
      ContaEstabelecimento.fromJson(_conta, nomeLojaPadrao: nomeLojaPadrao);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
