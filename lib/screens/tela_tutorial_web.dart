import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../widgets/app_drawer.dart';

/// ═══════════════════════════════════════════════════════════════
/// Tela de Tutorial & Acesso Rápido ao Portal Web Looker Studio
/// ═══════════════════════════════════════════════════════════════
/// Orienta o lojista sobre como acessar o painel SaaS Web (Vercel)
/// pelo computador ou tablet, ensinando passo a passo como lucrar
/// mais utilizando gráficos, predições de IA e curvas ABC.
/// ═══════════════════════════════════════════════════════════════
class TelaTutorialWeb extends StatelessWidget {
  const TelaTutorialWeb({super.key});

  static const String urlPortalWeb = 'https://web-eight-blond-46.vercel.app';

  Future<void> _abrirPortalWeb(BuildContext context) async {
    final url = Uri.parse(urlPortalWeb);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (context.mounted) {
        Clipboard.setData(const ClipboardData(text: urlPortalWeb));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copiado para a área de transferência! Cole no seu navegador.'),
            backgroundColor: Color(0xFF00C853),
          ),
        );
      }
    }
  }

  void _copiarLink(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: urlPortalWeb));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Link do Portal Web copiado! Cole no Chrome ou Safari do seu computador ou tablet.'),
        backgroundColor: Color(0xFF00C853),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Gráficos do Negócio', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Principal Destaque (Acesso ao Portal)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.language, color: Colors.white, size: 36),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Acesse seu Dashboard Web de Qualquer Lugar',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'O portal Web é a versão ampliada do seu app, ideal para telas grandes (Computador, Tablet ou Notebook). Ele se conecta na mesma nuvem blindada do app em tempo real.',
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _abrirPortalWeb(context),
                          icon: const Icon(Icons.open_in_browser, color: Color(0xFF0D47A1)),
                          label: const Text('Abrir Portal Web Agora', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _copiarLink(context),
                        icon: const Icon(Icons.copy, color: Colors.white),
                        tooltip: 'Copiar Link',
                        style: IconButton.styleFrom(backgroundColor: Colors.white24, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              '📈 Como Usufruir e Lucrar Mais com o Portal Web',
              style: TextStyle(color: Color(0xFFD4A843), fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildPassoLucrativo(
              '1. Foco nos Produtos Alto Lucro (Curva ABC)',
              'No gráfico de barras do Portal Web, identifique quais são os produtos da Classe A (que geram 80% do seu lucro). Garanta que eles nunca faltem no estoque, pois são o coração financeiro do comércio.',
              Icons.bar_chart,
              Colors.greenAccent,
            ),
            _buildPassoLucrativo(
              '2. Elimine Estoque Parado (Dinheiro Congelado)',
              'A IA sinaliza itens com baixo giro e vencimento próximo. Use a aba "Consultor IA" para gerar promoções automáticas casadas ("Compre Café e leve Leite com 30%"), transformando estoque parado em caixa imediato.',
              Icons.trending_up,
              Colors.orangeAccent,
            ),
            _buildPassoLucrativo(
              '3. Controle de Rentabilidade e Custos',
              'Use o filtro de meses para comparar seu Faturamento Bruto contra os Custos Operacionais (salários, luz, fornecedores). O segredo de lucrar não é apenas vender mais, mas manter a margem líquida acima de 25%.',
              Icons.account_balance_wallet,
              Colors.blueAccent,
            ),
            _buildPassoLucrativo(
              '4. Predições Automáticas (Zero Desperdício)',
              'O sistema avisa com 30 dias de antecedência o que vai vencer ou acabar. Reponha apenas o necessário para o mês, economizando capital de giro.',
              Icons.auto_awesome,
              Color(0xFFD4A843),
            ),

            const SizedBox(height: 24),
            // Guia Rápido de Login
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline, color: Color(0xFFD4A843), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Como fazer Login no Computador / Tablet:',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Abra o navegador (Google Chrome ou Edge) no PC.\n'
                    '2. Digite o endereço: web-eight-blond-46.vercel.app\n'
                    '3. Digite o mesmo E-mail e Senha que você usa aqui no App.\n'
                    '4. Pronto! Seus dados aparecerão sincronizados instantaneamente.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPassoLucrativo(String titulo, String descricao, IconData icone, Color corIcone) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: corIcone.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icone, color: corIcone, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(descricao, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
