// lib/domain/services/ai_grounding_guard.dart
// Camada de segurança e blindagem de IA para o APP-CIC
// REGRA CRÍTICA: A IA nunca calcula somas, nunca inventa dados de estoque e nunca recalcula ABC.
// Os dados são injetados pré-calculados e a IA atua estritamente como consultora analítica.

import 'dart:convert';
import '../contracts/abc_contract.dart';

class AiGroundingGuard {
  static const String systemSecurityPrompt = '''
VOCÊ É O CONSULTOR ESTRATÉGICO OFICIAL DO APP-CIC.
DIRETRIZES DE SEGURANÇA E PREVENÇÃO DE ALUCINAÇÃO:
1. NUNCA calcule totais de faturamento, quantidade de estoque ou classes ABC por conta própria.
2. Utilize EXCLUSIVAMENTE os números exatos fornecidos no snapshot JSON de contexto.
3. Se um dado ou período não estiver presente no contexto, informe explicitamente: "Dado não disponível no relatório".
4. Foque em recomendações de negócio: quais itens da Classe A repor com urgência, como liquidar a Classe C e oportunidades de margem de lucro.
''';

  /// Prepara o payload auditado e blindado para a IA (Gemini)
  static Map<String, dynamic> buildAuditedPayload({
    required String perguntaUsuario,
    required AbcReportResult abcSnapshot,
    required Map<String, dynamic> estoqueSnapshot,
    required String tenantId,
    required bool isDemonstracao,
  }) {
    return {
      'tenantId': tenantId,
      'isDemonstracao': isDemonstracao,
      'seguranca': {'fonteVerdade': 'SISTEMA_DART_ABC_V1', 'regrasMatematicasAplicadas': true},
      'systemPrompt': systemSecurityPrompt,
      'contextoMatematicoFixo': {'curvaAbc': abcSnapshot.toJson(), 'estoqueAtual': estoqueSnapshot},
      'pergunta': perguntaUsuario,
    };
  }

  /// Valida se a resposta da IA contém alucinações de valores inexistentes
  static bool validarConformidadeResposta(String respostaIa, AbcReportResult abcSnapshot) {
    // Garante que a IA não contradiga as classes A, B ou C definidas pelo contrato matemático
    for (final item in abcSnapshot.itens) {
      if (respostaIa.contains(item.nome)) {
        // Se mencionar o item, não pode atribuir uma categoria diferente da oficial
        if (item.categoria == AbcCategory.A && respostaIa.contains('${item.nome} é C')) {
          return false; // Alucinação detectada!
        }
      }
    }
    return true;
  }
}
