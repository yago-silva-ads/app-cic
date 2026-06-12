import 'package:supabase_flutter/supabase_flutter.dart';

/// Serviço para gerar relatórios avançados de vendas e estoque
/// 
/// Este serviço complementa o SupabaseHelper fornecendo análises
/// mais complexas para o dashboard e para relatórios DataStudio
class RelatorioService {
  static final supabase = Supabase.instance.client;

  /// Retorna estatísticas gerais de vendas
  /// 
  /// Exemplo de uso:
  /// ```dart
  /// final stats = await RelatorioService.getEstatisticasGerais();
  /// print('Total faturado: ${stats['total_faturado']}');
  /// ```
  static Future<Map<String, dynamic>> getEstatisticasGerais() async {
    try {
      // Total faturado
      final faturamento = await supabase
          .from('historico_vendas')
          .select('valor_unitario, quantidade_vendida')
          .then((data) {
        double total = 0;
        for (var venda in data) {
          total += (venda['valor_unitario'] as num).toDouble() * 
                   (venda['quantidade_vendida'] as num);
        }
        return total;
      });

      // Total de vendas
      final totalVendas = await supabase
          .from('historico_vendas')
          .select('id')
          .then((data) => data.length);

      // Ticket médio
      final ticketMedio = totalVendas > 0 ? faturamento / totalVendas : 0.0;

      return {
        'total_faturado': faturamento,
        'total_vendas': totalVendas,
        'ticket_medio': ticketMedio,
        'data_atualizacao': DateTime.now().toString(),
      };
    } catch (e) {
      print("Erro ao buscar estatísticas: $e");
      return {};
    }
  }

  /// Retorna os N produtos mais vendidos com nome do produto
  /// 
  /// Exemplo:
  /// ```dart
  /// final top10 = await RelatorioService.getProdutosMaisVendidos(limit: 10);
  /// ```
  static Future<List<Map<String, dynamic>>> getProdutosMaisVendidos({
    int limit = 5,
  }) async {
    try {
      // Busca todas as vendas
      final vendas = await supabase
          .from('historico_vendas')
          .select('produto_codigo, quantidade_vendida, valor_unitario');

      // Busca todos os produtos para mapear código → nome
      final produtos = await supabase
          .from('produtos')
          .select('codigo, nome');
      
      Map<String, String> mapaProdutos = {};
      for (var p in produtos) {
        mapaProdutos[p['codigo']] = p['nome'];
      }

      // Agrupa vendas por código
      Map<String, dynamic> grouped = {};
      for (var venda in vendas) {
        String codigo = venda['produto_codigo'];
        if (grouped[codigo] == null) {
          grouped[codigo] = {
            'codigo': codigo,
            'nome': mapaProdutos[codigo] ?? 'Produto Excluído',
            'total_vendas': 0,
            'total_faturado': 0.0,
            'total_unidades': 0,
          };
        }
        
        grouped[codigo]['total_vendas']++;
        grouped[codigo]['total_faturado'] += 
            (venda['valor_unitario'] as num).toDouble() * 
            (venda['quantidade_vendida'] as num);
        grouped[codigo]['total_unidades'] += venda['quantidade_vendida'];
      }

      final response = grouped.values
          .toList()
          .cast<Map<String, dynamic>>()
          ..sort((a, b) => (b['total_faturado'] as num)
              .compareTo(a['total_faturado'] as num));

      return response.take(limit).toList();
    } catch (e) {
      print("Erro ao buscar produtos mais vendidos: $e");
      return [];
    }
  }

  /// Calcula a margem de lucro média
  /// 
  /// Exemplo:
  /// ```dart
  /// final margem = await RelatorioService.getMargemLucroMedia();
  /// print('Margem média: ${margem['margem_percentual']}%');
  /// ```
  static Future<Map<String, dynamic>> getMargemLucroMedia() async {
    try {
      final produtos = await supabase
          .from('produtos')
          .select('valor_compra, valor_venda, quantidade');

      if (produtos.isEmpty) {
        return {'margem_percentual': 0.0, 'margem_media_reais': 0.0};
      }

      double margemTotalReais = 0;
      double faturamentoBruto = 0;

      for (var p in produtos) {
        double margem = (p['valor_venda'] as num).toDouble() - 
                       (p['valor_compra'] as num).toDouble();
        int quantidade = p['quantidade'] ?? 0;
        
        margemTotalReais += margem * quantidade;
        faturamentoBruto += (p['valor_venda'] as num).toDouble() * quantidade;
      }

      double margemPercentual = 
          faturamentoBruto > 0 ? (margemTotalReais / faturamentoBruto * 100) : 0;

      return {
        'margem_percentual': margemPercentual.toStringAsFixed(2),
        'margem_media_reais': margemTotalReais.toStringAsFixed(2),
        'faturamento_bruto': faturamentoBruto.toStringAsFixed(2),
      };
    } catch (e) {
      print("Erro ao calcular margem: $e");
      return {};
    }
  }

