import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/produto.dart';
import '../models/custo_operacional.dart';
import '../models/alerta.dart';
import '../secrets.dart';

class IaService {
  static const String _apiKey = Secrets.geminiApiKey;
  static Future<String> analisarEstoque(
    List<Produto> estoque,
    List<Map<String, dynamic>> historico,
    List<CustoOperacional> custos, {
    List<Alerta>? alertasAtivos,
  }) async {
    if (estoque.isEmpty) {
      return "📊 O seu estoque está vazio. Adicione produtos no PDV para gerar um diagnóstico financeiro.";
    }

    // Proteção em tempo de execução: impede crash na tela do cliente
    if (_apiKey == 'COLE_SUA_CHAVE_GEMINI_AQUI' || _apiKey.isEmpty) {
      return "⚠️ Serviço de Inteligência Temporariamente Indisponível. Por favor, tente novamente mais tarde ou contate o suporte técnico.";
    }

    // Monta o texto fora do try/catch para que ambos os planos (A e B) possam enxergar
    final buffer = StringBuffer();
    buffer.writeln(
      "Aja como um Consultor Financeiro para Microempreendedores. Fale de forma simples, direta e empática (evite termos muito difíceis). Formate sua resposta em Markdown limpo com emojis. Seu objetivo é ajudar o dono do negócio a prever vendas e colocar dinheiro no bolso (pró-labore). Crie um relatório contendo:",
    );
    buffer.writeln(
      "🔮 **1. Visões Preditivas (Semanas/Meses):** Analisando as datas das vendas recentes, qual o padrão? O que ele tende a vender mais nas próximas semanas? Há sugestões de combos para produtos parados?",
    );
    buffer.writeln(
      "💰 **2. Meta de Vendas e Pró-Labore:** Analise os Custos Fixos totais abaixo. Qual a meta de vendas mínima SÓ para pagar essas contas? O que ele deve fazer para aumentar a margem e sobrar lucro limpo pro próprio bolso?",
    );
    buffer.writeln(
      "🏷️ **3. Precificação e Inflação:** Olhando o custo vs venda, algum produto está muito barato podendo ser engolido pela inflação? Como ele pode ajustar o preço mantendo-se competitivo no mercado?\n",
    );

    buffer.writeln("--- DADOS DE ESTOQUE ---");
    for (var p in estoque.take(20)) {
      String validadeInfo = '';
      if (p.dataValidade != null) {
        final diasRestantes = p.dataValidade!.difference(DateTime.now()).inDays;
        if (diasRestantes <= 0) {
          validadeInfo = ' | ⛔ VENCIDO há ${diasRestantes.abs()} dia(s)';
        } else if (diasRestantes <= 7) {
          validadeInfo = ' | ⚠️ Vence em $diasRestantes dia(s)';
        } else if (diasRestantes <= 30) {
          validadeInfo = ' | 📅 Vence em $diasRestantes dia(s)';
        }
      }
      buffer.writeln(
        "${p.nome} - Custo: R\$${p.valorCompra}, Venda: R\$${p.valorVenda}, Qtd: ${p.quantidade}$validadeInfo",
      );
    }

    // Se há alertas ativos, inclui no contexto para a IA
    if (alertasAtivos != null && alertasAtivos.isNotEmpty) {
      buffer.writeln("\n--- ALERTAS ATIVOS DO SISTEMA ---");
      for (var a in alertasAtivos.take(10)) {
        buffer.writeln("[${a.severidade}] ${a.mensagem}");
      }
    }

    buffer.writeln("\n--- HISTÓRICO DE VENDAS RECENTES ---");
    for (var v in historico.reversed.take(30)) {
      String data = v['data_venda'] != null
          ? v['data_venda'].toString().split('T')[0]
          : 'Data Indisponível';
      buffer.writeln(
        "Data: $data | Produto ID ${v['produto_codigo']} - Qtd Vendida: ${v['quantidade_vendida']} por R\$${v['valor_unitario']}",
      );
    }

    buffer.writeln("\n--- CUSTOS OPERACIONAIS ---");
    double totalCustos = 0;
    for (var c in custos) {
      buffer.writeln("${c.nome}: R\$${c.valor}");
      totalCustos += c.valor;
    }
    buffer.writeln("Custo Fixo Total: R\$${totalCustos}\n");

    final promptFinal = buffer.toString();

    try {
      final model = GenerativeModel(model: 'gemini-3.5-flash', apiKey: _apiKey);
      final response = await model.generateContent([Content.text(promptFinal)]);
      return response.text ?? "Análise concluída, mas sem texto retornado.";
    } catch (e) {
      // PLANO B (FALLBACK): Se o 3.5 cair (Erro 503), usamos o 1.5 Flash automaticamente!
      try {
        final modelFallback = GenerativeModel(
          model: 'gemini-3.5-flash',
          apiKey: _apiKey,
        );
        final response = await modelFallback.generateContent([
          Content.text(promptFinal),
        ]);
        return response.text ?? "Análise concluída, mas sem texto retornado.";
      } catch (eFallback) {
        String errStr = eFallback.toString() + e.toString();
        print("Erro Gemini: $errStr");
        if (errStr.contains('429') ||
            errStr.toLowerCase().contains('quota') ||
            errStr.toLowerCase().contains('too many requests')) {
          return "⏳ **Aguarde um momentinho! (Limite Antispam)**\n\nVocê fez muitas análises muito rápido! Para não sobrecarregar, o sistema permite cerca de 15 consultas por minuto. Respire fundo, espere uns 30 segundinhos e tente novamente! 😊";
        } else if (errStr.contains('503') ||
            errStr.toLowerCase().contains('service unavailable')) {
          return "⚠️ **Servidores Ocupados (Google)**\n\nA Inteligência Artificial está atendendo muita gente neste exato segundo e não conseguiu processar. Aguarde uns 10 segundinhos e clique novamente.";
        }
        return "❌ **Sem conexão com a IA**\n\nVerifique se o seu Wi-Fi/Internet está funcionando bem e tente novamente em instantes.";
      }
    }
  }

