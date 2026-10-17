import 'package:flutter/material.dart';

import '../core/semana_campo.dart';
import '../data/repository.dart';
import '../ui/widgets.dart';

class FeedbackCampoCard extends StatefulWidget {
  const FeedbackCampoCard({super.key, required this.repo});
  final CicRepository repo;

  @override
  State<FeedbackCampoCard> createState() => _FeedbackCampoCardState();
}

class _FeedbackCampoCardState extends State<FeedbackCampoCard> with WidgetsBindingObserver {
  late Future<bool> _resposta;
  DateTime? _semana;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _consultar();
  }

  void _consultar() {
    _semana = inicioSemanaCampo(DateTime.now());
    _resposta = widget.repo.enviouFeedbackNestaSemana();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(_consultar);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _abrir() async {
    final enviado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FormularioCampo(repo: widget.repo),
    );
    if (mounted && enviado == true) setState(_consultar);
  }

  @override
  Widget build(BuildContext context) {
    if (_semana != inicioSemanaCampo(DateTime.now())) _consultar();
    return FutureBuilder<bool>(
      future: _resposta,
      builder: (context, resposta) {
        if (resposta.connectionState != ConnectionState.done || resposta.data == true) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: CicCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Seu feedback desta semana', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(resposta.hasError
                ? 'Não foi possível verificar sua resposta. Tente novamente.'
                : 'Conte como foi usar o app. O formulário do teste de campo leva cerca de 2 minutos.'),
            const SizedBox(height: 12),
            CicBotao(resposta.hasError ? 'Tentar novamente' : 'Responder formulário',
                onPressed: resposta.hasError ? () => setState(_consultar) : _abrir),
          ])),
        );
      },
    );
  }
}

class _FormularioCampo extends StatefulWidget {
  const _FormularioCampo({required this.repo});
  final CicRepository repo;

  @override
  State<_FormularioCampo> createState() => _FormularioCampoState();
}

class _FormularioCampoState extends State<_FormularioCampo> {
  final _comentario = TextEditingController();
  final _aspectos = <String>{};
  int _nota = 0;
  bool _recomendaria = false;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando || _nota == 0) return;
    setState(() { _enviando = true; _erro = null; });
    try {
      await widget.repo.salvarFeedbackCampo(nota: _nota, aspectos: _aspectos.toList(),
          comentario: _comentario.text, recomendaria: _recomendaria);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() {
        _enviando = false;
        _erro = 'Não foi possível enviar. Sua resposta foi mantida; tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_enviando,
    child: AlertDialog(
      title: const Text('Feedback semanal do teste de campo'),
      content: SingleChildScrollView(child: AbsorbPointer(
        absorbing: _enviando,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Como foi usar o app nesta semana? (1 a 5)'),
          Wrap(spacing: 6, children: [for (var i = 1; i <= 5; i++)
            ChoiceChip(label: Text('$i'), selected: _nota == i, onSelected: (_) => setState(() => _nota = i))]),
          const SizedBox(height: 12),
          const Text('O que mais ajudou?'),
          for (final item in const ['Estoque', 'PDV e vendas', 'Alertas', 'Auditoria e IA', 'Preço de mercado'])
            CheckboxListTile(contentPadding: EdgeInsets.zero, title: Text(item), value: _aspectos.contains(item),
                onChanged: (v) => setState(() => v == true ? _aspectos.add(item) : _aspectos.remove(item))),
          TextField(controller: _comentario, maxLines: 3, maxLength: 4000,
              decoration: const InputDecoration(labelText: 'O que devemos melhorar?')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Você recomendaria o app?'),
              value: _recomendaria, onChanged: (v) => setState(() => _recomendaria = v)),
          if (_erro != null) Text(_erro!),
        ]),
      )),
      actions: [
        TextButton(onPressed: _enviando ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: _enviando || _nota == 0 ? null : _enviar,
            child: Text(_enviando ? 'Enviando…' : 'Enviar feedback')),
      ],
    ),
  );
}
