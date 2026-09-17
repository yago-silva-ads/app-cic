import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../web/tela_dashboard_web.dart';
import 'tela_estoque.dart';
import 'leitor_screen.dart';
import 'tela_chat_ia.dart';
import 'tela_vendedor.dart';

class TelaUnicaDashboard extends StatelessWidget {
  final Function(int)? onNavigate;
  const TelaUnicaDashboard({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Resumo (KPIs e Gráficos)
          const TelaDashboardWeb(isEmbedded: true),
          
          // 2. Botões de Ação Principais
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 70,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner, size: 28),
                    label: const Text(
                      'Escanear Produto',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (onNavigate != null) {
                        onNavigate!(1); // 1 = Leitor
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const LeitorScreen(isEmbedded: false)));
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Análise IA', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade50,
                            foregroundColor: Colors.purple.shade700,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            if (onNavigate != null) {
                              onNavigate!(3); // 3 = Chat IA
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TelaChatIA(
                                    diagnosticoInicial: 'Olá! Sou seu consultor de negócios IA. Posso te ajudar a analisar suas vendas, sugerir onde cortar gastos ou ideias de como aumentar o lucro do mês.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.attach_money),
                          label: const Text('Custos', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade50,
                            foregroundColor: Colors.green.shade700,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            if (onNavigate != null) {
                              onNavigate!(4); // 4 = Custos
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const TelaVendedor()),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
            child: Text(
              'Estoque Atual',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),

          // 3. Lista de Estoque Integrada
          const TelaEstoque(isEmbedded: true),
        ],
      ),
    );
  }
}
