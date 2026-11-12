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

class _FeedbackCampoCardState extends State<FeedbackCampoCard>
    with WidgetsBindingObserver {
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
      builder: (_) => FormularioCampo(repo: widget.repo),
    );
    if (mounted && enviado == true) setState(_consultar);
  }

  @override
  Widget build(BuildContext context) {
    if (_semana != inicioSemanaCampo(DateTime.now())) _consultar();
    return FutureBuilder<bool>(
      future: _resposta,
      builder: (context, resposta) {
        if (resposta.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: CicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sua experiência com o app',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  resposta.hasError
                      ? 'Não foi possível verificar sua resposta. Tente novamente.'
                      : resposta.data == true
                      ? 'Obrigado pelo feedback! Você pode enviar uma nova resposta quando quiser.'
                      : 'Conte como foi usar o app. O formulário do teste de campo leva menos de 3 minutos.',
                ),
                const SizedBox(height: 12),
                CicBotao(
                  resposta.hasError
                      ? 'Tentar novamente'
                      : resposta.data == true
                      ? 'Enviar novo feedback'
                      : 'Responder formulário',
                  onPressed: resposta.hasError
                      ? () => setState(_consultar)
                      : _abrir,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FormularioCampo extends StatefulWidget {
  const FormularioCampo({super.key, required this.repo});
  final CicRepository repo;

  @override
  State<FormularioCampo> createState() => _FormularioCampoState();
}

class _FormularioCampoState extends State<FormularioCampo> {
  static const _perguntas = [
    'Como você avalia o processo para entrar no sistema (login ou modo convidado)?',
    'Você conseguiu achar as funções no menu (estoque, caixa, custos, alertas etc.)?',
    'Como foi cadastrar um produto (usando o leitor ou digitando o código)?',
    'Como foi consultar o estoque e entender os números?',
    'O que achou ao registrar uma venda no Frente de Caixa (PDV)?',
  ];
  static const _opcoes = [
    'Cadastrar produtos pelo código',
    'Ver o estoque de forma clara',
    'Registrar vendas no PDV',
    'Acompanhar custos e meta diária',
    'Receber alertas',
    'Usar o Consultor de IA',
    'Outro',
  ];
  final _notas = List<int?>.filled(5, null);
  final _aspectos = <String>{};
  final _outro = TextEditingController();
  final _dificuldades = TextEditingController();
  final _melhorias = TextEditingController();
  final _motivo = TextEditingController();
  String? _ajudaIa;
  int? _recomendacao;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    for (final controller in [_outro, _dificuldades, _melhorias, _motivo]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    if (_notas.contains(null) ||
        _aspectos.isEmpty ||
        _ajudaIa == null ||
        _recomendacao == null ||
        _dificuldades.text.trim().isEmpty ||
        _melhorias.text.trim().isEmpty ||
        _motivo.text.trim().isEmpty ||
        (_aspectos.contains('Outro') && _outro.text.trim().isEmpty)) {
      setState(() => _erro = 'Responda às 10 perguntas antes de enviar.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final respostas = <String, dynamic>{
        'versao': 2,
        'entrada': _notas[0],
        'menu': _notas[1],
        'cadastro_produto': _notas[2],
        'consulta_estoque': _notas[3],
        'venda_pdv': _notas[4],
        'favoritos': _aspectos.toList(),
        'outro_favorito': _aspectos.contains('Outro') ? _outro.text.trim() : '',
        'ajuda_ia': _ajudaIa,
        'dificuldades': _dificuldades.text.trim(),
        'melhorias': _melhorias.text.trim(),
        'recomendacao': _recomendacao,
        'motivo_recomendacao': _motivo.text.trim(),
      };
      await widget.repo.salvarFeedbackCampo(
        aspectos: _aspectos.toList(),
        comentario: _melhorias.text.trim(),
        respostas: respostas,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _erro =
              'Não foi possível enviar. Sua resposta foi mantida; tente novamente.';
        });
      }
    }
  }

  Widget _titulo(String texto) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_enviando,
    child: AlertDialog(
      title: const Text('Como foi sua experiência usando o APP-CIC?'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: AbsorbPointer(
            absorbing: _enviando,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Responda de forma sincera, não precisa saber de gestão. Sua opinião ajuda a melhorar nosso aplicativo. Leva menos de 3 minutos.',
                ),
                for (var q = 0; q < _perguntas.length; q++) ...[
                  _titulo('${q + 1}. ${_perguntas[q]}'),
                  const Text(
                    'Como você avalia o nível de dificuldade desta etapa?\n1 = muito difícil · 5 = muito fácil',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var nota = 1; nota <= 5; nota++)
                        ChoiceChip(
                          label: Text('$nota'),
                          selected: _notas[q] == nota,
                          onSelected: (_) => setState(() => _notas[q] = nota),
                        ),
                    ],
                  ),
                ],
                _titulo('6. O que você mais gostou no APP-CIC?'),
                const Text('Pode marcar mais de uma opção.'),
                for (final item in _opcoes)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item),
                    value: _aspectos.contains(item),
                    onChanged: (v) => setState(
                      () => v == true
                          ? _aspectos.add(item)
                          : _aspectos.remove(item),
                    ),
                  ),
                if (_aspectos.contains('Outro'))
                  TextField(
                    controller: _outro,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'O que mais você gostou?',
                    ),
                  ),
                _titulo('7. A IA te ajudou a ter mais controle do negócio?'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final opcao in const [
                      'Sim, bastante',
                      'Um pouco',
                      'Ainda não',
                      'Não sei',
                    ])
                      ChoiceChip(
                        label: Text(opcao),
                        selected: _ajudaIa == opcao,
                        onSelected: (_) => setState(() => _ajudaIa = opcao),
                      ),
                  ],
                ),
                _titulo('8. O que foi mais confuso ou difícil de usar?'),
                TextField(
                  controller: _dificuldades,
                  maxLines: 3,
                  maxLength: 4000,
                  decoration: const InputDecoration(labelText: 'Sua resposta'),
                ),
                _titulo(
                  '9. O que você mudaria ou melhoraria para ficar mais fácil no dia a dia?',
                ),
                TextField(
                  controller: _melhorias,
                  maxLines: 3,
                  maxLength: 4000,
                  decoration: const InputDecoration(labelText: 'Sua resposta'),
                ),
                _titulo(
                  '10. Em uma nota de 0 a 10, quanto você recomendaria o APP-CIC para outro lojista? (E por que deu essa nota?)',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var nota = 0; nota <= 10; nota++)
                      ChoiceChip(
                        label: Text('$nota'),
                        selected: _recomendacao == nota,
                        onSelected: (_) => setState(() => _recomendacao = nota),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _motivo,
                  maxLines: 3,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Por que deu essa nota?',
                  ),
                ),
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _erro!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _enviando ? null : _enviar,
          child: Text(_enviando ? 'Enviando…' : 'Enviar feedback'),
        ),
      ],
    ),
  );
}
