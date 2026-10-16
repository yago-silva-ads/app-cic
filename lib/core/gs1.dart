import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'catalogo_gs1.dart';

/// Valida o dígito verificador GS1 (GTIN-8/12/13/14). Leitura de câmera erra
/// com frequência; um código com dígito inválido não deve virar produto.
bool gtinValido(String codigo) {
  if (!RegExp(r'^\d+$').hasMatch(codigo)) return false;
  if (![8, 12, 13, 14].contains(codigo.length)) return false;
  final d = codigo.split('').map(int.parse).toList();
  var soma = 0;
  for (var i = 0; i < d.length - 1; i++) {
    final posDaDireita = d.length - 1 - i; // 1 = logo antes do dígito verificador
    soma += d[i] * (posDaDireita.isOdd ? 3 : 1);
  }
  return (10 - soma % 10) % 10 == d.last;
}

class ResultadoGs1 {
  const ResultadoGs1({required this.encontrado, this.nome, this.categoria, this.marca, this.origem, this.mensagem});
  final bool encontrado;
  final String? nome;
  final String? categoria;
  final String? marca;
  final String? origem;
  final String? mensagem;
}

/// Bases abertas consultadas em paralelo (mesma API, catálogos diferentes).
const _bases = [
  ('https://world.openfoodfacts.org', 'Open Food Facts'),
  ('https://br.openfoodfacts.org', 'Open Food Facts Brasil'),
  ('https://world.openbeautyfacts.org', 'Open Beauty Facts'),
  ('https://world.openproductsfacts.org', 'Open Products Facts'),
];

Future<ResultadoGs1?> _consultarBase(String base, String origem, String codigo) async {
  try {
    final r = await http
        .get(Uri.parse('$base/api/v2/product/$codigo.json?fields=product_name,product_name_pt,brands,quantity,categories'))
        .timeout(const Duration(seconds: 7));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final p = j['product'] as Map<String, dynamic>?;
    if (p == null) return null;
    final brands = '${p['brands'] ?? ''}'.trim();
    final qtd = '${p['quantity'] ?? ''}'.trim();
    var nome = '${p['product_name_pt'] ?? ''}'.trim();
    if (nome.isEmpty) nome = '${p['product_name'] ?? ''}'.trim();
    if (nome.isEmpty && brands.isNotEmpty) nome = qtd.isEmpty ? brands : '$brands ($qtd)';
    if (nome.isEmpty) return null;
    if (qtd.isNotEmpty && !nome.toLowerCase().contains(qtd.toLowerCase())) nome = '$nome $qtd';
    var cat = 'Geral';
    final cats = '${p['categories'] ?? ''}';
    if (cats.isNotEmpty) {
      final raw = cats.split(',').first.trim().replaceFirst(RegExp(r'^[a-z]{2}:'), '');
      if (raw.isNotEmpty) cat = raw[0].toUpperCase() + raw.substring(1);
    }
    return ResultadoGs1(encontrado: true, nome: nome, categoria: cat, marca: brands, origem: origem);
  } catch (_) {
    return null;
  }
}

/// Reconhece o produto pelo código de barras:
///  1. catálogo GS1 Brasil embutido (instantâneo, funciona sem internet);
///  2. quatro bases abertas em paralelo; vale a primeira que encontrar.
/// Nunca "adivinha" o produto com IA nem inventa custo, lote ou validade.
Future<ResultadoGs1> consultarGs1(String codigo) async {
  final limpo = codigo.trim().replaceAll(RegExp(r'\D'), '');
  if (limpo.isEmpty) return const ResultadoGs1(encontrado: false, mensagem: 'Código inválido.');

  final local = catalogoGs1[limpo];
  if (local != null) {
    return ResultadoGs1(encontrado: true, nome: local.$1, categoria: local.$2, marca: local.$3, origem: 'Catálogo GS1 Brasil');
  }

  final tentativas = [for (final b in _bases) _consultarBase(b.$1, b.$2, limpo)];
  final completer = Completer<ResultadoGs1?>();
  var pendentes = tentativas.length;
  for (final t in tentativas) {
    t.then((r) {
      pendentes--;
      if (r != null && !completer.isCompleted) completer.complete(r);
      if (pendentes == 0 && !completer.isCompleted) completer.complete(null);
    });
  }
  final achado = await completer.future;
  if (achado != null) return achado;
  return const ResultadoGs1(
    encontrado: false,
    mensagem: 'Produto não encontrado no catálogo GS1 nem nas bases abertas. Preencha o nome para cadastrar (o código já fica salvo).',
  );
}
