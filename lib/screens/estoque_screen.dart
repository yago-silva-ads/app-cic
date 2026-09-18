import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/kpi_card.dart';
import '../services/supabase_helper.dart';
import '../models/produto.dart';
import 'leitor_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// EstoqueScreen — Gestão de Estoque Premium v2.0
///
/// Grid de produtos com contadores ágeis, filtros por pílulas, busca e 
/// resumo de KPIs do estoque.
/// ═══════════════════════════════════════════════════════════════════════
class EstoqueScreen extends StatefulWidget {
  const EstoqueScreen({super.key});

  @override
  State<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends State<EstoqueScreen> {
  List<Produto> _estoqueCompleto = [];
  List<Produto> _estoqueFiltrado = [];
  bool _carregando = true;
  String _filtroAtual = 'Todos';
  String _termoBusca = '';

  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _carregarEstoque();
  }

  Future<void> _carregarEstoque() async {
    setState(() => _carregando = true);
    try {
      final produtos = await SupabaseHelper.getEstoque();
      if (mounted) {
        setState(() {
          _estoqueCompleto = produtos;
          _aplicarFiltros();
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _aplicarFiltros() {
    var temp = _estoqueCompleto;

    // Busca por texto
    if (_termoBusca.isNotEmpty) {
      final termo = _termoBusca.toLowerCase();
      temp = temp.where((p) =>
          p.nome.toLowerCase().contains(termo) ||
          p.codigo.contains(termo) ||
          p.lote.toLowerCase().contains(termo)).toList();
    }

    // Filtro por pílula
    switch (_filtroAtual) {
      case 'Estoque Baixo':
        temp = temp.where((p) => p.quantidade <= 10).toList();
        break;
      case 'Validade Crítica':
        final hoje = DateTime.now();
        temp = temp.where((p) => 
          p.dataValidade != null && 
          p.dataValidade!.difference(hoje).inDays <= 30
        ).toList();
        break;
      case 'Fabricados':
        temp = temp.where((p) => p.origem.toLowerCase() == 'fabricado').toList();
        break;
    }

    setState(() {
      _estoqueFiltrado = temp;
    });
  }

  void _setFiltro(String filtro) {
    setState(() {
      _filtroAtual = filtro;
      _aplicarFiltros();
    });
  }

  Future<void> _ajustarEstoque(Produto p, int variacao) async {
    final novaQtd = p.quantidade + variacao;
    if (novaQtd < 0) return;

    try {
      await SupabaseHelper.atualizarEstoque(p.codigo, novaQtd);
      _carregarEstoque(); // recarrega para manter sync
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final gold = AppColors.goldForBrightness(Theme.of(context).brightness);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Estoque'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeitorScreen(isEmbedded: false)),
              ).then((_) => _carregarEstoque());
            },
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: gold,
              onRefresh: _carregarEstoque,
              child: CustomScrollView(
                slivers: [
                  // ── Resumo KPIs ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: KpiCard(
                              icon: Icons.inventory_2_outlined,
                              iconColor: AppColors.info,
                              title: 'Total SKUs',
                              value: '${_estoqueCompleto.length}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: KpiCard(
                              icon: Icons.warning_amber_rounded,
                              iconColor: AppColors.error,
                              title: 'Estoque Baixo',
                              value: '${_estoqueCompleto.where((p) => p.quantidade <= 10).length}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Busca e Filtros ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CustomTextField(
                            hint: 'Buscar por nome, código ou lote...',
                            prefixIcon: Icons.search,
                            onChanged: (v) {
                              _termoBusca = v;
                              _aplicarFiltros();
                            },
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterPill('Todos'),
                                _buildFilterPill('Estoque Baixo'),
                                _buildFilterPill('Validade Crítica'),
                                _buildFilterPill('Fabricados'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${_estoqueFiltrado.length} produtos listados',
                            style: TextStyle(fontSize: 12, color: textPrimary.withValues(alpha: 0.6)),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // ── Lista de Produtos ──
                  _estoqueFiltrado.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'Nenhum produto encontrado',
                              style: TextStyle(color: textPrimary.withValues(alpha: 0.5)),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final p = _estoqueFiltrado[index];
                                return _buildProductCard(p);
                              },
                              childCount: _estoqueFiltrado.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterPill(String label) {
    final isSelected = _filtroAtual == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = AppColors.goldForBrightness(Theme.of(context).brightness);

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _setFiltro(label),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        selectedColor: gold.withValues(alpha: 0.2),
        checkmarkColor: gold,
        labelStyle: TextStyle(
          color: isSelected ? gold : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? gold : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Produto p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final isLowStock = p.quantidade <= 10;
    final lucroPerc = p.valorCompra > 0 
        ? ((p.valorVenda - p.valorCompra) / p.valorCompra) * 100 
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLowStock ? AppColors.error.withValues(alpha: 0.5) : borderColor,
          width: isLowStock ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ── Header Card ──
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.nome,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLowStock)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.errorBgDark,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('BAIXO', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('EAN: ${p.codigo}', style: TextStyle(fontSize: 12, color: textSecondary)),
                      Text('Lote: ${p.lote}', style: TextStyle(fontSize: 12, color: textSecondary)),
                      const SizedBox(height: 8),
                      CategoryBadge(label: p.origem, color: AppColors.info),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Venda', style: TextStyle(fontSize: 10, color: textSecondary)),
                    Text(
                      _currencyFormat.format(p.valorVenda),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.success),
                    ),
                    const SizedBox(height: 4),
                    Text('Custo: ${_currencyFormat.format(p.valorCompra)}', style: TextStyle(fontSize: 11, color: textSecondary)),
                    Text('Lucro: ${lucroPerc.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          
          // ── Divider ──
          Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),

          // ── Controles Estoque Rápido ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Em Estoque:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: AppColors.error,
                      onPressed: p.quantidade > 0 ? () => _ajustarEstoque(p, -1) : null,
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${p.quantidade}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isLowStock ? AppColors.error : textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: AppColors.success,
                      onPressed: () => _ajustarEstoque(p, 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
