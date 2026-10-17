import 'package:app_cic/core/semana_campo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('segunda a domingo pertencem à mesma semana, sem horário', () {
    for (var dia = 12; dia <= 18; dia++) {
      expect(inicioSemanaCampo(DateTime(2026, 10, dia, 23, 59)), DateTime(2026, 10, 12));
    }
    expect(inicioSemanaCampo(DateTime(2026, 10, 19)), DateTime(2026, 10, 19));
  });
  test('semana atravessa mês e ano', () {
    expect(inicioSemanaCampo(DateTime(2027, 1, 1)), DateTime(2026, 12, 28));
    expect(inicioSemanaCampo(DateTime(2026, 11, 1)), DateTime(2026, 10, 26));
  });
}
