import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import '../services/ia_service.dart';

class TelaChatIA extends StatefulWidget {
  final String diagnosticoInicial;
  const TelaChatIA({super.key, required this.diagnosticoInicial});

  @override
  State<TelaChatIA> createState() => _TelaChatIAState();
}

class _TelaChatIAState extends State<TelaChatIA> {
  List<types.Message> _messages = [];
  final _user = types.User(id: '82091008-a484-4a89-ae75-a22bf8d6f3ac');
  final _ia = types.User(id: 'gemini-ia');

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  Future<void> _carregarHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    final String? messagesJson = prefs.getString('chat_history_ia');

    if (messagesJson != null) {
      final List<dynamic> decodedList = jsonDecode(messagesJson);
      final loadedMessages = decodedList.map((e) => types.Message.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {
        _messages = loadedMessages;
      });
    }

    // Se o chat estiver vazio OU o último diagnóstico gerado na Dashboard for novo, nós o adicionamos!
    if (_messages.isEmpty || (_messages.first is types.TextMessage && (_messages.first as types.TextMessage).text != widget.diagnosticoInicial)) {
      _adicionarMensagem(types.TextMessage(author: _ia, createdAt: DateTime.now().millisecondsSinceEpoch, id: Uuid().v4(), text: widget.diagnosticoInicial));
    }
  }

  Future<void> _salvarHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_history_ia', jsonEncode(_messages.map((m) => m.toJson()).toList()));
  }

  void _adicionarMensagem(types.Message message) {
    setState(() => _messages.insert(0, message));
    _salvarHistorico();
  }

  void _handleSendPressed(types.PartialText message) async {
    final textMessage = types.TextMessage(author: _user, createdAt: DateTime.now().millisecondsSinceEpoch, id: Uuid().v4(), text: message.text);
    _adicionarMensagem(textMessage);

    String historico = _messages.reversed.whereType<types.TextMessage>().map((m) => m.text).join("\n");
    String resposta = await IaService.continuarConversa(historico, message.text);

    _adicionarMensagem(types.TextMessage(author: _ia, createdAt: DateTime.now().millisecondsSinceEpoch, id: Uuid().v4(), text: resposta));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Consultor IA"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: "Limpar Histórico",
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('chat_history_ia');
              setState(() {
                _messages.clear();
              });
              // Re-adiciona o diagnóstico da tela atual para não ficar uma tela em branco
              _adicionarMensagem(types.TextMessage(author: _ia, createdAt: DateTime.now().millisecondsSinceEpoch, id: Uuid().v4(), text: widget.diagnosticoInicial));
            },
          )
        ],
      ),
      body: Chat(messages: _messages, onSendPressed: _handleSendPressed, user: _user),
    );
  }
}