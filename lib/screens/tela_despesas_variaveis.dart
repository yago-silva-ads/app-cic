import 'package:flutter/material.dart';
import '../models/despesa_variavel.dart';
import '../services/supabase_helper.dart';
import '../widgets/app_drawer.dart';

class TelaDespesasVariaveis extends StatefulWidget {
  const TelaDespesasVariaveis({super.key});

  @override
  State<TelaDespesasVariaveis> createState() => _TelaDespesasVariaveisState();
}

class _TelaDespesasVariaveisState extends State<TelaDespesasVariaveis> {
  List<DespesaVariavel> despesas = [];
  bool _carregando = true;
  String _filtroPeriodo = 'Mês'; // Padrão: mês atual

  @override
  void initState() {
    super.initState();
    _carregarDespesas();
  }

  Future<void> _carregarDespesas() async {
    try {
      final resultado = await SupabaseHelper.getDespesasVariaveis();
      if (!mounted) return;
      setState(() {
        despesas = resultado;
        _carregando = false;
      });
    } catch (e) {
      print("Erro ao carregar despesas variáveis: $e");
      if (!mounted) return;
      setState(() => _carregando = false);
    }
  }

  List<DespesaVariavel> _filtrarDespesas() {
    final agora = DateTime.now();
    return despesas.where((d) {
      final data = d.criadoEm?.toLocal() ?? agora;
      if (_filtroPeriodo == 'Hoje') {
        return data.year == agora.year &&
            data.month == agora.month &&
            data.day == agora.day;
      } else if (_filtroPeriodo == '7 Dias') {
        return agora.difference(data).inDays.abs() <= 7;
      } else if (_filtroPeriodo == 'Mês') {
        return data.year == agora.year && data.month == agora.month;
      }
      return true; // 'Tudo'
    }).toList()
      ..sort((a, b) {
        final dtA = a.criadoEm;
        final dtB = b.criadoEm;
        if (dtA == null && dtB == null) return 0;
        if (dtA == null) return 1;
        if (dtB == null) return -1;
        return dtB.compareTo(dtA); // Mais recentes primeiro
      });
  }

  double _calcularTotal(List<DespesaVariavel> lista) {
    double soma = 0;
    for (var d in lista) {
      soma += d.valor;
    }
    return soma;
  }

  Future<void> _confirmarExclusao(DespesaVariavel despesa) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir Despesa"),
        content: Text(
          "Deseja realmente excluir a despesa '${despesa.nome}' "
          "de R\$ ${despesa.valor.toStringAsFixed(2).replaceAll('.', ',')}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              "Excluir",
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true && despesa.id != null) {
      await SupabaseHelper.deleteDespesaVariavel(despesa.id!);
      _carregarDespesas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Despesa '${despesa.nome}' excluída."),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  String _formatarData(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final despesasFiltradas = _carregando ? <DespesaVariavel>[] : _filtrarDespesas();
    final totalFiltrado = _calcularTotal(despesasFiltradas);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Despesas Variáveis"),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregarDespesas,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Filtro de Período
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Hoje', '7 Dias', 'Mês', 'Tudo'].map((periodo) {
                          final isSelected = _filtroPeriodo == periodo;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(
                                periodo,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: Colors.red.shade700,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _filtroPeriodo = periodo);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card de Somatório
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade700, Colors.red.shade900],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "💸 Total de Despesas Variáveis",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "${despesasFiltradas.length} registro(s)",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "R\$ ${totalFiltrado.toStringAsFixed(2).replaceAll('.', ',')}",
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Período: $_filtroPeriodo",
                            style: const TextStyle(fontSize: 12, color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Lista de despesas
                    const Text(
                      "Histórico de Despesas",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const Divider(),
                    despesasFiltradas.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            child: Text(
                              "Nenhuma despesa variável registrada neste período.",
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: despesasFiltradas.length,
                            itemBuilder: (ctx, index) {
                              final d = despesasFiltradas[index];
                              return Dismissible(
                                key: Key(d.id ?? index.toString()),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) async {
                                  await _confirmarExclusao(d);
                                  return false; // Não remove automaticamente, o reload faz isso
                                },
                                background: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade900,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.shade200),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.red.shade100,
                                      child: Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.red.shade700,
                                        size: 24,
                                      ),
                                    ),
                                    title: Text(
                                      d.nome,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        "Despesa Variável • ${_formatarData(d.criadoEm)}",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red.shade400,
                                        ),
                                      ),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "- R\$ ${d.valor.toStringAsFixed(2).replaceAll('.', ',')}",
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Pagamento / Saída",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.red.shade600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
