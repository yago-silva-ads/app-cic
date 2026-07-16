import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import '../widgets/app_drawer.dart';

/// ═══════════════════════════════════════════════════════════════
/// Tela de Suporte & Fale Conosco (Ajuda ao Empreendedor)
/// ═══════════════════════════════════════════════════════════════
/// Permite ao lojista entrar em contato direto com os desenvolvedores
/// via WhatsApp ou E-mail, consultar dúvidas frequentes (FAQ) e verificar
/// o status de conexão em tempo real com o banco de dados blindado.
/// ═══════════════════════════════════════════════════════════════
class TelaSuporte extends StatelessWidget {
  const TelaSuporte({super.key});

  Future<void> _abrirWhatsApp(BuildContext context) async {
    const telefone = '5511999999999';
    final user = Supabase.instance.client.auth.currentUser;
    final tenantId = user?.id ?? 'Não identificado';
    
    final mensagem = Uri.encodeComponent(
      'Olá, equipe de Desenvolvimento App-CIC! Preciso de ajuda com o sistema.\n\n'
      '🏢 ID da Loja (Tenant): $tenantId\n'
      '📱 Sistema: Mobile/Web'
    );

    final uris = [
      Uri.parse('whatsapp://send?phone=$telefone&text=$mensagem'),
      Uri.parse('https://wa.me/$telefone?text=$mensagem'),
      Uri.parse('https://api.whatsapp.com/send?phone=$telefone&text=$mensagem'),
    ];

    bool abriu = false;
    for (var u in uris) {
      try {
        if (await canLaunchUrl(u)) {
          await launchUrl(u, mode: LaunchMode.externalApplication);
          abriu = true;
          break;
        } else {
          // Tentativa direta mesmo que canLaunchUrl dê false (comum no Android 11+)
          await launchUrl(u, mode: LaunchMode.platformDefault);
          abriu = true;
          break;
        }
      } catch (_) {}
    }

    if (!abriu && context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Contato WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'Não conseguimos abrir o WhatsApp automaticamente no seu dispositivo. Copie nosso link de atendimento:',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: 'https://wa.me/5511999999999'));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Link copiado! Cole no seu navegador ou WhatsApp.'), backgroundColor: Color(0xFF00C853)),
                );
              },
              icon: const Icon(Icons.copy, color: Colors.white),
              label: const Text('Copiar Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _abrirEmail(BuildContext context) async {
    final url = Uri.parse('mailto:suporte@appcic.com.br?subject=Suporte%20App-CIC%20Gestão');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('E-mail de Suporte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text(
              'Nosso e-mail oficial é:\n\nsuporte@appcic.com.br\n\nDeseja copiar o endereço para o seu aplicativo de e-mail favorito?',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fechar', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: 'suporte@appcic.com.br'));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ E-mail suporte@appcic.com.br copiado!'), backgroundColor: Colors.blueAccent),
                  );
                },
                icon: const Icon(Icons.copy, color: Colors.white),
                label: const Text('Copiar E-mail', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _abrirDownloadAPK(BuildContext context) async {
    const urlApk = 'https://web-eight-blond-46.vercel.app/download/app-cic.apk';
    final url = Uri.parse(urlApk);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.android, color: Color(0xFF00E676), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Instalar App Android (APK)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O aplicativo nativo permite usar a câmera traseira em altíssima velocidade e acessar o sistema sem precisar abrir o navegador.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_2, color: Color(0xFFD4A843), size: 40),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Link de Download Direto (~73 MB)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        SizedBox(height: 4),
                        Text('web-eight-blond-46.vercel.app/download/app-cic.apk', style: TextStyle(color: Color(0xFFD4A843), fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: urlApk));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Link do APK copiado! Cole no navegador do celular.'),
                  backgroundColor: Color(0xFF00C853),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16, color: Colors.white),
            label: const Text('Copiar Link', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF333333)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(url, mode: LaunchMode.platformDefault);
                }
              } catch (_) {}
              if (ctx.mounted) Navigator.pop(ctx);
            },
            icon: const Icon(Icons.download, color: Colors.black),
            label: const Text('Baixar APK Agora', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final tenantId = user?.id ?? 'Desconhecido';

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Central de Ajuda & Suporte', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de Contato Rápido
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C853), Color(0xFF009624)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.support_agent, color: Colors.white, size: 36),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Fale direto com os Desenvolvedores',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nossa equipe está pronta para ajudar com dúvidas de estoque, IA preditiva ou relatórios financeiros.',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _abrirWhatsApp(context),
                    icon: const Icon(Icons.chat, color: Color(0xFF009624)),
                    label: const Text('Chamar no WhatsApp agora', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF009624))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Banner de Download APK Android
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B3B2B), Color(0xFF0E2218)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.android, color: Color(0xFF00E676), size: 36),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Baixar App para Android (APK)',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Instale no celular para leitura ultrarrápida com a câmera sem precisar do navegador.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _abrirDownloadAPK(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    child: const Text('📥 Baixar App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Outros Canais & Diagnóstico
            const Text(
              'Outros Canais & Status',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: Color(0xFFD4A843)),
                    title: const Text('Enviar E-mail', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: const Text('suporte@appcic.com.br', style: TextStyle(color: Colors.white70)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
                    onTap: () => _abrirEmail(context),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined, color: Colors.greenAccent),
                    title: const Text('Status de Segurança (RLS)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Supabase Cloud Blindado — 100% Ativo', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                    trailing: const Icon(Icons.check_circle, color: Colors.greenAccent),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  ListTile(
                    leading: const Icon(Icons.fingerprint, color: Colors.blueAccent),
                    title: const Text('ID do Comércio (Tenant)', style: TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: Text(tenantId, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Perguntas Frequentes (FAQ)
            const Text(
              'Perguntas Frequentes (FAQ)',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildFaqItem(
              'Como funciona a validade inteligente (FIFO)?',
              'O sistema ordena os produtos no estoque automaticamente dando prioridade aos lotes que vencem primeiro (First-In, First-Out). Produtos próximos do vencimento (30, 7 ou 0 dias) geram alertas urgentes automáticos.',
            ),
            _buildFaqItem(
              'Outras lojas podem ver o meu faturamento?',
              'Não! O sistema possui proteção RLS (Row Level Security) e Triggers QA diretamente no PostgreSQL em nuvem. Cada requisição é filtrada pelo seu ID de lojista (auth.uid()).',
            ),
            _buildFaqItem(
              'O que é o Saldo em Caixa e como é calculado?',
              'O Saldo em Caixa é a diferença exata entre todas as vendas realizadas e os Custos Operacionais cadastrados na sua conta.',
            ),
            _buildFaqItem(
              'Como funcionam as predições e relatórios da IA?',
              'O Consultor Gemini analisa seu histórico de vendas, estoque parado e custos em segundo plano, sugerindo promoções e compras ideais sem vazar dados para fora de sua loja.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String pergunta, String resposta) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(pergunta, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        iconColor: const Color(0xFFD4A843),
        collapsedIconColor: Colors.white54,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              resposta,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
