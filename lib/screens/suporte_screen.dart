import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';

/// Ajuda voltada ao lojista. Diagnósticos de banco, códigos internos e nomes
/// de provedores ficam fora da experiência do cliente.
class SuporteScreen extends StatelessWidget {
  const SuporteScreen({super.key, required this.estado});
  final AppState estado;

  Future<void> _email(BuildContext context) async {
    final uri = Uri(scheme: 'mailto', path: Config.supportEmail, queryParameters: {'subject': 'Ajuda com o APP-CIC'});
    if (!await launchUrl(uri)) {
      await Clipboard.setData(ClipboardData(text: Config.supportEmail));
      if (context.mounted) aviso(context, 'E-mail copiado: ${Config.supportEmail}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final nome = estado.usuario?.nome ?? 'lojista';
    return CicPagina(children: [
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CicCard(
              padding: const EdgeInsets.all(22),
              gradiente: LinearGradient(colors: c.isLight ? const [Color(0xFFFEF9EE), Colors.white] : const [Color(0xFF171511), Color(0xFF121212)]),
              borda: c.gold.withValues(alpha: 0.35),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CicIconeCaixa(LucideIcons.lifeBuoy, tom: BadgeTom.ouro, tamanho: 48),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Ajuda e suporte', style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Olá, $nome. Encontre orientações rápidas ou fale com a equipe do APP-CIC.', style: TextStyle(color: c.textMuted, fontSize: 12, height: 1.45)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    CicBotao('Enviar e-mail', icone: LucideIcons.mail, compacto: true, onPressed: () => _email(context)),
                    CicBotao('Copiar e-mail', icone: LucideIcons.copy, secundario: true, compacto: true, onPressed: () async { await Clipboard.setData(ClipboardData(text: Config.supportEmail)); if (context.mounted) aviso(context, 'E-mail copiado.'); }),
                  ]),
                ])),
              ]),
            ),
            const SizedBox(height: 16),
            CicCard(
              padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('O que você pode fazer no app', style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                CicGrid(minLargura: 240, espaco: 10, maxColunas: 2, children: [
                  _sistema(c, LucideIcons.barcode, 'Leitor de códigos', 'Leia o código, encontre os dados do produto e cadastre estoque, lote e validade.'),
                  _sistema(c, LucideIcons.boxes, 'Estoque e validade', 'Acompanhe saldo, lote, vencimento, custo e alertas de reposição.'),
                  _sistema(c, LucideIcons.shoppingCart, 'Vendas e caixa', 'Registre vendas, formas de pagamento e histórico sem planilha.'),
                  _sistema(c, LucideIcons.chartPie, 'Inteligência de negócio', 'Veja auditoria, previsão de giro, análise de mercado e sugestão de preço.'),
                  _sistema(c, LucideIcons.fileSpreadsheet, 'Notas e entradas', 'Importe notas quando disponíveis e evite lançar a mesma entrada duas vezes.'),
                  _sistema(c, LucideIcons.refreshCw, 'Logística reversa', 'Registre devoluções, avarias e envios ao fornecedor mantendo o histórico.'),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            CicCard(
              padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Respostas rápidas', style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _faq(c, 'Como começo?', 'Abra Leitor de códigos, leia um produto e informe quantidade, custo e preço. Depois use o PDV para registrar as vendas.'),
                _faq(c, 'O app altera meu preço sozinho?', 'Não. A análise compara ofertas públicas e mostra uma sugestão. Você decide se quer atualizar o cadastro.'),
                _faq(c, 'Posso pedir um site?', 'Sim. Site, criação de páginas e automação de mensagens são serviços separados. Fale com a equipe pelo e-mail acima.'),
                _faq(c, 'Como envio uma sugestão?', 'Use o feedback semanal em Inteligência IA. Você pode marcar opções e escrever livremente.'),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Atendimento: ${Config.supportEmail} • Responderemos no próximo dia útil.', textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, fontSize: 11)),
          ]),
        ),
      ),
    ]);
  }

  Widget _sistema(CicPalette c, IconData icon, String titulo, String texto) => CicSub(
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: c.gold),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: TextStyle(color: c.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(texto, style: TextStyle(color: c.textMuted, fontSize: 11.5, height: 1.35)),
      ])),
    ]),
  );

  Widget _faq(CicPalette c, String pergunta, String resposta) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(pergunta, style: TextStyle(color: c.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
      iconColor: c.gold,
      collapsedIconColor: c.textMuted,
      children: [Align(alignment: Alignment.centerLeft, child: Text(resposta, style: TextStyle(color: c.textMuted, fontSize: 12, height: 1.4)))],
    ),
  );
}
