// lib/domain/contracts/abc_contract.dart
// Contrato matemático versionado 'abc-v1' conforme especificação técnica APP_CIC_PROMPT_UPGRADE.md
// Garante paridade absoluta entre a versão Web e o aplicativo Flutter/Dart.

enum AbcCategory { A, B, C }

enum AbcPeriodType { hoje, seteDias, mes, todos, projetado }

class AbcItemResult {
  final String produtoId;
  final String nome;
  final int unidadesVendidas;
  final int faturamentoCentavos; // Valores em centavos inteiros (evita erros de arredondamento)
  final int custoHistoricoCentavos;
  final int lucroCentavos;
  final double percentualFaturamento;
  final double percentualAcumulado;
  final AbcCategory categoria;

  const AbcItemResult({
    required this.produtoId,
    required this.nome,
    required this.unidadesVendidas,
    required this.faturamentoCentavos,
    required this.custoHistoricoCentavos,
    required this.lucroCentavos,
    required this.percentualFaturamento,
    required this.percentualAcumulado,
    required this.categoria,
  });

  Map<String, dynamic> toJson() => {
    'produtoId': produtoId,
    'nome': nome,
    'unidadesVendidas': unidadesVendidas,
    'faturamentoCentavos': faturamentoCentavos,
    'custoHistoricoCentavos': custoHistoricoCentavos,
    'lucroCentavos': lucroCentavos,
    'percentualFaturamento': percentualFaturamento,
    'percentualAcumulado': percentualAcumulado,
    'categoria': categoria.name,
  };
}

class AbcReportResult {
  final String versaoContrato = 'abc-v1';
  final String timezone = 'America/Sao_Paulo';
  final AbcPeriodType periodo;
  final DateTime dataInicioCivil;
  final DateTime dataFimCivil;
  final int totalFaturamentoCentavos;
  final int totalLucroCentavos;
  final List<AbcItemResult> itens;

  const AbcReportResult({
    required this.periodo,
    required this.dataInicioCivil,
    required this.dataFimCivil,
    required this.totalFaturamentoCentavos,
    required this.totalLucroCentavos,
    required this.itens,
  });

  Map<String, dynamic> toJson() => {
    'versaoContrato': versaoContrato,
    'timezone': timezone,
    'periodo': periodo.name,
    'dataInicioCivil': dataInicioCivil.toIso8601String(),
    'dataFimCivil': dataFimCivil.toIso8601String(),
    'totalFaturamentoCentavos': totalFaturamentoCentavos,
    'totalLucroCentavos': totalLucroCentavos,
    'itens': itens.map((i) => i.toJson()).toList(),
  };
}
