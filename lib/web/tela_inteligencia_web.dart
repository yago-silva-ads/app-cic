import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/produto.dart';
import '../models/alerta.dart';
import '../models/custo_operacional.dart';
import '../services/ia_service.dart';
import '../services/supabase_helper.dart';

/// ═══════════════════════════════════════════════════════════════
/// Tela de Inteligência IA (Web) — Relatórios Preditivos
/// ═══════════════════════════════════════════════════════════════
/// Integra o IaService existente para gerar relatórios preditivos
/// diretamente na tela do computador. Inclui:
/// - Geração de relatório em tempo real
/// - Chat interativo com IA
/// - Histórico de relatórios salvos
/// ═══════════════════════════════════════════════════════════════

const Color _bgDark = Color(0xFF0D0D0D);
const Color _cardDark = Color(0xFF1A1A1A);
const Color _cardBorder = Color(0xFF2A2A2A);
const Color _accentGold = Color(0xFFD4A843);
const Color _accentTeal = Color(0xFF00B8AA);
const Color _textPrimary = Color(0xFFF5F5F5);
const Color _textSecondary = Color(0xFF9E9E9E);

class TelaInteligenciaWeb extends StatefulWidget {
  final List<Produto> estoque;
  final List<Map<String, dynamic>> historicoVendas;
  final List<CustoOperacional> custos;
  final List<Alerta> alertas;

  const TelaInteligenciaWeb({
    super.key,
    required this.estoque,
    required this.historicoVendas,
    required this.custos,
    required this.alertas,
  });

  @override
  State<TelaInteligenciaWeb> createState() => _TelaInteligenciaWebState();
}

class _TelaInteligenciaWebState extends State<TelaInteligenciaWeb> {
  bool _isAnalyzing = false;
  String? _analiseIA;
  List<Map<String, dynamic>> _relatoriosHistorico = [];
  bool _isLoadingHistorico = true;

  // Chat IA
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _chatMessages = [];
  bool _isChatLoading = false;
  String _historicoChat = '';

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _carregarHistorico() async {
    final dados = await SupabaseHelper.getRelatoriosIA(limite: 5);
    if (!mounted) return;
    setState(() {
      _relatoriosHistorico = dados;
      _isLoadingHistorico = false;
    });
  }

  Future<void> _gerarRelatorio() async {
    setState(() {
      _isAnalyzing = true;
      _analiseIA = null;
    });

    final resposta = await IaService.analisarEstoque(
      widget.estoque,
      widget.historicoVendas,
      widget.custos,
      alertasAtivos: widget.alertas,
    );

    // Salva no banco para histórico
    try {
      await SupabaseHelper.salvarRelatorioIA(
        conteudo: resposta,
        tipo: 'SOB_DEMANDA',
      );
      _carregarHistorico(); // Atualiza histórico
    } catch (e) {
      print("Erro ao salvar relatório: $e");
    }

    if (!mounted) return;
    setState(() {
      _analiseIA = resposta;
      _isAnalyzing = false;
    });
  }

