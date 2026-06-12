import 'package:flutter/material.dart';
import '../services/relatorio_service.dart';

/// Widget de exemplo mostrando como usar o RelatorioService
/// 
/// Este widget demonstra como exibir as análises geradas pelo
/// RelatorioService de forma visual para o usuário
class EstatisticasAvancadasWidget extends StatefulWidget {
  const EstatisticasAvancadasWidget({super.key});

  @override
  State<EstatisticasAvancadasWidget> createState() =>
      _EstatisticasAvancadasWidgetState();
}

class _EstatisticasAvancadasWidgetState
    extends State<EstatisticasAvancadasWidget> {
  bool _carregando = true;
  Map<String, dynamic> _dados = {};

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);

    try {
      // Carrega todos os dados em paralelo
      final [
        stats,
        topProdutos,
        produtosEmFalta,
      ] = await Future.wait([
        RelatorioService.getEstatisticasGerais(),
        RelatorioService.getProdutosMaisVendidos(limit: 5),
        RelatorioService.getProdutosEmFalta(minimo: 5),
      ]);

      setState(() {
        _dados = {
          'stats': stats,
          'topProdutos': topProdutos,
          'produtosEmFalta': produtosEmFalta,
        };
        _carregando = false;
      });
    } catch (e) {
      print("Erro ao carregar dados: $e");
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregarDados,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== RESUMO EXECUTIVO =====
          _buildResumoExecutivo(),
          const SizedBox(height: 24),

          // ===== TOP 5 PRODUTOS =====
          _buildTopProdutos(),
          const SizedBox(height: 24),

          // ===== ALERTA: PRODUTOS EM FALTA =====
          if ((_dados['produtosEmFalta'] as List).isNotEmpty)
            _buildProdutosEmFalta(),
        ],
      ),
    );
  }

  Widget _buildResumoExecutivo() {
    final stats = _dados['stats'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumo Executivo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricaRow(
            'Faturamento Total',
            'R\$ ${stats['total_faturado']?.toStringAsFixed(2) ?? '0.00'}',
            Colors.white,
          ),
          const SizedBox(height: 8),
          _buildMetricaRow(
            'Custos Operacionais',
            'R\$ ${stats['custos_operacionais']?.toStringAsFixed(2) ?? '0.00'}',
            Colors.red.shade300,
          ),
          const SizedBox(height: 8),
          _buildMetricaRow(
            'Total de Vendas',
            '${stats['total_vendas'] ?? 0} transações',
            Colors.white70,
          ),
          const SizedBox(height: 8),
          _buildMetricaRow(
            'Ticket Médio',
            'R\$ ${(stats['ticket_medio'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
            Colors.white70,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricaRow(String label, String valor, Color cor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: cor.withOpacity(0.8),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
      ],
    );
  }

  Widget _buildTopProdutos() {
    final topProdutos = _dados['topProdutos'] as List;

    if (topProdutos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Nenhuma venda registrada ainda'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top 5 Produtos Mais Rentáveis',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: List.generate(
              topProdutos.length,
              (index) {
                final p = topProdutos[index] as Map<String, dynamic>;
                return _buildProdutoItem(
                  index + 1,
                  p['nome'] ?? 'Produto Excluído',
                  '${p['total_vendas'] ?? 0} vendas',
                  'R\$ ${(p['total_faturado'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProdutoItem(
    int posicao,
    String nome,
    String vendas,
    String faturamento,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blue.shade500,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$posicao',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  vendas,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            faturamento,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProdutosEmFalta() {
    final emFalta = _dados['produtosEmFalta'] as List;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(
                'Alerta: ${emFalta.length} produto(s) em falta',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              emFalta.length,
              (index) {
                final p = emFalta[index] as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${p['nome']}: ${p['quantidade']} unidades',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
