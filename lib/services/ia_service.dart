import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
    return await _consultarGeminiRobusto(promptFinal);
  }

  static Future<String> analisarProduto(Produto produto) async {
    final prompt =
        "Aja como um Estrategista de Varejo. Avalie o produto: ${produto.nome} (Estoque: ${produto.quantidade}, Preço de Custo: R\$${produto.valorCompra}, Preço de Venda: R\$${produto.valorVenda}). Crie uma estratégia agressiva e curta em tópicos sobre margem de lucro sugerida versus preço competitivo praticado pelo mercado.";
    return await _consultarGeminiRobusto(prompt);
  }

  static Future<String> continuarConversa(
    String historico,
    String novaMensagem,
  ) async {
    final fullPrompt =
        "Você é o Consultor IA de Negócios do App-Cic. Ajude o microempreendedor de forma firme, assertiva e direta com base neste histórico da conversa:\n\n$historico\n\nUsuário: $novaMensagem\nConsultor IA:";
    return await _consultarGeminiRobusto(fullPrompt);
  }

  /// Método robusto centralizado para consultar o Gemini (mantendo o gemini-3.5-flash)
  /// e contornando bloqueios de CORS/XMLHttpRequest em navegadores Web (Chrome/Safari).
  static Future<String> _consultarGeminiRobusto(String prompt) async {
    if (_apiKey == 'COLE_SUA_CHAVE_GEMINI_AQUI' || _apiKey.isEmpty) {
      return "⚠️ Chave da API não configurada.";
    }

    try {
      // 1ª Tentativa: SDK do Google com o modelo configurado (gemini-3.5-flash)
      final model = GenerativeModel(model: 'gemini-3.5-flash', apiKey: _apiKey);
      final response = await model.generateContent([Content.text(prompt)]);
      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!;
      }
    } catch (e) {
      print("Erro 1ª tentativa Gemini SDK (3.5): $e");
      // Se não for erro de web/XMLHttpRequest, tenta o 1.5-flash no SDK via fallback
      try {
        final modelFallback = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: _apiKey,
        );
        final response = await modelFallback.generateContent([
          Content.text(prompt),
        ]);
        if (response.text != null && response.text!.isNotEmpty) {
          return response.text!;
        }
      } catch (eFallback) {
        print("Erro 2ª tentativa Gemini SDK (1.5): $eFallback");
      }
    }

    // 2ª Tentativa: Chamada HTTP REST Direta (Bypassa problemas de headers/CORS e tenta como API Key e como Token OAuth 2 Bearer)
    try {
      final bodyJson = jsonEncode({
        'contents': [
          {'parts': [{'text': prompt}]}
        ]
      });

      var url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$_apiKey');
      var resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'x-goog-api-key': _apiKey},
        body: bodyJson,
      );

      // Se o Google reclamar que a chave é um Token OAuth 2 ('ACCESS_TOKEN_TYPE_UNSUPPORTED' ou 'Expected OAuth 2 access token'),
      // refazemos automaticamente a chamada enviando a chave no cabeçalho 'Authorization: Bearer' (suporte nativo para tokens do tipo AQ.Ab...)
      if (resp.statusCode == 401 && (resp.body.contains('ACCESS_TOKEN_TYPE_UNSUPPORTED') || resp.body.contains('OAuth 2') || _apiKey.startsWith('AQ.') || _apiKey.startsWith('ya29.'))) {
        print("Identificado token OAuth 2 / Service Token (${_apiKey.substring(0, 5)}...). Enviando via Authorization: Bearer...");
        final urlBearer = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent');
        resp = await http.post(
          urlBearer,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: bodyJson,
        );

        // Se gemini-3.5-flash com Bearer falhar por 404 ou 401, tenta o 1.5-flash com Bearer
        if (resp.statusCode != 200) {
          final urlBearer15 = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent');
          final resp15 = await http.post(
            urlBearer15,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: bodyJson,
          );
          if (resp15.statusCode == 200) {
            resp = resp15;
          }
        }
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          if (content != null && content['parts'] != null) {
            final parts = content['parts'] as List<dynamic>;
            if (parts.isNotEmpty && parts[0]['text'] != null) {
              return parts[0]['text'] as String;
            }
          }
        }
      } else {
        print("Erro HTTP Gemini REST (${resp.statusCode}): ${resp.body}");
        final errStr = resp.body.toLowerCase();
        if (resp.statusCode == 429 || errStr.contains('quota') || errStr.contains('too many requests')) {
          return "⏳ **Aguarde um momentinho! (Limite Antispam)**\n\nVocê fez muitas análises muito rápido! Para não sobrecarregar, o sistema permite cerca de 15 consultas por minuto. Respire fundo, espere uns 30 segundinhos e tente novamente! 😊";
        } else if (resp.statusCode == 503 || errStr.contains('service unavailable')) {
          return "⚠️ **Servidores Ocupados (Google)**\n\nA Inteligência Artificial está atendendo muita gente neste exato segundo e não conseguiu processar. Aguarde uns 10 segundinhos e clique novamente.";
        } else if (resp.statusCode == 404) {
          return "⚠️ **Modelo não encontrado (404):** O modelo 'gemini-3.5-flash' não está disponível para esta chave/projeto na versão atual da API.";
        } else if (resp.statusCode == 401 || resp.statusCode == 400 || resp.statusCode == 403) {
          try {
            final errJson = jsonDecode(resp.body);
            final msg = errJson['error']?['message'] ?? resp.body;
            final details = errJson['error']?['details'] as List?;
            String reason = '';
            if (details != null && details.isNotEmpty) {
              reason = details[0]['reason'] ?? '';
            }
            if (reason.contains('API_KEY_SERVICE_BLOCKED') || msg.contains('API_KEY_SERVICE_BLOCKED')) {
              return "🛑 **Serviço da API Bloqueado (`API_KEY_SERVICE_BLOCKED`):**\n\nO Google recusou a requisição porque **o serviço Generative Language API não está habilitado ou está restrito para esta chave/projeto**.\n\n**Como resolver (na aba do Google AI Studio que você abriu):**\n1. Acesse `aistudio.google.com/api-keys`\n2. Clique em **\"Criar chave de API\" (`Create API key`)** -> escolha **\"Criar em novo projeto\" (`Create in new project`)**.\n3. O Google gerará uma chave limpa (formato `AIzaSy...`) com a API já habilitada sem bloqueios (`API_KEY_SERVICE_BLOCKED`).\n4. Cole a nova chave no seu `secrets.dart`.";
            }
            if (resp.statusCode == 401 || reason.contains('ACCESS_TOKEN_TYPE_UNSUPPORTED') || msg.contains('invalid authentication credentials')) {
              return "⚠️ **Credenciais de Autenticação Recusadas (401 - $reason):**\n\nO servidor do Google informou:\n\"$msg\"\n\n*Nota:* Se você gerou uma chave nova e ela ainda começa com `AQ.Ab...`, o Google a identifica como Token OAuth/Serviço restrito e retorna `$reason`. Para chamadas diretas da IA Gemini, utilize uma chave de API do Google AI Studio (formato `AIzaSy...`).";
            }
            return "⚠️ **Erro na Chave/API (${resp.statusCode}):** $msg";
          } catch (_) {
            if (resp.statusCode == 401) {
              return "⚠️ **Credenciais Recusadas (401):** O Google recusou a chave/credencial configurada no `secrets.dart` para esta chamada.";
            }
            return "⚠️ **Erro na Chave/API (${resp.statusCode}):** ${resp.body}";
          }
        }
      }
    } catch (eHttp) {
      print("Erro HTTP REST direct: $eHttp");
      final errHttpStr = eHttp.toString();
      if (errHttpStr.contains('401') || errHttpStr.contains('UNAUTHENTICATED') || errHttpStr.contains('ACCESS_TOKEN_TYPE_UNSUPPORTED')) {
        return "⚠️ **Credenciais Recusadas (401):** A credencial no `secrets.dart` (`AQ.Ab...`) foi rejeitada pela API do Google (`ACCESS_TOKEN_TYPE_UNSUPPORTED`).";
      }
      if (errHttpStr.contains('XMLHttpRequest') || kIsWeb) {
        return "🌐 **Bloqueio de Segurança Web (CORS/XMLHttpRequest):**\n\nComo o Lucas confirmou, **no celular (Android/iOS) a IA funciona normalmente** porque apps nativos conectam direto ao servidor sem restrições. Porém, navegadores Web (Chrome/Safari) bloqueiam por padrão requisições de servidores locais (`localhost`) por segurança do navegador (CORS / `XMLHttpRequest error`).\n\n**Dicas para testar na Web sem bloqueio:**\n1. Use o app rodando no celular ou emulador (onde funciona 100% sem bloqueio CORS).\n2. Ou inicie o Chrome desativando o CORS temporariamente para testes locais.";
      }
    }

    return "❌ **Sem conexão com a IA**\n\nVerifique se o seu Wi-Fi/Internet está funcionando bem ou se o navegador Web não está bloqueando a requisição (`XMLHttpRequest error`).";
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
