import 'package:flutter/material.dart';
import '../models/produto.dart';
import '../utils/moeda_formatter.dart';
import '../services/supabase_helper.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'leitor_screen.dart';
import 'tela_dashboard.dart';
import 'tela_vendedor.dart';
import 'tela_login.dart';
import 'tela_alertas.dart';
import 'tela_suporte.dart';
import 'tela_tutorial_web.dart';
import '../widgets/app_drawer.dart';

class TelaEstoque extends StatefulWidget {
  final List<Produto>? estoque;
  final VoidCallback? onUpdate;
  const TelaEstoque({super.key, this.estoque, this.onUpdate});

  @override
  State<TelaEstoque> createState() => _TelaEstoqueState();
}

class _TelaEstoqueState extends State<TelaEstoque> with TickerProviderStateMixin {
  List<Produto> estoqueLocal = [];
  Map<String, int> vendadasPorProduto = {};
  int clientesHoje = 0;
  int alertasNaoLidos = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarEstoque();
    _carregarClientesHoje();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregarEstoque() async {
    if (widget.estoque != null) {
      setState(() {
        estoqueLocal = widget.estoque!;
        // Carregar vendidas do banco
        for (var p in estoqueLocal) {
          vendadasPorProduto[p.codigo] = p.vendidas;
        }
      });
    } else {
      final produtos = await SupabaseHelper.getEstoque();
      setState(() {
        estoqueLocal = produtos;
        // Carregar vendidas do banco
        for (var p in estoqueLocal) {
          vendadasPorProduto[p.codigo] = p.vendidas;
        }
      });
    }
    final contagemAlertas = await SupabaseHelper.contarAlertasNaoLidos();
    if (mounted) {
      setState(() {
        alertasNaoLidos = contagemAlertas;
      });
    }
  }

