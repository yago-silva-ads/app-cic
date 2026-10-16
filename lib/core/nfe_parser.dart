import 'package:xml/xml.dart';

import 'gs1.dart';

/// Item de uma NF-e. Nada aqui é inventado: campo ausente fica nulo/vazio e
/// o item é sinalizado em [avisos] para o lojista conferir.
class ItemNfe {
  ItemNfe({
    required this.numero,
    required this.codigoProduto,
    required this.codigoBarras,
    required this.semGtin,
    required this.descricao,
    required this.unidade,
    required this.quantidade,
    required this.valorUnitario,
    required this.valorTotal,
    this.lote = '',
    this.validade,
    this.avisos = const [],
  });

  final int numero;
  final String codigoProduto;
  String codigoBarras;
  final bool semGtin;
  final String descricao;
  final String unidade;
  double quantidade;
  double valorUnitario;
  final double valorTotal;
  final String lote;
  final DateTime? validade;
  final List<String> avisos;

  bool get quantidadeInteira => quantidade == quantidade.roundToDouble();
}

class NotaFiscal {
  NotaFiscal({
    required this.chave,
    required this.numero,
    required this.serie,
    required this.emissao,
    required this.naturezaOperacao,
    required this.emitenteNome,
    required this.emitenteCnpj,
    required this.valorTotal,
    required this.itens,
  });

  final String? chave;
  final String numero;
  final String serie;
  final String emissao;
  final String naturezaOperacao;
  final String emitenteNome;
  final String emitenteCnpj;
  final double valorTotal;
  final List<ItemNfe> itens;

  /// Identificador estável da nota para impedir importação em duplicidade.
  String get idDocumento => chave ?? 'NF-$emitenteCnpj-$serie-$numero';
}

class ErroNfe implements Exception {
  ErroNfe(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

String _texto(XmlElement? pai, String tag) {
  if (pai == null) return '';
  final e = pai.findAllElements(tag).firstOrNull;
  return e?.innerText.trim() ?? '';
}

double? _numero(String s) => s.isEmpty ? null : double.tryParse(s);

/// Interpreta o XML de uma NF-e/NFC-e (modelos 55 e 65).
NotaFiscal interpretarNfe(String xml) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(xml.trim());
  } on XmlException catch (e) {
    throw ErroNfe('O arquivo não é um XML válido: ${e.message}');
  }

  final infNFe = doc.findAllElements('infNFe').firstOrNull;
  var chave = (infNFe?.getAttribute('Id') ?? '').replaceAll(RegExp(r'\D'), '');
  if (chave.isEmpty) chave = _texto(doc.rootElement, 'chNFe').replaceAll(RegExp(r'\D'), '');

  final ide = doc.findAllElements('ide').firstOrNull;
  final emit = doc.findAllElements('emit').firstOrNull;
  final emitNome = _texto(emit, 'xFant').isNotEmpty ? _texto(emit, 'xFant') : _texto(emit, 'xNome');
  final emitCnpj = _texto(emit, 'CNPJ').isNotEmpty ? _texto(emit, 'CNPJ') : _texto(emit, 'CPF');
  final raw = _texto(ide, 'dhEmi').isNotEmpty ? _texto(ide, 'dhEmi') : _texto(ide, 'dEmi');

  final icmsTot = doc.findAllElements('ICMSTot').firstOrNull;
  final dets = doc.findAllElements('det').toList();
  final itens = <ItemNfe>[];

  for (final det in dets) {
    final prod = det.findElements('prod').firstOrNull;
    if (prod == null) continue;
    final n = itens.length + 1;
    final avisos = <String>[];

    final cProd = _texto(prod, 'cProd');
    var cEan = _texto(prod, 'cEAN');
    if (cEan.isEmpty || cEan.toUpperCase().contains('SEM GTIN')) cEan = _texto(prod, 'cEANTrib');
    final semGtin = cEan.isEmpty || cEan.toUpperCase().contains('SEM GTIN');
    final codigo = semGtin ? cProd : cEan;
    if (semGtin) {
      avisos.add('Sem GTIN na nota: usando o código interno do fornecedor. Ajuste se quiser o código de barras.');
    } else if (!gtinValido(cEan)) {
      avisos.add('GTIN com dígito verificador inválido. Confira o código.');
    }

    final desc = _texto(prod, 'xProd');
    final qCom = _numero(_texto(prod, 'qCom'));
    final vUn = _numero(_texto(prod, 'vUnCom'));
    final vProd = _numero(_texto(prod, 'vProd'));
    if (desc.isEmpty || qCom == null || vUn == null) {
      avisos.add('Item incompleto no XML (descrição, quantidade ou valor ausente): não será importado.');
    }
    final unidade = _texto(prod, 'uCom');
    final qtd = qCom ?? 0;
    if (qCom != null && qCom != qCom.roundToDouble()) {
      avisos.add('Quantidade fracionada ($qCom $unidade). O app controla unidades inteiras: informe a quantidade em unidades.');
    }
    if (RegExp(r'^(CX|FD|FARDO|CAIXA|PCT/|DZ|DUZIA|KG|LT|L|G|ML)', caseSensitive: false).hasMatch(unidade)) {
      avisos.add('Unidade "$unidade": confirme se a quantidade é em unidades de venda, não em caixas/peso.');
    }

    final rastro = det.findElements('rastro').firstOrNull;
    final dVal = _texto(rastro, 'dVal');
    itens.add(ItemNfe(
      numero: n,
      codigoProduto: cProd,
      codigoBarras: codigo,
      semGtin: semGtin,
      descricao: desc,
      unidade: unidade,
      quantidade: qtd,
      valorUnitario: vUn ?? 0,
      valorTotal: vProd ?? (vUn ?? 0) * qtd,
      lote: _texto(rastro, 'nLote'),
      validade: dVal.isEmpty ? null : DateTime.tryParse(dVal),
      avisos: avisos,
    ));
  }

  if (itens.isEmpty) {
    throw ErroNfe('Nenhum item (<det><prod>) foi encontrado no XML. Confira se é o XML da NF-e.');
  }

  final vNF = _numero(_texto(icmsTot, 'vNF'));
  return NotaFiscal(
    chave: chave.isEmpty ? null : chave,
    numero: _texto(ide, 'nNF'),
    serie: _texto(ide, 'serie'),
    emissao: raw.length >= 10 ? raw.substring(0, 10) : raw,
    naturezaOperacao: _texto(ide, 'natOp'),
    emitenteNome: emitNome,
    emitenteCnpj: emitCnpj,
    valorTotal: vNF ?? itens.fold(0.0, (s, i) => s + i.valorTotal),
    itens: itens,
  );
}