  static Future<String> analisarProduto(Produto produto) async {
    if (_apiKey == 'COLE_SUA_CHAVE_GEMINI_AQUI') {
      return "⚠️ Chave da API não configurada.";
    }

    try {
      final model = GenerativeModel(model: 'gemini-3.5-flash', apiKey: _apiKey);

      final prompt =
          "Aja como um Estrategista de Varejo. Avalie o produto: ${produto.nome} (Estoque: ${produto.quantidade}, Preço de Custo: R\$${produto.valorCompra}, Preço de Venda: R\$${produto.valorVenda}). Crie uma estratégia agressiva e curta em tópicos sobre margem de lucro sugerida versus preço competitivo praticado pelo mercado.";

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "Análise concluída, mas sem texto retornado.";
    } catch (e) {
      try {
        final modelFallback = GenerativeModel(
          model: 'gemini-3.5-flash',
          apiKey: _apiKey,
        );
        final prompt =
            "Aja como um Estrategista de Varejo. Avalie o produto: ${produto.nome} (Estoque: ${produto.quantidade}, Preço de Custo: R\$${produto.valorCompra}, Preço de Venda: R\$${produto.valorVenda}). Crie uma estratégia agressiva e curta em tópicos sobre margem de lucro sugerida versus preço competitivo praticado pelo mercado.";
        final response = await modelFallback.generateContent([
          Content.text(prompt),
        ]);
        return response.text ?? "Análise concluída, mas sem texto retornado.";
      } catch (eFallback) {
        String errStr = eFallback.toString() + e.toString();
        print("Erro Gemini Produto: $errStr");
        if (errStr.contains('429') ||
            errStr.toLowerCase().contains('quota') ||
            errStr.toLowerCase().contains('too many requests')) {
          return "⏳ **Limite Antispam:** Você clicou muito rápido! Aguarde uns 30 segundinhos e tente novamente.";
        } else if (errStr.contains('503') ||
            errStr.toLowerCase().contains('service unavailable')) {
          return "⚠️ **Servidor Ocupado:** O Google está lotado agora. Aguarde 10 segundos e tente de novo.";
        }
        return "❌ **Falha de Conexão:** Verifique sua internet e tente novamente.";
      }
    }
  }

  static Future<String> continuarConversa(
    String historico,
    String novaMensagem,
  ) async {
    if (_apiKey == 'COLE_SUA_CHAVE_GEMINI_AQUI') {
      return "⚠️ Chave da API não configurada.";
    }
    try {
      final model = GenerativeModel(model: 'gemini-3.5-flash', apiKey: _apiKey);

      // Concatena o histórico com a nova pergunta
      final fullPrompt =
          "Você é o Consultor IA de Negócios do App-Cic. Ajude o microempreendedor de forma firme, assertiva e direta com base neste histórico da conversa:\n\n$historico\n\nUsuário: $novaMensagem\nConsultor IA:";

      final response = await model.generateContent([Content.text(fullPrompt)]);
      return response.text ?? "Não recebi resposta da IA.";
    } catch (e) {
      try {
        final modelFallback = GenerativeModel(
          model: 'gemini-3.5-flash',
          apiKey: _apiKey,
        );
        final fullPrompt =
            "Você é o Consultor IA de Negócios do App-Cic. Ajude o microempreendedor de forma firme, assertiva e direta com base neste histórico da conversa:\n\n$historico\n\nUsuário: $novaMensagem\nConsultor IA:";
        final response = await modelFallback.generateContent([
          Content.text(fullPrompt),
        ]);
        return response.text ?? "Não recebi resposta da IA.";
      } catch (eFallback) {
        String errStr = eFallback.toString() + e.toString();
        print("Erro Gemini Chat: $errStr");
        if (errStr.contains('429') ||
            errStr.toLowerCase().contains('quota') ||
            errStr.toLowerCase().contains('too many requests')) {
          return "⏳ **Muitas mensagens seguidas!** Aguarde uns 30 segundinhos antes de enviar a próxima pergunta.";
        } else if (errStr.contains('503') ||
            errStr.toLowerCase().contains('service unavailable')) {
          return "⚠️ **Servidor Ocupado:** Os computadores do Google estão cheios agora. Envie sua mensagem novamente em alguns segundos.";
        }
        return "❌ **Falha de Conexão:** Não consegui conectar à internet. Verifique seu Wi-Fi.";
      }
    }
  }

  /// Gera relatório agendado (para uso com cron/Edge Function)
  /// Salva automaticamente no banco via SupabaseHelper
  static Future<String> gerarRelatorioAgendado(
    List<Produto> estoque,
    List<Map<String, dynamic>> historico,
    List<CustoOperacional> custos, {
    List<Alerta>? alertasAtivos,
  }) async {
    final relatorio = await analisarEstoque(
      estoque,
      historico,
      custos,
      alertasAtivos: alertasAtivos,
    );
    return relatorio;
  }
}
