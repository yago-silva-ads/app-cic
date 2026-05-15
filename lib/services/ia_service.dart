import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/produto.dart';

class IaService {
  //  FIM DA BUROCRACIA: Pollinations AI (Livre, Open-Source, SEM CHAVE, SEM BLOQUEIO)
  // Essa API pública processa a requisição imediatamente e devolve o texto pronto.
  static const _url = "https://text.pollinations.ai/";

  static Future<String> analisarEstoque(List<Produto> estoque) async {
    if (estoque.isEmpty) return "Seu estoque está vazio.";
    try {
      print('\n=========================================');
      print('🚀 IA DE VERDADE INICIADA (POLLINATIONS)!');
      print('=========================================\n');

      final buffer = StringBuffer();
      for (var p in estoque.take(10)) {
        buffer.writeln("- ${p.nome}: Qtd ${p.quantidade}, Compra R\$${p.valorCompra}, Venda R\$${p.valorVenda}");
      }

      print('DEBUG IA: Enviando dados do estoque...');
      
      final response = await http.post(
        Uri.parse(_url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "messages": [
            {"role": "system", "content": "Você é um consultor financeiro. Responda em português do Brasil. Analise o estoque e gere 3 insights estratégicos sobre margem, giro e risco. NÃO use tabelas ou matrizes. Use apenas tópicos curtos (bullet points) com emojis."},
            {"role": "user", "content": buffer.toString()}
          ],
          "model": "openai" // Usa modelos avançados de graça
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        print('DEBUG IA: Sucesso Absoluto!');
        // A API livre não tem JSON complexo com frescura, devolve o texto puro no body!
        return response.body.trim();
      }
      
      return "Erro do Servidor (Status ${response.statusCode}):\n${response.body}";
    } catch (e) {
      print('ERRO FATAL IA: $e');
      return "Erro de conexão:\n$e";
    }
  }

  static Future<String> analisarProduto(Produto produto) async {
    try {
      print('\n=========================================');
      print('🚀 IA DE VERDADE INICIADA PARA PRODUTO!');
      print('=========================================\n');

      final prompt = "Analise o produto ${produto.nome} (Qtd ${produto.quantidade}, Compra R\$${produto.valorCompra}, Venda R\$${produto.valorVenda}) e gere insights curtos sobre margem e risco em formato Markdown.";
      
      print('DEBUG IA: Analisando produto...');
      
      final response = await http.post(
        Uri.parse(_url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "messages": [
            {"role": "system", "content": "Você é um consultor financeiro especialista. Responda em português. Gere um resumo em tópicos com emojis. NÃO crie tabelas e nem matrizes."},
            {"role": "user", "content": prompt}
          ],
          "model": "openai"
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        print('DEBUG IA: Sucesso Absoluto!');
        return response.body.trim();
      }
      
      return "Erro do Servidor (Status ${response.statusCode}):\n${response.body}";
    } catch (e) {
      print('ERRO FATAL IA PRODUTO: $e');
      return "Erro de conexão:\n$e";
    }
  }
}