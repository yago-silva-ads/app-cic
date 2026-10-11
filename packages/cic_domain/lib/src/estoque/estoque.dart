import '../qualidade.dart';
import '../tempo/fuso_loja.dart';

/// Produto com ID estável. Código de barras é string (preserva zeros à esquerda).
class Produto {
  const Produto({
    required this.id,
    required this.nome,
    this.codigoBarras,
    this.precoVendaAtualCentavos,
    this.custoAtualCentavos,
    this.arquivado = false,
  });

  final String id;
  final String nome;
  final String? codigoBarras;

  /// Preço e custo ATUAIS: servem só para o cenário projetado, nunca para
  /// reconstruir receita ou CMV históricos.
  final int? precoVendaAtualCentavos;
  final int? custoAtualCentavos;
  final bool arquivado;

  factory Produto.fromJson(Map<String, Object?> j) => Produto(
    id: j['id'] as String,
    nome: j['nome'] as String,
    codigoBarras: j['codigoBarras'] as String?,
    precoVendaAtualCentavos: j['precoVendaAtualCentavos'] as int?,
    custoAtualCentavos: j['custoAtualCentavos'] as int?,
    arquivado: j['arquivado'] as bool? ?? false,
  );
}

/// Lote físico. Vários lotes do mesmo produto somam no saldo; a validade fica
/// por lote.
class Lote {
  const Lote({
    required this.id,
    required this.produtoId,
    required this.quantidadeFisica,
    this.quantidadeReservada = 0,
    this.validade,
  });

  final String id;
  final String produtoId;
  final int quantidadeFisica;
  final int quantidadeReservada;
  final DataCivil? validade;

  factory Lote.fromJson(Map<String, Object?> j) {
    final validade = j['validade'] as String?;
    return Lote(
      id: j['id'] as String,
      produtoId: j['produtoId'] as String,
      quantidadeFisica: j['quantidadeFisica'] as int,
      quantidadeReservada: j['quantidadeReservada'] as int? ?? 0,
      validade: validade == null ? null : _parseData(validade),
    );
  }
}

DataCivil _parseData(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DataCivil(p[0], p[1], p[2]);
}

/// Foto consistente do estoque de UMA loja, com versão e horário.
///
/// [produtosSemSaldoConhecido] marca produtos cujo saldo não pôde ser lido
/// (falha parcial). Se [carregado] for falso, todo saldo é desconhecido:
/// falha de carregamento não equivale a estoque zero.
class SnapshotEstoque {
  const SnapshotEstoque({
    required this.versao,
    required this.atualizadoEm,
    required this.produtos,
    required this.lotes,
    this.carregado = true,
    this.produtosSemSaldoConhecido = const {},
    this.demonstracao = false,
  });

  final String versao;
  final DateTime atualizadoEm;
  final List<Produto> produtos;
  final List<Lote> lotes;
  final bool carregado;
  final Set<String> produtosSemSaldoConhecido;
  final bool demonstracao;

  factory SnapshotEstoque.fromJson(Map<String, Object?> j) => SnapshotEstoque(
    versao: j['versao'] as String,
    atualizadoEm: DateTime.parse(j['atualizadoEm'] as String).toUtc(),
    produtos: [for (final p in j['produtos'] as List) Produto.fromJson((p as Map).cast())],
    lotes: [for (final l in j['lotes'] as List? ?? const []) Lote.fromJson((l as Map).cast())],
    carregado: j['carregado'] as bool? ?? true,
    produtosSemSaldoConhecido: {
      ...(j['produtosSemSaldoConhecido'] as List? ?? const []).cast<String>(),
    },
    demonstracao: j['demonstracao'] as bool? ?? false,
  );
}

class SaldoProduto {
  const SaldoProduto._({
    required this.produto,
    required this.fisico,
    required this.reservado,
    required this.quantidadeLotes,
    required this.proximaValidade,
  });

  final Produto produto;

  /// `null` = desconhecido.
  final int? fisico;
  final int? reservado;
  final int quantidadeLotes;
  final DataCivil? proximaValidade;

  bool get conhecido => fisico != null;

  /// Físico − reservado. `null` quando desconhecido.
  int? get disponivel => fisico == null ? null : fisico! - (reservado ?? 0);
}

class ResumoEstoque {
  const ResumoEstoque({
    required this.produtosCadastrados,
    required this.produtosComSaldo,
    required this.produtosSemSaldoConhecido,
    required this.unidadesFisicas,
    required this.unidadesDisponiveis,
    required this.quantidadeLotes,
    required this.problemas,
    required this.snapshotVersion,
    required this.atualizadoEm,
  });

  /// Produtos ativos (não arquivados) cadastrados, com ou sem saldo.
  final int produtosCadastrados;

