import 'package:cic_domain/cic_domain.dart' as dom;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../data/conta.dart';
import '../data/models.dart';
import '../data/repository.dart';

/// Estado global do app logado: dados da loja (vindos do Supabase), tema e
/// ponte para a camada de domínio (`cic_domain`).
class AppState extends ChangeNotifier {
  AppState({CicRepository? repo, required this.tema}) : repo = repo ?? CicRepository();

  final CicRepository repo;
  final TemaController tema;

  List<Produto> estoque = [];
  List<CustoOperacional> custos = [];
  List<Alerta> alertas = [];
  List<Movimentacao> movimentacoes = [];
  List<VendaItemHistorico> vendas = [];
  ContaEstabelecimento conta = ContaEstabelecimento();

  bool carregando = false;
  bool carregouUmaVez = false;

  /// Mensagens de erro por área. Falha de leitura nunca vira "lista vazia".
  final Map<String, String> erros = {};
  DateTime? atualizadoEm;
  int _geracao = 0;

  Usuario? get usuario {
    if (Config.demo) {
      return Usuario(id: 'demo', email: 'demo@app-cic', nome: 'Ana', lojaNome: 'Mercadinho Bom Preço');
    }
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) return null;
    final meta = u.userMetadata ?? const {};
    final email = u.email ?? '';
    return Usuario(
      id: u.id,
      email: email,
      nome: '${meta['nome'] ?? (email.contains('@') ? email.split('@').first : 'Lojista')}',
      lojaNome: '${meta['lojaNome'] ?? 'Minha Loja'}',
    );
  }

  int get alertasNaoLidos => alertas.where((a) => !a.lido).length;
  bool get estoqueConfiavel => !erros.containsKey('estoque') && carregouUmaVez;

  Future<void> carregar() async {
    final minhaGeracao = ++_geracao;
    carregando = true;
    notifyListeners();

    final novosErros = <String, String>{};
    Future<T?> ler<T>(String area, Future<T> Function() f) async {
      try {
        return await f();
      } on ErroCic catch (e) {
        novosErros[area] = e.mensagem;
      } catch (_) {
        novosErros[area] = 'Falha inesperada ao carregar $area.';
      }
      return null;
    }

    final r = await Future.wait<Object?>([
      ler('estoque', repo.produtos),
      ler('custos', repo.custos),
      ler('alertas', repo.alertas),
      ler('movimentações', repo.movimentacoes),
      ler('vendas', repo.vendas),
      ler('conta', () => repo.contaEstabelecimento(nomeLojaPadrao: usuario?.lojaNome ?? '')),
    ]);

    // Resposta atrasada de uma carga anterior não sobrescreve a mais nova.
    if (minhaGeracao != _geracao) return;

    estoque = (r[0] as List<Produto>?) ?? (novosErros.containsKey('estoque') ? estoque : []);
    custos = (r[1] as List<CustoOperacional>?) ?? custos;
    alertas = (r[2] as List<Alerta>?) ?? alertas;
    movimentacoes = (r[3] as List<Movimentacao>?) ?? movimentacoes;
    vendas = (r[4] as List<VendaItemHistorico>?) ?? vendas;
    conta = (r[5] as ContaEstabelecimento?) ?? conta;

    erros
      ..clear()
      ..addAll(novosErros);
    carregando = false;
    carregouUmaVez = true;
    atualizadoEm = DateTime.now();
    notifyListeners();
  }

  /// Limpa tudo ao sair: nada da loja anterior fica na memória.
  void limpar() {
    _geracao++;
    estoque = [];
    custos = [];
    alertas = [];
    movimentacoes = [];
    vendas = [];
    conta = ContaEstabelecimento();
    erros.clear();
    carregouUmaVez = false;
    carregando = false;
    atualizadoEm = null;
    notifyListeners();
  }

  // ===================== Ações (sempre recarregam do banco) =====================

  Future<int> salvarProduto(Produto p, {bool somar = true}) async {
    final saldo = await repo.salvarProduto(p, somar: somar);
    await carregar();
    return saldo;
  }

  Future<bool> removerProduto(String codigo) async {
    final apagado = await repo.removerOuArquivarProduto(codigo);
    await carregar();
    return apagado;
  }

  Future<void> ajustarEstoque({
    required String codigo,
    required int delta,
    required String motivo,
    String? documento,
    String? observacao,
    double? valorUnitario,
  }) async {
    await repo.ajustarEstoque(
      codigo: codigo,
      delta: delta,
      motivo: motivo,
      documento: documento,
      observacao: observacao,
      valorUnitario: valorUnitario,
    );
    await carregar();
  }

  Future<String> finalizarVenda({
    required List<ItemCarrinho> itens,
    required String formaPagamento,
    String? operador,
    double descontoPct = 0,
  }) async {
    final id = await repo.registrarVenda(
      itens: itens,
      formaPagamento: formaPagamento,
      operador: operador,
      descontoPct: descontoPct,
    );
    await carregar();
    return id;
  }

  Future<void> salvarConta(ContaEstabelecimento nova) async {
    await repo.salvarConta(nova.toJson());
    conta = nova;
    notifyListeners();
  }

  Future<void> salvarCusto(CustoOperacional c) async {
    await repo.salvarCusto(c);
    custos = await repo.custos();
    notifyListeners();
  }

  Future<void> removerCusto(String id) async {
    await repo.removerCusto(id);
    custos = await repo.custos();
    notifyListeners();
  }

  Future<void> marcarAlertaLido(int id) async {
    await repo.marcarAlertaLido(id);
    for (final a in alertas) {
      if (a.id == id) a.lido = true;
    }
    notifyListeners();
  }

  Future<void> marcarTodosAlertasLidos() async {
    await repo.marcarTodosAlertasLidos();
    for (final a in alertas) {
      a.lido = true;
    }
    notifyListeners();
  }

  // ===================== Ponte para o domínio (cic_domain) =====================

  final dom.FusoLoja fusoLoja = dom.FusoLoja.padrao();

  /// Foto do estoque desta loja. `carregado = false` quando a leitura falhou:
  /// o domínio trata o saldo como DESCONHECIDO, nunca como zero.
  dom.SnapshotEstoque snapshot() {
    final agora = atualizadoEm ?? DateTime.now();
    final carregado = estoqueConfiavel;
    return dom.SnapshotEstoque(
      versao: 'snap-${agora.toUtc().millisecondsSinceEpoch}',
      atualizadoEm: agora.toUtc(),
      carregado: carregado,
      produtos: [
        for (final p in estoque)
          dom.Produto(
            id: p.codigo,
            nome: p.nome,
            codigoBarras: p.codigo,
            precoVendaAtualCentavos: _cent(p.valorVenda),
            custoAtualCentavos: _cent(p.valorCompra),
            arquivado: !p.ativo,
          ),
      ],
      lotes: [
        for (final p in estoque)
          dom.Lote(
            id: 'lote-${p.codigo}',
            produtoId: p.codigo,
            quantidadeFisica: p.quantidade,
            validade: p.dataValidade == null
                ? null
                : dom.DataCivil(p.dataValidade!.year, p.dataValidade!.month, p.dataValidade!.day),
          ),
      ],
    );
  }

  /// Vendas do banco como eventos do domínio. Linhas com o mesmo `venda_id`
  /// formam uma venda; legado sem `venda_id` vira uma venda por linha.
  List<dom.EventoComercial> eventosDeVenda() {
    final grupos = <String, List<VendaItemHistorico>>{};
    for (final v in vendas) {
      grupos.putIfAbsent(v.vendaId ?? 'legado-${v.id}', () => []).add(v);
    }
    return [
      for (final e in grupos.entries)
        dom.Venda(
          id: e.key,
          instante: e.value.first.data.toUtc(),
          itens: [
            for (final v in e.value)
              dom.ItemVendido(
                itemId: v.id,
                produtoId: v.produtoCodigo,
                quantidade: v.quantidade,
                precoUnitarioCentavos: _cent(v.valorUnitario),
                custoUnitarioHistoricoCentavos: v.custoUnitario == null ? null : _cent(v.custoUnitario!),
                nomeHistorico: v.nomeProduto,
              ),
          ],
          descontoPedidoCentavos: _descontoPedido(e.value),
        ),
    ];
  }

  int _descontoPedido(List<VendaItemHistorico> itens) {
    final pct = itens.first.desconto;
    if (pct <= 0) return 0;
    final bruto = itens.fold<int>(0, (s, v) => s + v.quantidade * _cent(v.valorUnitario));
    return (bruto * pct / 100).round();
  }

  dom.ResultadoCurvaAbc curvaAbc(dom.PeriodoAbc periodo) {
    final servico = dom.CurvaAbcService(fuso: fusoLoja, relogio: const dom.RelogioSistema());
    return servico.calcular(periodo: periodo, estoque: snapshot(), eventos: eventosDeVenda());
  }

  static int _cent(double reais) => (reais * 100).round();
}
