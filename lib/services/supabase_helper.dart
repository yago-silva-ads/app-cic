import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/produto.dart';
import '../models/custo_operacional.dart';

class SupabaseHelper {
  static final supabase = Supabase.instance.client;

  // Buscar todo o estoque da nuvem
  static Future<List<Produto>> getEstoque() async {
    try {
      final response = await supabase.from('produtos').select();
      print("Produtos encontrados: ${response.length}"); // DEBUG

      // Mapear o JSON do Supabase para a sua classe Produto
      return (response as List)
          .map(
            (json) => Produto(
              codigo: json['codigo'],
              nome: json['nome'],
              lote: json['lote'] ?? '',
              quantidade: json['quantidade'],
              valorCompra: (json['valor_compra'] as num).toDouble(),
              markup: (json['markup'] as num).toDouble(),
              valorVenda: (json['valor_venda'] as num).toDouble(),
              // AS TRÊS LINHAS NOVAS AQUI:
              origem: json['origem'] ?? 'Revendido',
              dataEntrada: json['data_entrada'] != null
                  ? DateTime.tryParse(json['data_entrada'])
                  : null,
              dataValidade: json['data_validade'] != null
                  ? DateTime.tryParse(json['data_validade'])
                  : null,
              vendidas: json['vendidas'] ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      print("Erro ao buscar estoque: $e");
      return [];
    }
  }

  // Inserir ou Atualizar Produto (Upsert)
  static Future<void> insertProduto(Produto p) async {
    await supabase.from('produtos').upsert({
      'codigo': p.codigo,
      'nome': p.nome,
      'lote': p.lote,
      'quantidade': p.quantidade,
      'valor_compra': p.valorCompra,
      'markup': p.markup,
      'valor_venda': p.valorVenda,
      // AS TRÊS LINHAS NOVAS AQUI:
      'origem': p.origem,
      'data_entrada': p.dataEntrada?.toIso8601String(),
      'data_validade': p.dataValidade?.toIso8601String(),
      'vendidas': p.vendidas,
    }, onConflict: 'codigo');
  }

  // Registrar uma venda no histórico (usado pelo Firebase Analytics e Fluxo de Caixa)
  static Future<void> registrarVenda(
    String codigoProduto,
    int qtdVendida,
    double valorUnid,
  ) async {
    await supabase.from('historico_vendas').insert({
      'produto_codigo': codigoProduto,
      'quantidade_vendida': qtdVendida,
      'valor_unitario': valorUnid,
    });
  }

  // Recuperar Histórico de Vendas para o DashBoard
  static Future<List<Map<String, dynamic>>> getHistoricoVendas() async {
    try {
      final response = await supabase
          .from('historico_vendas')
          .select()
          .order('data_venda', ascending: true); // <-- MUDAR AQUI!
      print("Vendas encontradas: ${response.length}"); // DEBUG
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Erro ao buscar vendas: $e");
      return [];
    }
  }

  static Future<void> deleteProduto(String codigo) async {
    await supabase.from('produtos').delete().eq('codigo', codigo);
  }

  static Future<List<CustoOperacional>> getCustosOperacionais() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? custosJson = prefs.getString('custos_operacionais_locais');
      if (custosJson != null) {
        final List<dynamic> decoded = jsonDecode(custosJson);
        return decoded.map((json) => CustoOperacional.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print("Erro ao buscar custos operacionais: $e");
      return [];
    }
  }

  static Future<void> replaceCustosOperacionais(
    List<CustoOperacional> custos,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(custos.map((c) => c.toJson()).toList());
    await prefs.setString('custos_operacionais_locais', encoded);
  }
}