  /// Retorna faturamento por período (últimos N dias)
  /// 
  /// Exemplo:
  /// ```dart
  /// final faturamento = await RelatorioService.getFaturamentoPorPeriodo(7);
  /// // Retorna faturamento dos últimos 7 dias
  /// ```
  static Future<List<Map<String, dynamic>>> getFaturamentoPorPeriodo(
    int dias,
  ) async {
    try {
      final dataLimite = DateTime.now().subtract(Duration(days: dias));
      
      final response = await supabase
          .from('historico_vendas')
          .select('data_venda, valor_unitario, quantidade_vendida')
          .gte('data_venda', dataLimite.toIso8601String())
          .then((data) {
        Map<String, double> agrupado = {};
        
        for (var venda in data) {
          String data = venda['data_venda'].toString().split('T')[0];
          double valor = (venda['valor_unitario'] as num).toDouble() * 
                        (venda['quantidade_vendida'] as num);
          
          agrupado[data] = (agrupado[data] ?? 0) + valor;
        }
        
        return agrupado.entries
            .map((e) => {
              'data': e.key,
              'faturamento': e.value.toStringAsFixed(2),
            })
            .toList()
          ..sort((a, b) => a['data'].toString()
              .compareTo(b['data'].toString()));
      });

      return response;
    } catch (e) {
      print("Erro ao buscar faturamento por período: $e");
      return [];
    }
  }

  /// Análise de produtos em falta (quantidade baixa)
  /// 
  /// Exemplo:
  /// ```dart
  /// final emFalta = await RelatorioService.getProdutosEmFalta(minimo: 10);
  /// ```
  static Future<List<Map<String, dynamic>>> getProdutosEmFalta({
    int minimo = 5,
  }) async {
    try {
      final response = await supabase
          .from('produtos')
          .select('codigo, nome, quantidade, valor_compra')
          .lt('quantidade', minimo)
          .order('quantidade', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Erro ao buscar produtos em falta: $e");
      return [];
    }
  }

  /// Retorna a composição do estoque por categoria/origem
  /// 
  /// Exemplo:
  /// ```dart
  /// final composicao = await RelatorioService.getComposicaoEstoque();
  /// ```
  static Future<Map<String, dynamic>> getComposicaoEstoque() async {
    try {
      final produtos = await supabase.from('produtos').select();

      Map<String, int> composicao = {};
      for (var p in produtos) {
        String origem = p['origem'] ?? 'Revendido';
        composicao[origem] = (composicao[origem] ?? 0) + 
                            (p['quantidade'] as int);
      }

      return composicao;
    } catch (e) {
      print("Erro ao buscar composição do estoque: $e");
      return {};
    }
  }

  /// ROI (Retorno sobre Investimento) - Quanto rendeu vs quanto foi investido
  /// 
  /// Exemplo:
  /// ```dart
  /// final roi = await RelatorioService.getROI();
  /// print('ROI: ${roi['percentual']}%');
  /// ```
  static Future<Map<String, dynamic>> getROI() async {
    try {
      final vendas = await supabase
          .from('historico_vendas')
          .select('valor_unitario, quantidade_vendida, produto_codigo');

      double faturamento = 0;
      double custoTotal = 0;

      // Buscar preço de compra dos produtos
      final produtos = await supabase.from('produtos').select();
      Map<String, double> precoCompra = {};

      for (var p in produtos) {
        precoCompra[p['codigo']] = 
            (p['valor_compra'] as num).toDouble();
      }

      for (var venda in vendas) {
        double valor = (venda['valor_unitario'] as num).toDouble() * 
                      (venda['quantidade_vendida'] as num);
        faturamento += valor;

        double custo = (precoCompra[venda['produto_codigo']] ?? 0) * 
                      (venda['quantidade_vendida'] as num);
        custoTotal += custo;
      }

      double roi = custoTotal > 0 
          ? ((faturamento - custoTotal) / custoTotal * 100) 
          : 0;
      double lucro = faturamento - custoTotal;

      return {
        'roi_percentual': roi.toStringAsFixed(2),
        'faturamento_total': faturamento.toStringAsFixed(2),
        'custo_total': custoTotal.toStringAsFixed(2),
        'lucro': lucro.toStringAsFixed(2),
      };
    } catch (e) {
      print("Erro ao calcular ROI: $e");
      return {};
    }
  }

  /// Previsão simples de vendas baseada em média móvel
  /// 
  /// Exemplo:
  /// ```dart
  /// final previsao = await RelatorioService.getPrevisaoVendas(dias: 7);
  /// print('Previsão próximos 7 dias: R\$ ${previsao['previsao']}');
  /// ```
  static Future<Map<String, dynamic>> getPrevisaoVendas({
    int dias = 7,
  }) async {
    try {
      final dataLimite = DateTime.now().subtract(Duration(days: dias * 2));
      
      final vendas = await supabase
          .from('historico_vendas')
          .select('data_venda, valor_unitario, quantidade_vendida')
          .gte('data_venda', dataLimite.toIso8601String());

      if (vendas.isEmpty) {
        return {'previsao': 0, 'confianca': 'baixa'};
      }

      double totalVendido = 0;
      for (var v in vendas) {
        totalVendido += (v['valor_unitario'] as num).toDouble() * 
                       (v['quantidade_vendida'] as num);
      }

      double mediaDiaria = totalVendido / (dias * 2);
      double previsao = mediaDiaria * dias;

      return {
        'previsao': previsao.toStringAsFixed(2),
        'media_diaria': mediaDiaria.toStringAsFixed(2),
        'confianca': 'média',
        'periodo_dias': dias,
      };
    } catch (e) {
      print("Erro ao calcular previsão: $e");
      return {};
    }
  }
}