  Future<void> _carregarClientesHoje() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      clientesHoje = prefs.getInt('clientes_hoje_salvo') ?? 0;
    });
  }

  Future<void> _atualizarClientes(int novoValor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('clientes_hoje_salvo', novoValor);
    setState(() {
      clientesHoje = novoValor;
    });
  }

  void _onUpdate() {
    _carregarEstoque();
    if (widget.onUpdate != null) {
      widget.onUpdate!();
    }
  }

  // ==================== ABAS ====================

  Widget _buildAbaInventario() {
    return estoqueLocal.isEmpty
        ? const Center(child: Text("Estoque vazio."))
        : ListView.builder(
            itemCount: estoqueLocal.length,
            itemBuilder: (ctx, i) {
              final p = estoqueLocal[i];
              final lucroUnid = p.valorVenda - p.valorCompra;
              final isFabricado = p.origem.toLowerCase() == 'fabricado' || p.origem.toLowerCase() == 'produzido';
              final critico = p.quantidade <= 5;
              return Dismissible(
                key: Key('${p.codigo}_$i'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) async {
                  await SupabaseHelper.deleteProduto(p.codigo);
                  _onUpdate();
                },
                background: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: Card(
                  elevation: critico ? 6 : 3,
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: critico ? Colors.red.shade400 : Colors.transparent, width: 2),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: critico ? LinearGradient(colors: [Colors.red.shade50, Colors.white]) : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    if (critico) const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                                    if (critico) const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        p.nome,
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: critico ? Colors.red.shade900 : Colors.black87),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isFabricado ? Colors.purple.shade100 : Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  p.origem,
                                  style: TextStyle(color: isFabricado ? Colors.purple.shade900 : Colors.blue.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text("Qtd: ${p.quantidade}", style: p.quantidade <= 5 ? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold) : null),
                          Text("Custo: R\$ ${p.valorCompra.toStringAsFixed(2).replaceAll('.', ',')}"),
                          const SizedBox(height: 4),
                          // Lógica Inteligente de Exibição das Datas
                          ...(() {
                            String textEntrada = p.dataEntrada != null 
                              ? "Entrada: ${p.dataEntrada!.day.toString().padLeft(2, '0')}/${p.dataEntrada!.month.toString().padLeft(2, '0')}/${p.dataEntrada!.year}"
                              : "Entrada não registrada";

                            Widget validadeWidget;
                            if (p.dataValidade == null) {
                              validadeWidget = Text(
                                "Validade não registrada",
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              );
                            } else {
                              final hoje = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                              final validade = DateTime(p.dataValidade!.year, p.dataValidade!.month, p.dataValidade!.day);
                              final diferenca = validade.difference(hoje).inDays;
                              
                              String dataFormatada = "${p.dataValidade!.day.toString().padLeft(2, '0')}/${p.dataValidade!.month.toString().padLeft(2, '0')}/${p.dataValidade!.year}";

                              if (diferenca <= 0) {
                                validadeWidget = Row(
                                  children: [
                                    const Text("❌ ", style: TextStyle(fontSize: 12)),
                                    Text(
                                      "PRODUTO VENCIDO ($dataFormatada)",
                                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                );
                              } else if (diferenca >= 1 && diferenca <= 14) {
                                validadeWidget = Row(
                                  children: [
                                    const Text("⚠️ ", style: TextStyle(fontSize: 12)),
                                    Text(
                                      "Vence em $diferenca dias ($dataFormatada)",
                                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                );
                              } else {
                                validadeWidget = Text(
                                  "Validade: $dataFormatada",
                                  style: const TextStyle(color: Colors.green, fontSize: 12),
                                );
                              }
                            }

                            return [
                              Text(textEntrada, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                              const SizedBox(height: 2),
                              validadeWidget,
                            ];
                          })(),
                          const SizedBox(height: 4),
                          Text("Margem Bruta: ${((lucroUnid / p.valorVenda) * 100).toStringAsFixed(1)}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo)),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _edit(i), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                                  const SizedBox(width: 16),
                                ],
                              ),
                              Text("Lucro Unid: R\$ ${lucroUnid.toStringAsFixed(2).replaceAll('.', ',')}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ));
            },
          );
  }

  Widget _buildAbaVendas() {
    double totalVendido = 0;
    for (var p in estoqueLocal) {
      int vendidas = vendadasPorProduto[p.codigo] ?? 0;
      totalVendido += vendidas * p.valorVenda;
    }

    return estoqueLocal.isEmpty
        ? const Center(child: Text("Nenhum produto no estoque."))
        : SingleChildScrollView(
            child: Column(
              children: [
                // ====== CARD DE CLIENTES ======
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue.shade200),
                    boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 8)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, color: Colors.blue.shade700, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            "Clientes Hoje",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: clientesHoje > 0
                                    ? () => _atualizarClientes(clientesHoje - 1)
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                                color: Colors.red,
                                iconSize: 28,
                              ),
                              GestureDetector(
                                onTap: () {
                                  TextEditingController ctrl = TextEditingController(text: clientesHoje.toString());
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("Editar Clientes"),
                                      content: TextField(
                                        controller: ctrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(labelText: "Número de clientes"),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text("Cancelar"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            int? value = int.tryParse(ctrl.text);
                                            if (value != null && value >= 0) {
                                              _atualizarClientes(value);
                                              Navigator.pop(ctx);
                                            }
                                          },
                                          child: const Text("Salvar"),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    clientesHoje.toString(),
                                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _atualizarClientes(clientesHoje + 1),
                                icon: const Icon(Icons.add_circle_outline),
                                color: Colors.green,
                                iconSize: 28,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ====== LISTA DE PRODUTOS COM VENDAS ======
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: estoqueLocal.length,
                    itemBuilder: (ctx, i) {
                      final p = estoqueLocal[i];
                      int vendidas = vendadasPorProduto[p.codigo] ?? 0;
                      int restante = p.quantidade - vendidas;
                      double totalVendidoProduto = vendidas * p.valorVenda;
                      final critico = restante <= 5;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: critico ? Colors.red.shade200 : Colors.transparent, width: 2),
                        ),
                        elevation: critico ? 4 : 2,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: critico ? Colors.red.shade50 : Colors.white,
                          ),
                          child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.nome,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              "Vendidas: $vendidas",
                                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                                            ),
                                            const SizedBox(width: 20),
                                            Text(
                                              "Restante: $restante",
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: restante <= 0 ? Colors.red : Colors.black87,
                                                fontWeight: restante <= 0 ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.green.shade300),
                                        ),
                                        child: Text(
                                          "Total:\nR\$ ${totalVendidoProduto.toStringAsFixed(2).replaceAll('.', ',')}",
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // ====== CONTROLADOR DE VENDIDAS ======
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Quantidade vendida:",
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: vendidas > 0
                                            ? () async {
                                                setState(() => vendadasPorProduto[p.codigo] = vendidas - 1);
                                                final produtoAtualizado = Produto(
                                                  codigo: p.codigo,
                                                  nome: p.nome,
                                                  lote: p.lote,
                                                  quantidade: p.quantidade,
                                                  valorCompra: p.valorCompra,
                                                  markup: p.markup,
                                                  valorVenda: p.valorVenda,
                                                  origem: p.origem,
                                                  vendidas: vendidas - 1,
                                                );
                                                await SupabaseHelper.insertProduto(produtoAtualizado);
                                              }
                                            : null,
                                        icon: const Icon(Icons.remove),
                                        color: Colors.red,
                                        iconSize: 20,
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(6),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          TextEditingController ctrl = TextEditingController(text: vendidas.toString());
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: Text("Editar vendidas de ${p.nome}"),
                                              content: TextField(
                                                controller: ctrl,
                                                keyboardType: TextInputType.number,
                                                decoration: const InputDecoration(labelText: "Unidades vendidas"),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx),
                                                  child: const Text("Cancelar"),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    int? value = int.tryParse(ctrl.text);
                                                    if (value != null && value >= 0 && value <= p.quantidade) {
                                                      setState(() => vendadasPorProduto[p.codigo] = value);
                                                      final produtoAtualizado = Produto(
                                                        codigo: p.codigo,
                                                        nome: p.nome,
                                                        lote: p.lote,
                                                        quantidade: p.quantidade,
                                                        valorCompra: p.valorCompra,
                                                        markup: p.markup,
                                                        valorVenda: p.valorVenda,
                                                        origem: p.origem,
                                                        vendidas: value,
                                                      );
                                                      await SupabaseHelper.insertProduto(produtoAtualizado);
                                                      Navigator.pop(ctx);
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text("Valor inválido")),
                                                      );
                                                    }
                                                  },
                                                  child: const Text("Salvar"),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            vendidas.toString(),
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: vendidas < p.quantidade
                                            ? () async {
                                                setState(() => vendadasPorProduto[p.codigo] = vendidas + 1);
                                                final produtoAtualizado = Produto(
                                                  codigo: p.codigo,
                                                  nome: p.nome,
                                                  lote: p.lote,
                                                  quantidade: p.quantidade,
                                                  valorCompra: p.valorCompra,
                                                  markup: p.markup,
                                                  valorVenda: p.valorVenda,
                                                  origem: p.origem,
                                                  vendidas: vendidas + 1,
                                                );
                                                await SupabaseHelper.insertProduto(produtoAtualizado);
                                                
                                                // 1. Registra a venda pro Gráfico 
                                                await SupabaseHelper.registrarVenda(p.codigo, 1, p.valorVenda);
                                                // 2. Dispara evento de métrica pro Firebase Analytics
                                                await FirebaseAnalytics.instance.logEvent(
                                                  name: 'venda_realizada',
                                                  parameters: {'codigo': p.codigo, 'qtd': 1, 'valor': p.valorVenda},
                                                );
                                              }
                                            : null,
                                        icon: const Icon(Icons.add),
                                        color: Colors.green,
                                        iconSize: 20,
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(6),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
  }

  void _edit(int index) {
    Produto p = estoqueLocal[index];
    TextEditingController n = TextEditingController(text: p.nome);
    DateTime? validadeModal = p.dataValidade;
    TextEditingController q = TextEditingController(
      text: p.quantidade.toString(),
    );
    TextEditingController custoCtrl = TextEditingController(
      text: p.valorCompra.toStringAsFixed(2).replaceAll('.', ','),
    );
    TextEditingController markupCtrl = TextEditingController(
      text: p.markup.toString(),
    );
    TextEditingController vendaCtrl = TextEditingController(
      text: p.valorVenda.toStringAsFixed(2).replaceAll('.', ','),
    );
    String tipoSelecionado = (p.origem.toLowerCase() == 'fabricado' || p.origem.toLowerCase() == 'produzido') ? 'Fabricado' : 'Revendido';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        // <-- Isso permite atualizar a caixinha em tempo real!
        builder: (context, setStateModal) {
          bool margemSeguraModal = double.tryParse(markupCtrl.text.replaceAll(',', '.')) != null && double.parse(markupCtrl.text.replaceAll(',', '.')) >= 1.3;

          // Função que recalcula a Venda na hora que digita o Custo ou Markup
          void recalcularVenda() {
            double? c = double.tryParse(
              custoCtrl.text.replaceAll('.', '').replaceAll(',', '.'),
            );
            double? m = double.tryParse(markupCtrl.text.replaceAll(',', '.'));
            if (c != null && m != null) {
              setStateModal(() {
                margemSeguraModal = m >= 1.3;
                vendaCtrl.text = (c * m)
                    .toStringAsFixed(2)
                    .replaceAll('.', ',');
              });
            }
          }

          return AlertDialog(
            title: const Text("Editar Produto"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: n,
                    decoration: const InputDecoration(labelText: "Nome do Produto"),
                  ),
                  TextField(
                    controller: q,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Quantidade em Estoque"),
                  ),
                  TextField(
                    controller: custoCtrl,
                    inputFormatters: [MoedaFormatter()],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Custo Unitário (R\$)"),
                    onChanged: (_) =>
                        recalcularVenda(), // Chama o cálculo ao digitar
                  ),
                  TextField(
                    controller: markupCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: "Margem de Lucro (Markup)",
                      errorText: margemSeguraModal ? null : '⚠️ Margem muito baixa!',
                    ),
                    onChanged: (_) =>
                        recalcularVenda(), 
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_month, color: Colors.blueGrey),
                    label: Text(validadeModal != null 
                      ? "Vence em: ${validadeModal!.day.toString().padLeft(2, '0')}/${validadeModal!.month.toString().padLeft(2, '0')}/${validadeModal!.year}" 
                      : "Definir Data de Validade"),
                    onPressed: () async {
                      final data = await showDatePicker(
                        context: context,
                        initialDate: validadeModal ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (data != null) {
                        setStateModal(() => validadeModal = data);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: tipoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Origem do Produto',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Revendido',
                        child: Text('Revendido'),
                      ),
                      DropdownMenuItem(
                        value: 'Fabricado',
                        child: Text('Fabricado'),
                      ),
                    ],
                    onChanged: (value) {
                      setStateModal(() => tipoSelecionado = value!);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: vendaCtrl,
                    readOnly: true,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Preço de Venda Sugerido (R\$)",
                      filled: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!margemSeguraModal) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Ação Bloqueada: Corrija a margem de lucro!"),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  int? parsedQtd = int.tryParse(q.text);
                  double? parsedCusto = double.tryParse(custoCtrl.text.replaceAll('.', '').replaceAll(',', '.'));
                  double? parsedMarkup = double.tryParse(markupCtrl.text.replaceAll(',', '.'));
                  double? parsedVenda = double.tryParse(vendaCtrl.text.replaceAll('.', '').replaceAll(',', '.'));

                  if (parsedQtd == null || parsedCusto == null || parsedMarkup == null || parsedVenda == null ||
                      parsedQtd <= 0 || parsedCusto <= 0 || parsedMarkup <= 0 || parsedVenda <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Erro: Valores numéricos não podem estar vazios ou zerados!"),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Produto produtoAtualizado = Produto(
                    codigo: p.codigo,
                    nome: n.text,
                    lote: p.lote,
                    quantidade: parsedQtd,
                    valorCompra: parsedCusto,
                    markup: parsedMarkup,
                    valorVenda: parsedVenda,
                    dataValidade: validadeModal,
                    dataEntrada: p.dataEntrada ?? DateTime.now(), // Registra a entrada original!
                    origem: tipoSelecionado,
                  );

                  await SupabaseHelper.insertProduto(produtoAtualizado);

                  _onUpdate();
                  if (mounted) Navigator.pop(ctx);
                },
                child: const Text("Salvar"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Estoque Atual"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          // Ícone de Alertas / Avisos com Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_active_outlined),
                tooltip: 'Central de Alertas & Avisos',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaAlertas())).then((_) => _carregarEstoque());
                },
              ),
              if (alertasNaoLidos > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$alertasNaoLidos',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Ícone de Ajuda e Suporte
          IconButton(
            icon: const Icon(Icons.support_agent),
            tooltip: 'Fale com o Suporte',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaSuporte()));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: "Inventário"),
            Tab(icon: Icon(Icons.sell), text: "Vendas"),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAbaInventario(),
          _buildAbaVendas(),
        ],
      ),
    );
  }
}
