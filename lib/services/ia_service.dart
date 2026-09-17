import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/produto.dart';
import '../models/custo_operacional.dart';
import '../models/alerta.dart';
import '../secrets.dart';
import '../services/supabase_helper.dart';

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

    // Proteção em tempo de execução: orienta o deploy na Vercel ou local
    if (_apiKey == 'COLE_SUA_CHAVE_GEMINI_AQUI' || _apiKey.isEmpty) {
      return "⚠️ **IA Desativada no Deploy da Vercel:**\\n\\nPara a IA funcionar na nuvem (onde o arquivo `secrets.dart` é invisível por segurança), vá nas configurações do seu site no Vercel:\\n1. Acesse **Settings -> Environment Variables** no painel da Vercel.\\n2. Adicione uma variável chamada **`GEMINI_API_KEY`** e cole sua chave (ou token `AQ.Ab...`).\\n3. Vá na aba **Deployments** e clique em **Redeploy**.\\n\\n*(Se estiver rodando no seu computador, certifique-se de que a chave está no `lib/secrets.dart`)*";
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
    // Buscar o contexto real do banco para a IA saber de tudo
    final estoque = await SupabaseHelper.getEstoque();
    final historicoVendas = await SupabaseHelper.getHistoricoVendas();
    final custos = await SupabaseHelper.getCustosOperacionais();

    final buffer = StringBuffer();
    buffer.writeln("Você é o Consultor IA de Negócios do App-Cic. Ajude o microempreendedor de forma firme, assertiva e direta.");
    buffer.writeln("IMPORTANTE: Você JÁ TEM ACESSO ao banco de dados do cliente. NÃO peça para ele colar planilhas ou fornecer dados. Use os DADOS REAIS abaixo para basear qualquer resposta estratégica ou financeira:");
    
    if (estoque.isNotEmpty) {
      buffer.writeln("\n--- DADOS REAIS DO ESTOQUE ---");
      for (var p in estoque.take(50)) { // Limite razoável para não estourar o prompt
        buffer.writeln("${p.nome} - Custo: R\$${p.valorCompra}, Venda: R\$${p.valorVenda}, Qtd: ${p.quantidade}");
      }
    } else {
      buffer.writeln("\n--- DADOS REAIS DO ESTOQUE ---");
      buffer.writeln("O estoque do cliente está VAZIO no momento.");
    }

    if (historicoVendas.isNotEmpty) {
      buffer.writeln("\n--- ÚLTIMAS VENDAS REAIS ---");
      for (var v in historicoVendas.reversed.take(20)) {
        buffer.writeln("Data: ${v['data_venda']} | Produto ID ${v['produto_codigo']} - Qtd: ${v['quantidade_vendida']} por R\$${v['valor_unitario']}");
      }
    }

    if (custos.isNotEmpty) {
      buffer.writeln("\n--- CUSTOS OPERACIONAIS ---");
      for (var c in custos) {
        buffer.writeln("${c.nome}: R\$${c.valor}");
      }
    }

    buffer.writeln("\n--- HISTÓRICO DA CONVERSA ---");
    buffer.writeln(historico);
    buffer.writeln("\nUsuário: $novaMensagem\nConsultor IA:");

    return await _consultarGeminiRobusto(buffer.toString());
  }

  /// Modelos atuais do Google Gemini (2026) - Fonte oficial: ai.google.dev
  /// Ordem de prioridade: mais rápido primeiro, depois mais potente como fallback
  static const List<String> _modelos = [
    'gemini-2.5-flash',
    'gemini-2.5-pro',
  ];

  /// Método robusto centralizado para consultar o Gemini.
  /// Tenta múltiplos modelos via SDK primeiro, depois REST como fallback.
  static Future<String> _consultarGeminiRobusto(String prompt) async {
    if (_apiKey == 'COLE_SUA_CHAVE_GEMINI_AQUI' || _apiKey.isEmpty) {
      return "Chave da API nao configurada. Abra lib/secrets.dart e cole sua chave.";
    }

    // --- PLANO A: SDK do google_generative_ai (funciona com a chave AQ.Ab...) ---
    for (final modelo in _modelos) {
      try {
        final model = GenerativeModel(model: modelo, apiKey: _apiKey);
        final response = await model.generateContent([Content.text(prompt)]);
        if (response.text != null && response.text!.isNotEmpty) {
          return response.text!;
        }
      } catch (e) {
        print("SDK tentativa ($modelo): $e");
        // Se deu 503, espera 3s e tenta o mesmo modelo de novo
        if (e.toString().contains('503') || e.toString().contains('overloaded') || e.toString().contains('UNAVAILABLE')) {
          try {
            await Future.delayed(const Duration(seconds: 3));
            final model = GenerativeModel(model: modelo, apiKey: _apiKey);
            final response = await model.generateContent([Content.text(prompt)]);
            if (response.text != null && response.text!.isNotEmpty) {
              return response.text!;
            }
          } catch (eRetry) {
            print("SDK retry ($modelo): $eRetry");
          }
        }
        continue; // tenta o próximo modelo
      }
    }

    // --- PLANO B: HTTP REST direto (fallback se SDK falhar completamente) ---
    for (final modelo in _modelos) {
      try {
        final bodyJson = jsonEncode({
          'contents': [
            {'parts': [{'text': prompt}]}
          ]
        });

        // Tenta primeiro como API key normal, depois como Bearer
        var url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$modelo:generateContent?key=$_apiKey');
        var resp = await http.post(
          url,
          headers: {'Content-Type': 'application/json', 'x-goog-api-key': _apiKey},
          body: bodyJson,
        );

        // Se deu 401 com API key, tenta como Bearer
        if (resp.statusCode == 401) {
          final urlBearer = Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$modelo:generateContent');
          resp = await http.post(
            urlBearer,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: bodyJson,
          );
        }

        // Retry para 503
        if (resp.statusCode == 503) {
          await Future.delayed(const Duration(seconds: 3));
          resp = await http.post(url, headers: {'Content-Type': 'application/json', 'x-goog-api-key': _apiKey}, body: bodyJson);
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
        } else if (resp.statusCode == 404) {
          print("REST modelo $modelo nao encontrado (404), tentando proximo...");
          continue;
        } else if (resp.statusCode == 429) {
          return "Muitas consultas em pouco tempo. Aguarde 30 segundos e tente novamente.";
        } else if (resp.statusCode == 503) {
          continue;
        } else {
          print("REST erro ($modelo) ${resp.statusCode}: ${resp.body}");
          continue;
        }
      } catch (e) {
        print("REST erro ($modelo): $e");
        continue;
      }
    }

    return "IA indisponivel no momento. Verifique sua conexao com a internet e tente novamente.";
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
