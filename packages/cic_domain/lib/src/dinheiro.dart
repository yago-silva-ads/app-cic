/// Dinheiro trafega sempre em centavos inteiros. Formatação só na apresentação.
///
/// Atenção ao compilar para Web (JS): inteiros são exatos até 2^53, isto é,
/// cerca de R$ 90 trilhões. A classificação ABC multiplica por 100, então o
/// limite seguro de total por loja é ~R$ 900 bilhões.
library;

String formatarCentavos(int centavos) {
  final negativo = centavos < 0;
  final abs = centavos.abs();
  final reais = formatarInteiro(abs ~/ 100);
  final cents = (abs % 100).toString().padLeft(2, '0');
  return '${negativo ? '-' : ''}R\$ $reais,$cents';
}

/// Inteiro com separador de milhar pt-BR (`1.234`).
String formatarInteiro(int valor) {
  final s = valor.abs().toString();
  final buf = StringBuffer(valor < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Rateia [total] entre [pesos] proporcionalmente, com soma exata.
///
/// Maior resto primeiro; empate de resto pelo índice ascendente. Usado para
/// distribuir desconto de pedido entre itens de forma determinística.
List<int> ratearProporcional(int total, List<int> pesos) {
  if (pesos.any((p) => p < 0)) {
    throw ArgumentError('Pesos de rateio não podem ser negativos');
  }
  final somaPesos = pesos.fold<int>(0, (a, b) => a + b);
  if (somaPesos == 0 || total == 0) return List.filled(pesos.length, 0);
  final partes = <int>[];
  final restos = <(int indice, int resto)>[];
  var distribuido = 0;
  for (var i = 0; i < pesos.length; i++) {
    final produto = total * pesos[i];
    final parte = produto ~/ somaPesos;
    partes.add(parte);
    restos.add((i, produto.remainder(somaPesos).abs()));
    distribuido += parte;
  }
  var falta = total - distribuido;
  final passo = falta.sign;
  restos.sort((a, b) {
    final r = b.$2.compareTo(a.$2);
    return r != 0 ? r : a.$1.compareTo(b.$1);
  });
  for (var k = 0; falta != 0; k++) {
    partes[restos[k % restos.length].$1] += passo;
    falta -= passo;
  }
  return partes;
}
