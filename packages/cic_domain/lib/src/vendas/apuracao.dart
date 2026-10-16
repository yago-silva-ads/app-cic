import '../dinheiro.dart';
import '../qualidade.dart';
import '../tempo/periodo.dart';
import 'eventos.dart';

/// Totais realizados de um produto dentro da janela.
class FatoProduto {
  FatoProduto(this.produtoId);

  final String produtoId;
  String? nomeHistorico;
  int quantidadeLiquida = 0;
  int receitaLiquidaCentavos = 0;
  int cmvCentavos = 0;

  /// Falso se algum item sem custo histórico entrou: CMV/lucro indisponíveis.
  bool cmvCompleto = true;

  /// Falso se houve saída comercial sem preço histórico: receita subestimada.
  bool receitaCompleta = true;
}

class ResultadoApuracao {
  const ResultadoApuracao(this.porProduto, this.problemas);

  final Map<String, FatoProduto> porProduto;
  final List<ProblemaDados> problemas;
}

class _ItemLiquido {
  _ItemLiquido(this.venda, this.item, this.liquidoCentavos);

  final Venda venda;
  final ItemVendido item;
  final int liquidoCentavos;
  int devolvido = 0;
  int estornado = 0;
}

/// Converte eventos em fatos econômicos únicos (sem dupla contagem).
class ApuracaoRealizado {
  const ApuracaoRealizado();

  ResultadoApuracao apurar(Iterable<EventoComercial> eventos, JanelaPeriodo janela) {
    final problemas = <ProblemaDados>[];
    final unicos = <String, EventoComercial>{};
    for (final e in eventos) {
      if (unicos.containsKey(e.id)) {
        problemas.add(ProblemaDados(CodigoQualidade.eventoDuplicado, eventoId: e.id));
      } else {
        unicos[e.id] = e;
      }
    }
    final ordenados = unicos.values.toList()
      ..sort((a, b) {
        final c = a.instante.compareTo(b.instante);
        return c != 0 ? c : a.id.compareTo(b.id);
      });

    final vendas = <String, Venda>{};
    final itens = <(String, String), _ItemLiquido>{};
    for (final e in ordenados) {
      if (e is! Venda) continue;
      vendas[e.id] = e;
      final rateio = ratearProporcional(e.descontoPedidoCentavos, [
        for (final i in e.itens) i.brutoCentavos.clamp(0, 1 << 52),
      ]);
      for (var k = 0; k < e.itens.length; k++) {
        final i = e.itens[k];
        itens[(e.id, i.itemId)] = _ItemLiquido(e, i, i.brutoCentavos - rateio[k]);
      }
    }

    final fatos = <String, FatoProduto>{};
    FatoProduto fato(String id, String? nome) {
      final f = fatos.putIfAbsent(id, () => FatoProduto(id));
      f.nomeHistorico ??= nome;
      return f;
    }

    void somarCmv(FatoProduto f, int quantidade, int? custoUnitario, String eventoId) {
      if (custoUnitario == null) {
        if (f.cmvCompleto) {
          problemas.add(
            ProblemaDados(
              CodigoQualidade.custoHistoricoAusente,
              produtoId: f.produtoId,
              eventoId: eventoId,
            ),
          );
        }
        f.cmvCompleto = false;
      } else {
        f.cmvCentavos += quantidade * custoUnitario;
      }
    }

    for (final e in ordenados) {
      // Devoluções são conferidas mesmo fora da janela, para respeitar o
      // limite acumulado por item; só as de dentro da janela entram no total.
      final naJanela = janela.contem(e.instante);
      switch (e) {
        case Venda():
          if (!naJanela || e.status == StatusVenda.cancelada) break;
          for (final i in e.itens) {
            final f = fato(i.produtoId, i.nomeHistorico)
              ..quantidadeLiquida += i.quantidade
              ..receitaLiquidaCentavos += itens[(e.id, i.itemId)]!.liquidoCentavos;
            somarCmv(f, i.quantidade, i.custoUnitarioHistoricoCentavos, e.id);
          }
        case Devolucao():
          final venda = vendas[e.vendaId];
          final il = itens[(e.vendaId, e.itemId)];
          if (venda == null || il == null) {
            problemas.add(ProblemaDados(CodigoQualidade.devolucaoSemVendaOriginal, eventoId: e.id));
            break;
          }
          if (venda.status == StatusVenda.cancelada) {
            // Cancelamento já zerou a venda; não subtrair de novo.
            problemas.add(
              ProblemaDados(
                CodigoQualidade.devolucaoDeVendaCancelada,
                eventoId: e.id,
                produtoId: il.item.produtoId,
              ),
            );
            break;
          }
          final restante = il.item.quantidade - il.devolvido;
          var qtd = e.quantidade;
          if (qtd > restante) {
            problemas.add(
              ProblemaDados(
                CodigoQualidade.devolucaoAcimaDoVendido,
                eventoId: e.id,
                produtoId: il.item.produtoId,
                detalhe: 'pedido $qtd, restante $restante',
              ),
            );
            qtd = restante;
          }
          if (qtd <= 0) break;
          // Proporcional acumulado: a soma de devoluções parciais fecha
          // exatamente com o líquido do item.
          final alvo = il.liquidoCentavos * (il.devolvido + qtd) ~/ il.item.quantidade;
          final estorno = e.valorEstornadoCentavos ?? (alvo - il.estornado);
          il.devolvido += qtd;
          il.estornado += estorno;
          if (!naJanela) break;
          final f = fato(il.item.produtoId, il.item.nomeHistorico)
            ..quantidadeLiquida -= qtd
            ..receitaLiquidaCentavos -= estorno;
          final custo = il.item.custoUnitarioHistoricoCentavos;
          if (custo != null) f.cmvCentavos -= qtd * custo;
        case MovimentacaoEstoque(motivo: MotivoMovimentacao.saidaComercial):
          final origem = e.eventoOrigemId;
          if (origem != null) {
            // Baixa gerada por uma venda: o fato já foi contado pela venda.
            if (!vendas.containsKey(origem)) {
              problemas.add(
                ProblemaDados(
                  CodigoQualidade.movimentacaoVinculadaSemVenda,
                  eventoId: e.id,
                  produtoId: e.produtoId,
                ),
              );
            }
            break;
          }
          if (!naJanela) break;
          final f = fato(e.produtoId, e.nomeHistorico)..quantidadeLiquida += e.quantidade;
          final preco = e.precoUnitarioHistoricoCentavos;
          if (preco == null) {
            f.receitaCompleta = false;
            problemas.add(
              ProblemaDados(
                CodigoQualidade.precoHistoricoAusente,
                eventoId: e.id,
                produtoId: e.produtoId,
              ),
            );
          } else {
            f.receitaLiquidaCentavos += e.quantidade * preco;
          }
          somarCmv(f, e.quantidade, e.custoUnitarioHistoricoCentavos, e.id);
        case MovimentacaoEstoque():
        case MovimentoCaixa():
          // Perda, consumo, ajuste, transferência, entrada, sangria e reforço
          // não são receita de vendas.
          break;
      }
    }
    return ResultadoApuracao(fatos, problemas);
  }
}
