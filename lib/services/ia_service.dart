import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/produto.dart';

class IaService {
  // 🔐 Chave API da Google Gemini
  static const _apiKey = "AIzaSyBBGTyiuScuiCCLt5VdG3CBWofjv1k7M9U";
  
  // Link direto e oficial da API REST do Gemini
 static const _url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$_apiKey";



  static Future<String> analisarEstoque(List<Produto> estoque) async {
    if (estoque.isEmpty) return "Seu estoque está vazio.";
    try {
      print('\n=========================================');
      print('🚀 MODELO UNIVERSAL GEMINI-PRO INICIADO!');
      print('=========================================\n');

      final buffer = StringBuffer();
      buffer.writeln("Você é um consultor financeiro. Analise o estoque e gere 3 insights curtos sobre margem, giro e risco em formato Markdown.");
      for (var p in estoque.take(10)) {
        buffer.writeln("- ${p.nome}: Qtd ${p.quantidade}, Compra R\$${p.valorCompra}, Venda R\$${p.valorVenda}");
      }

      print('DEBUG IA: Enviando requisição REST direta para o Gemini...');
      
      final response = await http.post(
        Uri.parse(_url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [{"text": buffer.toString()}]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          print('DEBUG IA: Sucesso!');
          return data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
        }
      }
      
      // Mostra o erro real que o servidor devolveu
      return "Erro do Servidor (Status ${response.statusCode}):\n${response.body}";
    } catch (e) {
      print('ERRO FATAL IA: $e');
      return "Erro de conexão. O emulador está sem internet ou bloqueando a requisição:\n$e";
    }
  }

  static Future<String> analisarProduto(Produto produto) async {
    try {
      print('\n=========================================');
      print('🚀 MODELO UNIVERSAL GEMINI-PRO INICIADO!');
      print('=========================================\n');

      final prompt = "Você é um consultor financeiro. Analise o produto ${produto.nome} (Qtd ${produto.quantidade}, Compra R\$${produto.valorCompra}, Venda R\$${produto.valorVenda}) e gere insights curtos sobre margem e risco em formato Markdown.";
      
      print('DEBUG IA: Analisando produto via REST Gemini...');
      
      final response = await http.post(
        Uri.parse(_url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [{"text": prompt}]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          print('DEBUG IA: Sucesso!');
          return data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
        }
      }
      
      return "Erro do Servidor (Status ${response.statusCode}):\n${response.body}";
    } catch (e) {
      print('ERRO FATAL IA PRODUTO: $e');
      return "Erro de conexão:\n$e";
    }
  }
}