  Future<void> _enviarMensagemChat() async {
    final msg = _chatController.text.trim();
    if (msg.isEmpty) return;

    setState(() {
      _chatMessages.add({'role': 'user', 'text': msg});
      _isChatLoading = true;
    });
    _chatController.clear();

    final resposta = await IaService.continuarConversa(_historicoChat, msg);
    _historicoChat += '\nUsuário: $msg\nConsultor IA: $resposta';

    if (!mounted) return;
    setState(() {
      _chatMessages.add({'role': 'ia', 'text': resposta});
      _isChatLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === SEÇÃO 1: Gerar Relatório ===
          _buildSecaoRelatorio(),
          const SizedBox(height: 24),

          // === SEÇÃO 2: Chat IA ===
          _buildSecaoChat(),
          const SizedBox(height: 24),

          // === SEÇÃO 3: Histórico ===
          _buildSecaoHistorico(),
        ],
      ),
    );
  }

  // ==================== RELATÓRIO IA ====================
  Widget _buildSecaoRelatorio() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: _accentGold, size: 22),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text('Relatório Preditivo — IA Gemini',
                        style: GoogleFonts.outfit(
                          color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w600,
                        )),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _gerarRelatorio,
                icon: _isAnalyzing
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.rocket_launch, size: 16),
                label: Text(_isAnalyzing ? 'Analisando...' : 'Gerar Relatório'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentGold,
                  foregroundColor: _bgDark,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Análise completa: Curva ABC, Visão Preditiva, Meta de Vendas, Precificação e Alertas Ativos.',
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
          if (_analiseIA != null) ...[
            const SizedBox(height: 16),
            const Divider(color: _cardBorder),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 500),
              child: Markdown(
                data: _analiseIA!,
                shrinkWrap: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: _textPrimary, fontSize: 13, height: 1.6),
                  h1: GoogleFonts.outfit(color: _accentGold, fontSize: 20, fontWeight: FontWeight.bold),
                  h2: GoogleFonts.outfit(color: _accentGold, fontSize: 16, fontWeight: FontWeight.w600),
                  h3: GoogleFonts.outfit(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                  strong: const TextStyle(color: _accentGold, fontWeight: FontWeight.bold),
                  listBullet: const TextStyle(color: _accentTeal, fontSize: 13),
                  blockquote: const TextStyle(color: _textSecondary, fontStyle: FontStyle.italic),
                  code: TextStyle(
                    color: _accentTeal,
                    backgroundColor: _cardBorder,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== CHAT IA ====================
  Widget _buildSecaoChat() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline, color: _accentTeal, size: 20),
              const SizedBox(width: 10),
              Text('Consultor IA — Chat Interativo',
                  style: GoogleFonts.outfit(
                    color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
                  )),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Pergunte em português: "Quais produtos devo comprar?" ou "Como reduzir custos?"',
            style: TextStyle(color: _textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 16),

          // Mensagens do chat
          if (_chatMessages.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView.builder(
                itemCount: _chatMessages.length,
                itemBuilder: (ctx, i) {
                  final msg = _chatMessages[i];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.5,
                      ),
                      decoration: BoxDecoration(
                        color: isUser
                            ? _accentGold.withValues(alpha: 0.15)
                            : _cardBorder,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isUser
                              ? _accentGold.withValues(alpha: 0.3)
                              : _cardBorder,
                        ),
                      ),
                      child: isUser
                          ? Text(msg['text'] ?? '',
                              style: const TextStyle(color: _textPrimary, fontSize: 13))
                          : MarkdownBody(
                              data: msg['text'] ?? '',
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(color: _textPrimary, fontSize: 13),
                                strong: const TextStyle(color: _accentGold, fontWeight: FontWeight.bold),
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),

          if (_isChatLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _accentTeal)),
                  const SizedBox(width: 8),
                  Text('IA pensando...', style: TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              ),
            ),

          // Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: _textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Pergunte algo ao Consultor IA...',
                    hintStyle: TextStyle(color: _textSecondary.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: _bgDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _accentGold),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (_) => _enviarMensagemChat(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: _accentGold),
                onPressed: _isChatLoading ? null : _enviarMensagemChat,
                style: IconButton.styleFrom(
                  backgroundColor: _accentGold.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== HISTÓRICO DE RELATÓRIOS ====================
  Widget _buildSecaoHistorico() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: _textSecondary, size: 20),
              const SizedBox(width: 10),
              Text('Histórico de Relatórios',
                  style: GoogleFonts.outfit(
                    color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingHistorico)
            const Center(child: CircularProgressIndicator(color: _accentGold))
          else if (_relatoriosHistorico.isEmpty)
            Text('Nenhum relatório salvo ainda. Gere o primeiro acima!',
                style: TextStyle(color: _textSecondary, fontSize: 12))
          else
            ..._relatoriosHistorico.map((r) {
              final tipo = r['tipo'] ?? 'SOB_DEMANDA';
              final criadoEm = r['criado_em'] != null
                  ? DateTime.parse(r['criado_em'])
                  : DateTime.now();
              final conteudo = r['conteudo_markdown'] as String? ?? '';

              return ExpansionTile(
                leading: Icon(
                  tipo == 'DIARIO' ? Icons.schedule : Icons.description,
                  color: _accentGold, size: 18,
                ),
                title: Text(
                  tipo == 'DIARIO' ? '📅 Relatório Diário' : '📊 Relatório Sob Demanda',
                  style: const TextStyle(color: _textPrimary, fontSize: 13),
                ),
                subtitle: Text(
                  '${criadoEm.day.toString().padLeft(2, '0')}/${criadoEm.month.toString().padLeft(2, '0')}/${criadoEm.year} às ${criadoEm.hour}:${criadoEm.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: _textSecondary, fontSize: 10),
                ),
                collapsedIconColor: _textSecondary,
                iconColor: _accentGold,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: MarkdownBody(
                      data: conteudo,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: _textPrimary, fontSize: 12, height: 1.5),
                        strong: const TextStyle(color: _accentGold, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}
