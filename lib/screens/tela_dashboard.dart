import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/produto.dart';
import '../services/supabase_helper.dart';
import '../services/ia_service.dart';
import '../models/custo_operacional.dart';
import 'leitor_screen.dart';
import 'tela_estoque.dart';
import 'tela_vendedor.dart';
import 'tela_chat_ia.dart';
import 'tela_login.dart';
import 'tela_tutorial_web.dart';
import '../widgets/app_drawer.dart';

class TelaDashboard extends StatefulWidget {
  const TelaDashboard({super.key});

  @override
  State<TelaDashboard> createState() => _TelaDashboardState();
}

class _TelaDashboardState extends State<TelaDashboard> {
  List<Produto> estoque = [];
  List<Map<String, dynamic>> historicoVendas = [];
  List<CustoOperacional> custosOperacionais = [];
  bool _isAnalyzing = false;
  String? _analiseIA;
  bool _isLoading = true;
  String _filtroPeriodo = 'Tudo'; // 'Hoje', '7 Dias', 'Mês', 'Tudo'

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    List<Produto> dados = [];
    List<Map<String, dynamic>> historico = [];
    List<CustoOperacional> custos = [];

    try {
      dados = await SupabaseHelper.getEstoque();
    } catch (e) {
      print("Dashboard: Erro ao carregar estoque: $e");
    }

    try {
      historico = await SupabaseHelper.getHistoricoVendas();
    } catch (e) {
      print("Dashboard: Erro ao carregar historico: $e");
    }

    try {
      custos = await SupabaseHelper.getCustosOperacionais();
    } catch (e) {
      print("Dashboard: Erro ao carregar custos: $e");
    }

    if (!mounted) return; // Proteção: impede erro se o usuário fechar a tela durante o carregamento

