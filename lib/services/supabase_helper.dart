import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/produto.dart';
import '../models/custo_operacional.dart';

class SupabaseHelper {
  static final supabase = Supabase.instance.client;

  /// 🔒 Retorna o ID do usuário logado (usado como empresa_id para multi-tenant)
  static String get _empresaId => supabase.auth.currentUser!.id;

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

  // Inserir ou Atualizar Produto (Upsert) — 🔒 injeta empresa_id automaticamente
  static Future<void> insertProduto(Produto p) async {
    await supabase.from('produtos').upsert({
      'codigo': p.codigo,
      'nome': p.nome,
      'lote': p.lote,
      'quantidade': p.quantidade,
      'valor_compra': p.valorCompra,
      'markup': p.markup,
      'valor_venda': p.valorVenda,
      'origem': p.origem,
      'data_entrada': p.dataEntrada?.toIso8601String(),
      'data_validade': p.dataValidade?.toIso8601String(),
      'vendidas': p.vendidas,
      'empresa_id': _empresaId, // 🔒 Multi-tenant
    }, onConflict: 'codigo');
  }

  // Registrar uma venda no histórico — 🔒 injeta empresa_id automaticamente
  static Future<void> registrarVenda(
    String codigoProduto,
    int qtdVendida,
    double valorUnid,
  ) async {
    await supabase.from('historico_vendas').insert({
      'produto_codigo': codigoProduto,
      'quantidade_vendida': qtdVendida,
      'valor_unitario': valorUnid,
      'empresa_id': _empresaId, // 🔒 Multi-tenant
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

  // Buscar custos operacionais do Supabase (Multi-tenant via RLS)
  static Future<List<CustoOperacional>> getCustosOperacionais() async {
    try {
      final response = await supabase
          .from('custos_operacionais')
          .select()
          .order('id', ascending: true);
      print("Custos operacionais encontrados: ${response.length}"); // DEBUG
      return (response as List)
          .map((json) => CustoOperacional.fromJson(json))
          .toList();
    } catch (e) {
      print("Erro ao buscar custos operacionais do Supabase: $e");
      return [];
    }
  }

  // Substituir/salvar custos operacionais no Supabase (Multi-tenant via RLS)
  static Future<void> replaceCustosOperacionais(
    List<CustoOperacional> custos,
  ) async {
    // 1. Identificar IDs que ainda existem na nova lista
    final idsExistentes = custos
        .where((c) => c.id != null)
        .map((c) => c.id!)
        .toList();

    // 2. Apagar do banco os custos desta empresa que foram removidos pelo usuário na tela
    if (idsExistentes.isNotEmpty) {
      await supabase
          .from('custos_operacionais')
          .delete()
          .not('id', 'in', idsExistentes);
    } else {
      // Se nenhum item da lista possui ID antigo, limpa todos os custos anteriores desta empresa
      await supabase.from('custos_operacionais').delete().neq('id', -1);
    }

    // 3. Upsert dos custos (com ID atualiza; sem ID insere novo)
    if (custos.isNotEmpty) {
      final data = custos.map((c) => {
        if (c.id != null) 'id': c.id,
        'nome': c.nome,
        'valor': c.valor,
      }).toList();
      await supabase.from('custos_operacionais').upsert(data);
    }
  }

  /// 🔒 Logout: desconecta do Supabase e limpa dados locais do aparelho
  /// Isso impede que o próximo usuário veja custos/dados do anterior.
  static Future<void> signOut() async {
    // 1. Limpa todos os dados locais (SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 2. Desconecta do Supabase Auth (invalida o JWT local)
    await supabase.auth.signOut();
  }
}
