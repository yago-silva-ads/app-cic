import 'dart:convert';

import 'package:cic_domain/cic_domain.dart' as dom;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../data/models.dart';

class RelatorioMercado {
  const RelatorioMercado({required this.produto, required this.analise, required this.fontes, required this.aviso});
  final Produto produto;
  final dom.AnaliseMercado analise;
  final List<dom.OfertaMercado> fontes;
  final String? aviso;
}

class AnaliseMercadoService {
  Future<({List<dom.OfertaMercado> ofertas, String? aviso})> buscarOfertas({required String nome, required String codigo}) async {
    if (Config.demo) return (ofertas: const <dom.OfertaMercado>[], aviso: 'Demonstração: publique a Edge Function para consultar a web.');
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) throw StateError('Sessão expirada. Entre novamente para consultar o mercado.');
    final resposta = await http.post(
      Uri.parse(Config.marketFunctionUrl),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token', 'apikey': Config.supabaseAnonKey},
      body: jsonEncode({'produto': {'nome': nome, 'codigo': codigo, 'precoAtual': 0, 'custo': 0}}),
    // A busca na web (Groq browser_search) leva de 12 a 40 s; 75 s cobre a pior consulta medida com folga.
    ).timeout(const Duration(seconds: 75), onTimeout: () =>
        throw StateError('A pesquisa demorou mais que o normal. Tente de novo em alguns instantes.'));
    if (resposta.statusCode == 404) {
      throw StateError('A pesquisa de mercado ainda está sendo ativada para o teste de campo. Em breve ela aparece aqui.');
    }
    if (resposta.statusCode == 429) throw StateError('Muitas consultas seguidas. Aguarde um minuto e tente de novo.');
    if (resposta.statusCode != 200) throw StateError('A pesquisa de mercado não está disponível agora. Tente novamente mais tarde.');
    final body = jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
    final ofertas = [
      for (final item in (body['ofertas'] as List? ?? const []))
        dom.OfertaMercado(
          precoCentavos: (((item['preco'] as num?)?.toDouble() ?? 0) * 100).round(),
          fonte: '${item['fonte'] ?? 'Fonte'}',
          url: '${item['url'] ?? ''}',
          coletadaEm: DateTime.tryParse('${item['coletadaEm'] ?? ''}'),
        ),
    ];
    return (ofertas: ofertas, aviso: body['aviso']?.toString());
  }

  Future<RelatorioMercado> analisar(Produto produto) async {
    if (Config.demo) {
      final atual = (produto.valorVenda * 100).round();
      final ofertas = [
        dom.OfertaMercado(precoCentavos: (atual * 0.94).round(), fonte: 'Exemplo da demo', url: 'https://demo.app-cic.local/a'),
        dom.OfertaMercado(precoCentavos: (atual * 1.08).round(), fonte: 'Exemplo da demo', url: 'https://demo.app-cic.local/b'),
        dom.OfertaMercado(precoCentavos: (atual * 1.02).round(), fonte: 'Exemplo da demo', url: 'https://demo.app-cic.local/c'),
      ];
      return RelatorioMercado(
        produto: produto,
        fontes: ofertas,
        analise: dom.analisarMercado(precoAtualCentavos: atual, custoCentavos: (produto.valorCompra * 100).round(), ofertas: ofertas),
        aviso: 'Demonstração: as ofertas são fictícias. Publique a Edge Function para consultar a web.',
      );
    }
    final resposta = await buscarOfertas(nome: produto.nome, codigo: produto.codigo);
    final analise = dom.analisarMercado(precoAtualCentavos: (produto.valorVenda * 100).round(), custoCentavos: (produto.valorCompra * 100).round(), ofertas: resposta.ofertas);
    return RelatorioMercado(produto: produto, analise: analise, fontes: resposta.ofertas, aviso: resposta.aviso);
  }
}
