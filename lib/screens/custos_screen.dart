import 'package:flutter/material.dart';
import '../services/supabase_helper.dart';
import '../models/custo_operacional.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_text_field.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// CustosScreen — Custos Operacionais v2.0
///
/// Interface para gestão de custos fixos, alinhada ao design premium.
/// ═══════════════════════════════════════════════════════════════════════
class CustosScreen extends StatefulWidget {
  final bool isEmbedded;
  const CustosScreen({super.key, this.isEmbedded = false});

  @override
  State<CustosScreen> createState() => _CustosScreenState();
}

class _CustoEntry {
  String? id;
  final TextEditingController nomeController;
  final TextEditingController valorController;

  _CustoEntry({
    this.id,
    required this.nomeController,
    required this.valorController,
  });
}

class _CustosScreenState extends State<CustosScreen> {
  List<_CustoEntry> _entradas = [];
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarCustos();
  }

  Future<void> _carregarCustos() async {
    setState(() => _carregando = true);
    try {
      final custos = await SupabaseHelper.getCustosOperacionais();
      setState(() {
        if (custos.isEmpty) {
          _entradas = [
            _CustoEntry(nomeController: TextEditingController(), valorController: TextEditingController())
          ];
        } else {
          _entradas = custos.map((c) => _CustoEntry(
                id: c.id,
                nomeController: TextEditingController(text: c.nome),
                valorController: TextEditingController(text: c.valor.toStringAsFixed(2).replaceAll('.', ',')),
              )).toList();
        }
        _carregando = false;
      });
    } catch (e) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _adicionarCusto() {
    setState(() {
      _entradas.add(_CustoEntry(nomeController: TextEditingController(), valorController: TextEditingController()));
    });
  }

  void _removerCusto(int index) {
    if (_entradas.length == 1) return;
    setState(() {
      _entradas[index].nomeController.dispose();
      _entradas[index].valorController.dispose();
      _entradas.removeAt(index);
    });
  }

  double _calcularSomatoria() {
    double soma = 0;
    for (var entry in _entradas) {
      double? valor = double.tryParse(entry.valorController.text.replaceAll('.', '').replaceAll(',', '.'));
      if (valor != null) soma += valor;
    }
    return soma;
  }

  Future<void> _salvarCustos() async {
    setState(() => _salvando = true);
    try {
      final listaSalva = <CustoOperacional>[];
      for (var entry in _entradas) {
        final nome = entry.nomeController.text.trim();
        final valor = double.tryParse(entry.valorController.text.replaceAll('.', '').replaceAll(',', '.'));

        if (nome.isEmpty && entry.valorController.text.trim().isEmpty) continue;

        listaSalva.add(CustoOperacional(
          id: entry.id,
          nome: nome.isEmpty ? 'Custo Operacional' : nome,
          valor: valor ?? 0,
        ));
      }

      await SupabaseHelper.replaceCustosOperacionais(listaSalva);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custos salvos com sucesso!'), backgroundColor: AppColors.success),
        );
      }
      await _carregarCustos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    for (var entry in _entradas) {
      entry.nomeController.dispose();
      entry.valorController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = AppColors.goldForBrightness(Theme.of(context).brightness);
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final content = _carregando
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: gold.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total Custos Fixos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'R\$ ${_calcularSomatoria().toStringAsFixed(2).replaceAll('.', ',')}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: gold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Detalhamento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ..._entradas.asMap().entries.map((entry) {
                  final index = entry.key;
                  final custo = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderCol),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: CustomTextField(
                            controller: custo.nomeController,
                            label: 'Descrição',
                            hint: 'Ex: Aluguel',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: CustomTextField(
                            controller: custo.valorController,
                            label: 'Valor',
                            hint: '0,00',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_entradas.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 4),
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.error),
                              onPressed: () => _removerCusto(index),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _adicionarCusto,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar Novo Custo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: gold,
                    side: BorderSide(color: gold.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _salvando ? null : _salvarCustos,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: AppColors.darkBackground,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _salvando
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Custos Operacionais')),
      body: content,
    );
  }
}
