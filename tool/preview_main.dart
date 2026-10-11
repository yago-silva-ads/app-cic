// Pré-visualização local com dados de exemplo (NÃO é o app publicado).
//   flutter run -t tool/preview_main.dart -d chrome
// Não acessa o seu banco: serve para conferir o visual das telas.
import 'package:app_cic/app/shell.dart';
import 'package:app_cic/core/theme.dart';
import 'package:app_cic/data/auth_service.dart';
import 'package:app_cic/data/conta.dart';
import 'package:app_cic/data/models.dart';
import 'package:app_cic/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Demo extends AppState {
  _Demo({required super.tema});

  @override
  Usuario? get usuario => Usuario(id: 'demo', email: 'lojista@exemplo.com', nome: 'Carlos Eduardo', lojaNome: 'Mercadinho Central');

  @override
  Future<void> carregar() async {
    final agora = DateTime.now();
    estoque = [
      Produto(codigo: '7891721201806', nome: 'GLIFAGE XR 500MG TAB RM (30)', lote: 'L-24098A', quantidade: 14, valorCompra: 12.5, markup: 1.8, valorVenda: 22.5, categoria: 'Medicamentos', dataValidade: agora.add(const Duration(days: 180)), vendidas: 8),
      Produto(codigo: '7894900010015', nome: 'Refrigerante Coca-Cola Lata 350ml', lote: 'LT-5512', quantidade: 3, valorCompra: 2.8, markup: 1.75, valorVenda: 4.9, categoria: 'Bebidas', dataValidade: agora.add(const Duration(days: 45)), vendidas: 32),
      Produto(codigo: '7891000100103', nome: 'Leite Condensado Moça Lata 395g', lote: 'MC-881', quantidade: 22, valorCompra: 5.9, markup: 1.5, valorVenda: 8.85, categoria: 'Mercearia', dataValidade: agora.add(const Duration(days: 5)), vendidas: 15),
      Produto(codigo: '7896004000110', nome: 'Café Pilão Tradicional Vácuo 500g', lote: 'PIL-992', quantidade: 18, valorCompra: 16.5, markup: 1.45, valorVenda: 23.9, categoria: 'Mercearia', vendidas: 11),
      Produto(codigo: '7891038072120', nome: 'Creme Dental Colgate Total 12 90g', lote: 'CG-404', quantidade: 2, valorCompra: 4.5, markup: 1.2, valorVenda: 5.4, categoria: 'Higiene', vendidas: 19),
      Produto(codigo: '7896094900109', nome: 'Detergente Líquido Ypê Neutro 500ml', lote: 'YP-102', quantidade: 30, valorCompra: 1.95, markup: 1.65, valorVenda: 3.2, categoria: 'Limpeza', vendidas: 45),
    ];
    custos = [
      CustoOperacional(id: '1', nome: 'Aluguel do Ponto Comercial', valor: 1400, categoria: 'Imóvel'),
      CustoOperacional(id: '2', nome: 'Energia Elétrica Comercial', valor: 380, categoria: 'Utilidades'),
      CustoOperacional(id: '3', nome: 'Taxas de Maquininha e Cartão', valor: 220, tipo: TipoCusto.variavel, categoria: 'Financeiro', observacao: 'Média de 2,5% do faturamento'),
    ];
    alertas = [
      Alerta(id: 1, tipo: 'VALIDADE', mensagem: '⚠️ "Leite Condensado Moça Lata 395g" vence em 5 dia(s). Crie uma promoção.', severidade: 'ALTO', lido: false, criadoEm: agora),
      Alerta(id: 2, tipo: 'ESTOQUE_BAIXO', mensagem: '📦 CRÍTICO: "Creme Dental Colgate" tem apenas 2 unidade(s)!', severidade: 'CRITICO', lido: false, criadoEm: agora),
      Alerta(id: 3, tipo: 'PREJUIZO', mensagem: 'Margem baixa: "Creme Dental Colgate" com markup 1,20x.', severidade: 'MEDIO', lido: true, criadoEm: agora),
    ];
    movimentacoes = [
      Movimentacao(id: 'm1', tipo: 'ENTRADA', motivo: 'COMPRA_FORNECEDOR', produtoCodigo: '7891721201806', produtoNome: 'GLIFAGE XR 500MG TAB RM (30)', quantidade: 20, valorUnitario: 12.5, valorTotal: 250, dataHora: agora.subtract(const Duration(days: 15)), documento: 'NF-e 88120'),
      Movimentacao(id: 'm2', tipo: 'SAIDA', motivo: 'VENDA_PDV', produtoCodigo: '7894900010015', produtoNome: 'Refrigerante Coca-Cola Lata 350ml', quantidade: 20, valorUnitario: 4.9, valorTotal: 98, dataHora: agora.subtract(const Duration(days: 2)), documento: 'VEN-3301'),
    ];
    vendas = [
      VendaItemHistorico(id: 'v1', vendaId: 'a', produtoCodigo: '7894900010015', nomeProduto: 'Refrigerante Coca-Cola Lata 350ml', quantidade: 20, valorUnitario: 4.9, custoUnitario: 2.8, data: agora.subtract(const Duration(days: 2)), metodoPagamento: 'PIX'),
      VendaItemHistorico(id: 'v2', vendaId: 'b', produtoCodigo: '7896094900109', nomeProduto: 'Detergente Líquido Ypê Neutro 500ml', quantidade: 12, valorUnitario: 3.2, custoUnitario: 1.95, data: agora.subtract(const Duration(days: 1)), metodoPagamento: 'DINHEIRO'),
    ];
    conta = ContaEstabelecimento(
      nomeFantasia: 'Mercadinho Central', razaoSocial: 'Carlos Eduardo Silva MEI', documentoNumero: '48.912.345/0001-78',
      banco: 'Nubank (260)', pixChave: '48912345000178', pixTitular: 'Mercadinho Central', pixCidade: 'Sao Paulo', cidade: 'São Paulo', uf: 'SP',
      maquininhas: [Maquininha(id: 'm1', nome: 'Stone Smart Balcão', taxaDebito: 1.29, taxaCredito: 3.19, prazoDias: 1)],
    );
    carregouUmaVez = true;
    atualizadoEm = agora;
    notifyListeners();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  await Supabase.initialize(url: 'https://preview.invalid', anonKey: 'preview');
  final tema = TemaController();
  final estado = _Demo(tema: tema);
  await estado.carregar();
  runApp(ListenableBuilder(
    listenable: tema,
    builder: (_, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: construirTema(tema.paleta),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: AppShell(estado: estado, auth: AuthService()),
    ),
  ));
}
