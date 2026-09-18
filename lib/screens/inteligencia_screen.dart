import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ia_service.dart';
import '../theme/app_colors.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// InteligenciaScreen — Consultor IA Gemini v2.0
///
/// Interface de chat customizada para paridade com o Design System.
/// ═══════════════════════════════════════════════════════════════════════
class InteligenciaScreen extends StatefulWidget {
  final String diagnosticoInicial;
  final bool isEmbedded;

  const InteligenciaScreen({
    super.key,
    this.diagnosticoInicial = '',
    this.isEmbedded = false,
  });

  @override
  State<InteligenciaScreen> createState() => _InteligenciaScreenState();
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime createdAt;

  ChatMessage({required this.text, required this.isUser, required this.createdAt});

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'],
        isUser: json['isUser'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      );
}

class _InteligenciaScreenState extends State<InteligenciaScreen> {
  List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  Future<void> _carregarHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    final String? messagesJson = prefs.getString('chat_history_ia_v2');

    if (messagesJson != null) {
      final List<dynamic> decodedList = jsonDecode(messagesJson);
      setState(() {
        _messages = decodedList.map((e) => ChatMessage.fromJson(e)).toList();
      });
    }

    if (_messages.isEmpty || (_messages.isNotEmpty && _messages.first.text != widget.diagnosticoInicial && widget.diagnosticoInicial.isNotEmpty)) {
      _adicionarMensagem(ChatMessage(
        text: widget.diagnosticoInicial,
        isUser: false,
        createdAt: DateTime.now(),
      ));
    }
  }

  Future<void> _salvarHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_history_ia_v2', jsonEncode(_messages.map((m) => m.toJson()).toList()));
  }

  void _adicionarMensagem(ChatMessage message) {
    setState(() {
      _messages.insert(0, message);
    });
    _salvarHistorico();
  }

  void _handleSendPressed() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    
    final userMsg = ChatMessage(text: text, isUser: true, createdAt: DateTime.now());
    _adicionarMensagem(userMsg);

    setState(() => _isTyping = true);

    String historico = _messages.reversed.map((m) => '${m.isUser ? "Usuário" : "IA"}: ${m.text}').join("\n");
    
    try {
      String resposta = await IaService.continuarConversa(historico, text);
      setState(() => _isTyping = false);
      _adicionarMensagem(ChatMessage(text: resposta, isUser: false, createdAt: DateTime.now()));
    } catch (e) {
      setState(() => _isTyping = false);
      _adicionarMensagem(ChatMessage(
        text: "Desculpe, ocorreu um erro ao contatar o Gemini: $e",
        isUser: false,
        createdAt: DateTime.now(),
      ));
    }
  }

  void _limparChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_history_ia_v2');
    setState(() {
      _messages.clear();
    });
    if (widget.diagnosticoInicial.isNotEmpty) {
      _adicionarMensagem(ChatMessage(text: widget.diagnosticoInicial, isUser: false, createdAt: DateTime.now()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = AppColors.goldForBrightness(Theme.of(context).brightness);
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: widget.isEmbedded ? null : AppBar(
        title: const Text('Consultor IA Gemini'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Limpar Chat',
            onPressed: _limparChat,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == 0) {
                  return _buildTypingIndicator(isDark, gold);
                }
                final msgIndex = _isTyping ? index - 1 : index;
                final msg = _messages[msgIndex];
                return _buildMessageBubble(msg, isDark, gold);
              },
            ),
          ),
          _buildInputArea(isDark, gold),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark, Color gold) {
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: msg.isUser ? gold.withValues(alpha: 0.15) : cardBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 0),
            bottomRight: Radius.circular(msg.isUser ? 0 : 16),
          ),
          border: Border.all(
            color: msg.isUser ? gold.withValues(alpha: 0.3) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: textPrimary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark, Color gold) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: gold),
            ),
            const SizedBox(width: 8),
            Text("IA digitando...", style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark, Color gold) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Pergunte ao Gemini...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _handleSendPressed(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 24,
            backgroundColor: gold,
            child: IconButton(
              icon: const Icon(Icons.send, color: AppColors.darkBackground),
              onPressed: _handleSendPressed,
            ),
          )
        ],
      ),
    );
  }
}
