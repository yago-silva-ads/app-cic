import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Quando o João Paulo passar a API oficial da GS1, você troca o link aqui!
  static const String _baseUrl = 'https://world.openfoodfacts.org/api/v0/product/';
  
  // Se a GS1 exigir um token (bearer token, api-key), você vai colocar ele aqui no futuro
  // static const String _gs1Token = 'ABC-123-SEU-TOKEN-AQUI';

  // Função que vai na internet, busca o código e devolve apenas o nome em texto (String)
  static Future<String?> buscarProdutoExterno(String codigo) async {
    try {
      final url = Uri.parse('$_baseUrl$codigo.json');
      
      // Exemplo de como você passará o Token da GS1 no futuro:
      // final response = await http.get(url, headers: {'Authorization': 'Bearer $_gs1Token'});
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1) {
          // Retorna o nome do produto ou a marca
          return data['product']['product_name'] ?? data['product']['brands'];
        }
      }
      return null; // Retorna nulo se o produto não existir no banco de dados deles
    } catch (e) {
      return null; // Retorna nulo se o celular estiver sem internet
    }
  }
}