    setState(() {
      estoque = dados;
      historicoVendas = historico;
      custosOperacionais = custos;
      _isLoading = false;
    });
  }

  Future<void> _gerarAnaliseInteligente() async {
    setState(() {
      _isAnalyzing = true;
      _analiseIA = null;
    });

    // Envia o estoque E O HISTÓRICO para a IA fazer a visão preditiva!
    String resposta = await IaService.analisarEstoque(estoque, historicoVendas, custosOperacionais);

    if (!mounted) return; // Proteção

    setState(() {
      _analiseIA = resposta;
      _isAnalyzing = false;
    });
  }

  Widget _buildAlertaPrejuizo() {
    double lucroProjetado = 0;
    for (var p in estoque) {
      lucroProjetado += (p.valorVenda - p.valorCompra) * p.quantidade;
    }

    double custoTotal = 0;
    for (var c in custosOperacionais) {
      custoTotal += c.valor;
    }

    // Limite da Meta: Exibe aviso de prejuízo caso o lucro bruto não cubra o custo operacional.
    if (lucroProjetado < custoTotal && custoTotal > 0) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '⚠️ Alerta: Seu lucro projetado não cobre os custos operacionais mensais. Reveja a margem de lucro dos seus produtos.',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildAbaCurvaABC() {
    if (estoque.isEmpty) {
      return const Center(child: Text("Sem dados no estoque para analisar."));
    }

    List<Produto> listaOrdenada = List.from(estoque);

    listaOrdenada.sort((a, b) {
      double lucroA = a.quantidade * (a.valorVenda - a.valorCompra);
      double lucroB = b.quantidade * (b.valorVenda - b.valorCompra);
      return lucroB.compareTo(lucroA);
    });

    int total = listaOrdenada.length;
    int limiteA = (total * 0.2).ceil();
    int limiteB = limiteA + (total * 0.3).ceil();

    return Column(
      children: [
        _buildAlertaPrejuizo(), // Card crítico fixado no topo
        Expanded(
          child: ListView.builder(
            itemCount: total,
            itemBuilder: (context, index) {
              Produto p = listaOrdenada[index];
              double lucroTotal = p.quantidade * (p.valorVenda - p.valorCompra);

              String classe;
              Color cor;
              if (index < limiteA) {
                classe = 'Classe A';
                cor = Colors.green;
              } else if (index < limiteB) {
                classe = 'Classe B';
                cor = Colors.orange;
              } else {
                classe = 'Classe C';
                cor = Colors.red;
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: cor.withOpacity(0.2),
                  child: Text(
                    classe.split(' ').last,
                    style: TextStyle(color: cor, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(p.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Lucro Projetado: R\$ ${lucroTotal.toStringAsFixed(2)}"),
                trailing: Text(classe, style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
              );
            },
          ),
        ),
      ],
    );
  }

  void _abrirSeletorMesAno(BuildContext context) {
    final meses = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    int anoSelecionado = DateTime.now().year;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Mês/Ano Específico", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 16),
                        onPressed: () => setDialogState(() => anoSelecionado--),
                      ),
                      Text("$anoSelecionado", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 16),
                        onPressed: () => setDialogState(() => anoSelecionado++),
                      ),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 300,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.8,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (ctx, idx) {
                    final mesLabel = "${meses[idx]}/$anoSelecionado";
                    final isCurrent = _filtroPeriodo == mesLabel;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _filtroPeriodo = mesLabel;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrent ? Colors.blue.shade800 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isCurrent ? Colors.blue.shade900 : Colors.blue.shade200),
                        ),
                        child: Text(
                          meses[idx],
                          style: TextStyle(
                            color: isCurrent ? Colors.white : Colors.blue.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Fechar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper para obter nome do mês abreviado em português (ex: Ago/2026)
  String _obterLabelMes(DateTime dt) {
    const meses = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return "${meses[dt.month - 1]}/${dt.year}";
  }

  void _mostrarModalPagarDespesa(BuildContext context) {
    final nomeController = TextEditingController();
    final valorController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "💸 Pagar Funcionário ou Adicionar Despesa",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "O valor informado será subtraído instantaneamente do seu Saldo em Caixa atual.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nomeController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Descrição (Ex: Salário Funcionário Carlos, Aluguel, Luz)",
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valorController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Valor (R\$)",
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Cancelar",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final nome = nomeController.text.trim();
                      final valor =
                          double.tryParse(
                            valorController.text.replaceAll(',', '.'),
                          ) ??
                          0.0;
                      if (nome.isEmpty || valor <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Preencha a descrição e um valor válido.",
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(ctx);

                      final novoCusto = CustoOperacional(
                        nome: nome,
                        valor: valor,
                      );
                      final novosCustos = [...custosOperacionais, novoCusto];
                      await SupabaseHelper.replaceCustosOperacionais(
                        novosCustos,
                      );
                      _carregarDados();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "✅ Despesa '$nome' (R\$ ${valor.toStringAsFixed(2)}) abatida do Caixa!",
                            ),
                            backgroundColor: const Color(0xFF00C853),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text(
                      "Salvar e Abater",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbaFluxoCaixa() {
    // 1. Extrair meses distintos históricos dinamicamente
    final Set<String> mesesHistoricos = {};
    for (var v in historicoVendas) {
      if (v['criado_em'] != null) {
        final dt = DateTime.tryParse(v['criado_em'].toString());
        if (dt != null) {
          mesesHistoricos.add(_obterLabelMes(dt));
        }
      }
    }
    final listaOpcoesPeriodo = [
      'Hoje',
      '7 Dias',
      'Mês',
      ...mesesHistoricos,
      'Tudo',
    ];
    if (!listaOpcoesPeriodo.contains(_filtroPeriodo)) {
      listaOpcoesPeriodo.insert(3, _filtroPeriodo);
    }

    // Filtragem por Período
    List<Map<String, dynamic>> historicoFiltrado = [];
    final agora = DateTime.now();

    for (var v in historicoVendas) {
      DateTime? dataVenda;
      if (v['criado_em'] != null) {
        dataVenda = DateTime.tryParse(v['criado_em'].toString());
      }
      dataVenda ??= agora;

      bool incluir = true;
      if (_filtroPeriodo == 'Hoje') {
        incluir =
            dataVenda.year == agora.year &&
            dataVenda.month == agora.month &&
            dataVenda.day == agora.day;
      } else if (_filtroPeriodo == '7 Dias') {
        incluir = agora.difference(dataVenda).inDays <= 7;
      } else if (_filtroPeriodo == 'Mês') {
        incluir =
            dataVenda.year == agora.year && dataVenda.month == agora.month;
      } else if (_filtroPeriodo != 'Tudo') {
        // Filtro por Mês/Ano específico (ex: Ago/2026)
        incluir = _obterLabelMes(dataVenda) == _filtroPeriodo;
      }

      if (incluir) {
        historicoFiltrado.add(v);
      }
    }

    if (historicoFiltrado.isEmpty && _filtroPeriodo == 'Tudo') {
      return const Center(
        child: Text(
          "Nenhuma venda registrada ainda no Supabase.\nVá em Estoque Atual -> Vendas e registre uma saída!",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    List<FlSpot> vendasSpots = [];
    double totalFaturamento = 0;
    double faturamentoAcumulado = 0;
    List<Widget> historicoDetalhado = [];

    for (int i = 0; i < historicoFiltrado.length; i++) {
      var venda = historicoFiltrado[i];
      double valorUnitario =
          double.tryParse(venda['valor_unitario'].toString()) ?? 0.0;
      int quantidade =
          int.tryParse(venda['quantidade_vendida'].toString()) ?? 0;
      String codigoProduto = venda['produto_codigo'].toString();

      double valorTotalVenda = valorUnitario * quantidade;
      totalFaturamento += valorTotalVenda;
      faturamentoAcumulado += valorTotalVenda;

      vendasSpots.add(FlSpot(i.toDouble(), faturamentoAcumulado));

      String nomeProduto = "Produto Excluído";
      try {
        nomeProduto =
            estoque.firstWhere((p) => p.codigo == codigoProduto).nome;
      } catch (_) {}

      historicoDetalhado.insert(
        0,
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade50,
              child: Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 24),
            ),
            title: Text(
              nomeProduto,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                "$quantidade un. vendidas a R\$ ${valorUnitario.toStringAsFixed(2).replaceAll('.', ',')}",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "+ R\$ ${valorTotalVenda.toStringAsFixed(2).replaceAll('.', ',')}",
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Venda Realizada",
                  style: TextStyle(fontSize: 10, color: Colors.green.shade600, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    double totalCustosMensal = custosOperacionais.fold(0.0, (s, c) => s + c.valor);
    // Proporcionalizar custos operacionais conforme o período selecionado
    double totalCustos;
    if (_filtroPeriodo == 'Hoje') {
      totalCustos = totalCustosMensal / 30.0; // Custo diário
    } else if (_filtroPeriodo == '7 Dias') {
      totalCustos = totalCustosMensal * 7 / 30.0; // Custo semanal
    } else {
      totalCustos = totalCustosMensal; // Mês inteiro ou 'Tudo'
    }
    double saldoCaixa = totalFaturamento - totalCustos;
    double rentabilidadePct =
        totalFaturamento > 0
            ? ((totalFaturamento - totalCustos) / totalFaturamento * 100)
            : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Acesso Rápido ao Tutorial e Portal Web Looker Studio
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.language, color: Colors.white, size: 30),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Portal Web Looker Studio & IA",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "Gráficos, Curva ABC e Acesso no PC",
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TelaTutorialWeb(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0D47A1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Tutorial / Acessar",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Seletor de Período Flexível (Meses Dinâmicos) + Botão Calendário Mês Específico
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...listaOpcoesPeriodo.map((periodo) {
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
                      selectedColor: Colors.blue.shade800,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _filtroPeriodo = periodo);
                        }
                      },
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    avatar: const Icon(Icons.calendar_month, size: 16, color: Colors.blue),
                    label: const Text(
                      "📅 Escolher Mês Específico...",
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.blue.shade50,
                    onPressed: () => _abrirSeletorMesAno(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Card de Saldo em Caixa Real + Botão de Pagar Funcionário/Despesa
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    saldoCaixa >= 0
                        ? [Colors.green.shade700, Colors.green.shade900]
                        : [Colors.red.shade700, Colors.red.shade900],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (saldoCaixa >= 0 ? Colors.green : Colors.red)
                      .withValues(alpha: 0.3),
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
                    const Expanded(
                      child: Text(
                        "💰 Saldo em Caixa (Vendas - Custos)",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                        "Rentabilidade: ${rentabilidadePct.toStringAsFixed(1)}%",
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
                  "R\$ ${saldoCaixa.toStringAsFixed(2).replaceAll('.', ',')}",
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Faturamento: R\$ ${totalFaturamento.toStringAsFixed(2)} | Custos: R\$ ${totalCustos.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _mostrarModalPagarDespesa(context),
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Pagar Funcionário / Saída",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TelaVendedor(),
                          ),
                        ).then((_) => _carregarDados());
                      },
                      icon: const Icon(Icons.edit, color: Colors.white),
                      tooltip: "Editar todos os custos",
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card de Faturamento do Período
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Vendas ($_filtroPeriodo)", style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                    const SizedBox(height: 4),
                    Text(
                      "R\$ ${totalFaturamento.toStringAsFixed(2).replaceAll('.', ',')}",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                    ),
                  ],
                ),
                Icon(Icons.trending_up, color: Colors.blue.shade800, size: 32),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text("Evolução do Faturamento", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          SizedBox(
            height: 120, // Altura ajustada para dar espaço à lista detalhada
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (group) => Colors.blueGrey.shade900,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          'Acumulado:\nR\$ ${spot.y.toStringAsFixed(2).replaceAll('.', ',')}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: vendasSpots,
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.2)),
                  ),
                ],
                titlesData: const FlTitlesData(
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text("Detalhamento das Vendas", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const Divider(),
          historicoDetalhado.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: const Text("Nenhuma venda registrada neste período.", style: TextStyle(color: Colors.blueGrey)),
                )
              : ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: historicoDetalhado,
                ),
          if (_analiseIA != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => TelaChatIA(diagnosticoInicial: _analiseIA!)));
              },
              icon: const Icon(Icons.chat),
              label: const Text("Aprofundar Análise no Chat"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAbaConsultorIA() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.auto_awesome, color: Colors.teal, size: 28),
                    SizedBox(width: 8),
                    Text("Consultor IA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    "Acesso Ilimitado (Powered by Gemini)",
                    style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Text("Clique em 'Gerar Relatório de Mercado' para obter previsões de vendas baseadas em datas, alertas de inflação e metas para cobrir seus custos fixos.",
                    style: TextStyle(color: Colors.blueGrey.shade700)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade200)),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(child: Text("Dica de Letramento: Após gerar o relatório, clique em 'Aprofundar no Chat' e pergunte à IA: 'Se eu vender 50 produtos a mais, quanto sobra pro meu bolso?'", style: TextStyle(fontSize: 12, color: Colors.amber.shade900))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isAnalyzing ? null : _gerarAnaliseInteligente,
            icon: _isAnalyzing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.auto_awesome, color: Colors.white),
            label: Text(_isAnalyzing ? "Analisando previsões..." : "Gerar Relatório de Mercado", style: const TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _analiseIA == null
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: MarkdownBody(data: _analiseIA!),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Dashboard & IA"),
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.analytics), text: "Curva ABC"),
              Tab(icon: Icon(Icons.show_chart), text: "Fluxo Caixa"),
              Tab(icon: Icon(Icons.auto_awesome), text: "Consultor IA"),
            ],
          ),
        ),
        drawer: const AppDrawer(),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text("Debug: Estoque (${estoque.length}) | Vendas (${historicoVendas.length})", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildAbaCurvaABC(),
                        _buildAbaFluxoCaixa(),
                        _buildAbaConsultorIA(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}