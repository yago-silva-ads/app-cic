import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/produto.dart';

class IaService {
  // Busca a chave de forma segura no cofre do .env:
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<String> analisarEstoque(List<Produto> estoque) async {
    if (estoque.isEmpty) {
      return "O seu estoque está vazio. Adicione produtos para gerar uma análise.";
    }
    
    if (_apiKey.isEmpty) {
      return "⚠️ ERRO: Chave da API não encontrada no arquivo .env.";
    }

    try {
      final model = GenerativeModel(model: 'gemini-3.5-flash', apiKey: _apiKey);

      final buffer = StringBuffer();
      buffer.writeln("Você é um Consultor Executivo de Inteligência de Mercado. Avalie este estoque empresarial e forneça 3 diagnósticos rápidos (em tópicos com emojis) focando na agressividade de preços, competitividade de mercado e mitigação de riscos de falência.\n");

      for (var p in estoque.take(15)) {
        buffer.writeln("- ${p.nome}: Qtd ${p.quantidade}, Custo R\$${p.valorCompra}, Venda R\$${p.valorVenda}");
      }

      final response = await model.generateContent([Content.text(buffer.toString())]);
      return response.text ?? "Análise concluída, mas sem texto retornado.";
    } catch (e) {
      return "❌ ERRO DE LIGAÇÃO INTERNA: O emulador/telemóvel está sem internet ou bloqueou o pedido. Detalhe: $e";
    }
  }

  static Future<String> analisarProduto(Produto produto) async {
    if (_apiKey.isEmpty) {
      return "⚠️ ERRO: Chave da API não encontrada no arquivo .env.";
    }

    try {
      final model = GenerativeModel(model: 'gemini-3.5-flash', apiKey: _apiKey);

      final prompt = "Aja como um Estrategista de Varejo. Avalie o produto: ${produto.nome} (Estoque: ${produto.quantidade}, Preço de Custo: R\$${produto.valorCompra}, Preço de Venda: R\$${produto.valorVenda}). Crie uma estratégia agressiva e curta em tópicos sobre margem de lucro sugerida versus preço competitivo praticado pelo mercado.";

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "Análise concluída, mas sem texto retornado.";
    } catch (e) {
      return "❌ ERRO DE LIGAÇÃO INTERNA: $e";
    }
  }
}