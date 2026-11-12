import 'package:app_cic/data/repository_demo.dart';
import 'package:app_cic/core/theme.dart';
import 'package:app_cic/screens/feedback_campo_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo extends DemoRepository {
  Map<String, dynamic>? respostasSalvas;
  bool falhar = true;
  bool enviado = false;

  @override
  Future<bool> enviouFeedbackNestaSemana() async => enviado;

  @override
  Future<void> salvarFeedbackCampo({
    int? nota,
    required List<String> aspectos,
    required String comentario,
    bool? recomendaria,
    String interesseSite = 'nao_agora',
    Map<String, dynamic>? respostas,
  }) async {
    if (falhar) throw Exception('Falha de conexão');
    respostasSalvas = respostas;
    enviado = true;
  }
}

void main() {
  testWidgets('envia as 10 respostas e preserva os campos após falha', (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(MaterialApp(theme: ThemeData(extensions: [CicPalette.escuro]), home: Scaffold(
      body: FeedbackCampoCard(repo: repo),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Responder formulário'));
    await tester.pumpAndSettle();

    Future<void> tocar(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tocar(find.text('Enviar feedback'));
    expect(find.text('Responda às 10 perguntas antes de enviar.'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tocar(find.byType(ChoiceChip).at(i * 5 + 4));
    }
    await tocar(find.text('Ver o estoque de forma clara'));
    await tocar(find.text('Sim, bastante'));
    for (var i = 0; i < 3; i++) {
      final campo = find.byType(TextField).at(i);
      await tester.ensureVisible(campo);
      await tester.enterText(campo, ['Nada confuso', 'Melhorar o menu', 'Muito útil'][i]);
    }
    // A nota zero é uma resposta válida na escala de recomendação.
    await tocar(find.byType(ChoiceChip).at(29));
    await tocar(find.text('Enviar feedback'));
    expect(find.text('Não foi possível enviar. Sua resposta foi mantida; tente novamente.'), findsOneWidget);
    expect(find.text('Melhorar o menu'), findsOneWidget);
    repo.falhar = false;
    await tocar(find.text('Enviar feedback'));
    expect(find.byType(FormularioCampo), findsNothing);
    expect(repo.respostasSalvas, containsPair('entrada', 5));
    expect(repo.respostasSalvas, containsPair('venda_pdv', 5));
    expect(repo.respostasSalvas, containsPair('favoritos', ['Ver o estoque de forma clara']));
    expect(repo.respostasSalvas, containsPair('ajuda_ia', 'Sim, bastante'));
    expect(repo.respostasSalvas, containsPair('dificuldades', 'Nada confuso'));
    expect(repo.respostasSalvas, containsPair('melhorias', 'Melhorar o menu'));
    expect(repo.respostasSalvas, containsPair('recomendacao', 0));
    expect(repo.respostasSalvas, containsPair('motivo_recomendacao', 'Muito útil'));
    expect(find.text('Enviar novo feedback'), findsOneWidget);
    await tocar(find.text('Enviar novo feedback'));
    expect(find.byType(FormularioCampo), findsOneWidget);
    expect(find.text('Melhorar o menu'), findsNothing);
    expect(tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .every((chip) => !chip.selected), isTrue);
  });
}
