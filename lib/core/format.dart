import 'package:intl/intl.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);
final _numero = NumberFormat.decimalPattern('pt_BR');
final _dataCurta = DateFormat('dd/MM/yyyy');
final _dataHora = DateFormat('dd/MM/yyyy HH:mm');

/// `R$ 1.234,56`
String brl(num valor) => _moeda.format(valor).replaceAll(' ', ' ');

String inteiro(num valor) => _numero.format(valor);

String dataCurta(DateTime? d) => d == null ? '—' : _dataCurta.format(d.toLocal());
String dataHora(DateTime? d) => d == null ? '—' : _dataHora.format(d.toLocal());

/// Converte texto digitado (`12,50`, `1.234,56`, `12.5`) em número; null se inválido.
double? lerDecimal(String texto) {
  var t = texto.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(t);
}

int? lerInteiro(String texto) => int.tryParse(texto.trim());

/// Reais -> centavos sem erro de ponto flutuante.
int centavos(num reais) => (reais * 100).round();