  /// Produtos ativos com saldo DISPONÍVEL > 0. É a definição de
  /// "produtos em estoque" usada no dashboard, no chat e nos testes.
  final int produtosComSaldo;
  final int produtosSemSaldoConhecido;

  /// Somam apenas saldos conhecidos e positivos; ver [completo].
  final int unidadesFisicas;
  final int unidadesDisponiveis;
  final int quantidadeLotes;
  final List<ProblemaDados> problemas;
  final String snapshotVersion;
  final DateTime atualizadoEm;

  /// Falso quando algum saldo é desconhecido: os totais são parciais.
  bool get completo => produtosSemSaldoConhecido == 0;

  Map<String, Object?> toJson() => {
    'produtosCadastrados': produtosCadastrados,
    'produtosComSaldo': produtosComSaldo,
    'produtosSemSaldoConhecido': produtosSemSaldoConhecido,
    'unidadesFisicas': unidadesFisicas,
    'unidadesDisponiveis': unidadesDisponiveis,
    'quantidadeLotes': quantidadeLotes,
    'completo': completo,
    'problemas': [for (final p in problemas) p.toJson()],
    'snapshotVersion': snapshotVersion,
    'atualizadoEm': atualizadoEm.toIso8601String(),
  };
}

class EstoqueService {
  const EstoqueService();

  /// Saldo agregado por produto (todos os lotes), indexado pelo ID.
  Map<String, SaldoProduto> saldos(SnapshotEstoque snap) {
    final porProduto = <String, List<Lote>>{};
    for (final l in snap.lotes) {
      porProduto.putIfAbsent(l.produtoId, () => []).add(l);
    }
    return {for (final p in snap.produtos) p.id: _saldo(snap, p, porProduto[p.id] ?? const [])};
  }

  SaldoProduto _saldo(SnapshotEstoque snap, Produto p, List<Lote> lotes) {
    final desconhecido = !snap.carregado || snap.produtosSemSaldoConhecido.contains(p.id);
    DataCivil? validade;
    for (final l in lotes) {
      final v = l.validade;
      if (v != null && l.quantidadeFisica > 0 && (validade == null || v.compareTo(validade) < 0)) {
        validade = v;
      }
    }
    return SaldoProduto._(
      produto: p,
      fisico: desconhecido ? null : lotes.fold<int>(0, (s, l) => s + l.quantidadeFisica),
      reservado: desconhecido ? null : lotes.fold<int>(0, (s, l) => s + l.quantidadeReservada),
      quantidadeLotes: lotes.length,
      proximaValidade: validade,
    );
  }

  ResumoEstoque resumir(SnapshotEstoque snap) {
    final problemas = <ProblemaDados>[];
    final idsConhecidos = {for (final p in snap.produtos) p.id};
    for (final l in snap.lotes) {
      if (!idsConhecidos.contains(l.produtoId)) {
        problemas.add(
          ProblemaDados(
            CodigoQualidade.produtoDesconhecido,
            produtoId: l.produtoId,
            detalhe: 'Lote ${l.id} sem produto cadastrado',
          ),
        );
      }
    }
    var cadastrados = 0, comSaldo = 0, semSaldo = 0, fisicas = 0, disponiveis = 0, lotes = 0;
    for (final s in saldos(snap).values) {
      if (s.produto.arquivado) continue;
      cadastrados++;
      lotes += s.quantidadeLotes;
      final fisico = s.fisico;
      final disp = s.disponivel;
      if (fisico == null || disp == null) {
        semSaldo++;
        problemas.add(ProblemaDados(CodigoQualidade.estoqueDesconhecido, produtoId: s.produto.id));
        continue;
      }
      if (fisico < 0) {
        problemas.add(
          ProblemaDados(
            CodigoQualidade.estoqueNegativo,
            produtoId: s.produto.id,
            detalhe: 'saldo físico $fisico',
          ),
        );
      } else if (disp < 0) {
        problemas.add(
          ProblemaDados(CodigoQualidade.reservaMaiorQueFisico, produtoId: s.produto.id),
        );
      }
      if (fisico > 0) fisicas += fisico;
      if (disp > 0) {
        disponiveis += disp;
        comSaldo++;
      }
    }
    return ResumoEstoque(
      produtosCadastrados: cadastrados,
      produtosComSaldo: comSaldo,
      produtosSemSaldoConhecido: semSaldo,
      unidadesFisicas: fisicas,
      unidadesDisponiveis: disponiveis,
      quantidadeLotes: lotes,
      problemas: problemas,
      snapshotVersion: snap.versao,
      atualizadoEm: snap.atualizadoEm,
    );
  }
}
