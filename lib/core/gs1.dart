import 'dart:convert';

import 'package:http/http.dart' as http;

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

/// Consulta o nome do produto na Open Food Facts. Não inventa custo, lote nem
/// validade: esses dados só valem se vierem da nota ou do produto físico.
Future<ResultadoGs1> consultarGs1(String codigo) async {
  final limpo = codigo.trim().replaceAll(RegExp(r'\D'), '');
  if (limpo.isEmpty) return const ResultadoGs1(encontrado: false, mensagem: 'Código inválido.');
  try {
    final r = await http
        .get(Uri.parse('https://world.openfoodfacts.org/api/v2/product/$limpo.json?fields=product_name,product_name_pt,brands,quantity,categories'))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode == 200) {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final p = j['product'] as Map<String, dynamic>?;
      if (p != null) {
        final brands = '${p['brands'] ?? ''}'.trim();
        final qtd = '${p['quantity'] ?? ''}'.trim();
        var nome = '${p['product_name_pt'] ?? p['product_name'] ?? ''}'.trim();
        if (nome.isEmpty && brands.isNotEmpty) nome = qtd.isEmpty ? brands : '$brands ($qtd)';
        if (nome.isNotEmpty) {
          var cat = 'Geral';
          final cats = '${p['categories'] ?? ''}';
          if (cats.isNotEmpty) {
            final raw = cats.split(',').first.trim().replaceFirst(RegExp(r'^(en|pt):'), '');
            if (raw.isNotEmpty) cat = raw[0].toUpperCase() + raw.substring(1);
          }
          return ResultadoGs1(encontrado: true, nome: nome, categoria: cat, marca: brands, origem: 'Open Food Facts');
        }
      }
    }
    return const ResultadoGs1(encontrado: false, mensagem: 'Produto não encontrado nas bases abertas. Preencha o nome para cadastrar.');
  } catch (_) {
    return const ResultadoGs1(encontrado: false, mensagem: 'Não foi possível consultar a base de produtos agora (sem conexão). Preencha o nome para cadastrar.');
  }
}
