import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/custo_operacional.dart';
import '../services/supabase_helper.dart';
import '../utils/moeda_formatter.dart';
import 'leitor_screen.dart';
import 'tela_dashboard.dart';
import 'tela_estoque.dart';
import 'tela_login.dart';
import '../widgets/app_drawer.dart';

class TelaVendedor extends StatefulWidget {
  const TelaVendedor({super.key});

  @override
  State<TelaVendedor> createState() => _TelaVendedorState();
}

class _CustoEntry {
  String? id; // UUID no Supabase (era int?)
  final TextEditingController nomeController;
  final TextEditingController valorController;

  _CustoEntry({
    this.id,
    required this.nomeController,
    required this.valorController,
  });
}

class _TelaVendedorState extends State<TelaVendedor> {
  List<_CustoEntry> custoEntries = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarCustos();
  }

  Future<void> _carregarCustos() async {
    try {
      final custos = await SupabaseHelper.getCustosOperacionais();
      setState(() {
        if (custos.isEmpty) {
          custoEntries = [
            _CustoEntry(
              nomeController: TextEditingController(),
              valorController: TextEditingController(),
            ),
          ];
        } else {
          custoEntries = custos
              .map(
                (custo) => _CustoEntry(
                  id: custo.id,
                  nomeController: TextEditingController(text: custo.nome),
                  valorController: TextEditingController(
                    text: custo.valor.toStringAsFixed(2).replaceAll('.', ','),
                  ),
                ),
              )
              .toList();
        }
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
    }
  }

  void _adicionarCusto() {
    setState(() {
      custoEntries.add(
        _CustoEntry(
          nomeController: TextEditingController(),
          valorController: TextEditingController(),
        ),
      );
    });
  }

  void _removerCusto(int index) {
    if (custoEntries.length == 1) return;
    setState(() {
      custoEntries[index].nomeController.dispose();
      custoEntries[index].valorController.dispose();
      custoEntries.removeAt(index);
    });
  }

  double _calcularSomatoria() {
    double soma = 0;
    for (var entry in custoEntries) {
      double? valor = double.tryParse(
        entry.valorController.text.replaceAll('.', '').replaceAll(',', '.'),
      );
      if (valor != null) {
        soma += valor;
      }
    }
    return soma;
  }

  Future<void> _salvarCustos() async {
    try {
      final listaSalva = <CustoOperacional>[];
      for (var entry in custoEntries) {
        final nome = entry.nomeController.text.trim();
        final valor = double.tryParse(
          entry.valorController.text.replaceAll('.', '').replaceAll(',', '.'),
        );

        if (nome.isEmpty && (entry.valorController.text.trim().isEmpty)) {
          continue;
        }

        listaSalva.add(
          CustoOperacional(
            id: entry.id,
            nome: nome.isEmpty ? 'Custo Operacional' : nome,
            valor: valor ?? 0,
          ),
        );
      }

      await SupabaseHelper.replaceCustosOperacionais(listaSalva);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custos operacionais salvos com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _carregarCustos();
    } catch (e, stack) {
      print("Erro ao salvar custos: $e\n$stack");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar os custos operacionais: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (var entry in custoEntries) {
      entry.nomeController.dispose();
      entry.valorController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Custos Operacionais"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Insira os custos fixos operacionais aplicáveis:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ...custoEntries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final custo = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: custo.nomeController,
                              decoration: const InputDecoration(
                                labelText: 'Nome do Custo',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: custo.valorController,
                              inputFormatters: [MoedaFormatter()],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Valor (R\$)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          if (custoEntries.length > 1)
                            IconButton(
                              onPressed: () => _removerCusto(index),
                              icon: const Icon(Icons.delete, color: Colors.red),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _adicionarCusto,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Adicionar Custo', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _salvarCustos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Salvar Custos', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                  const SizedBox(height: 30),
                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text(
                            'Somatória dos Custos Operacionais',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'R\$ ${_calcularSomatoria().toStringAsFixed(2).replaceAll('.', ',')}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}