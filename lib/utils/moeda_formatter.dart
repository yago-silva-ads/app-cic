import 'package:flutter/services.dart';

class MoedaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // 1. Remove tudo que não for número
    String numbers = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numbers.isEmpty) return const TextEditingValue(text: '0,00', selection: TextSelection.collapsed(offset: 4));

    // 🔥 A MÁGICA QUE FALTAVA: Converte para número e volta para texto. 
    // Isso DESTROÍ todos os zeros à esquerda acumulados (00000000010 vira apenas 10).
    numbers = BigInt.parse(numbers).toString();

    // 2. Garante que tenha 3 dígitos para os centavos funcionarem
    numbers = numbers.padLeft(3, '0');

    // 3. Separa os centavos dos milhares
    String cents = numbers.substring(numbers.length - 2);
    String integerPart = numbers.substring(0, numbers.length - 2);

    // 4. Coloca os pontos a cada 3 casas
    String formattedInteger = '';
    int count = 0;
    for (int i = integerPart.length - 1; i >= 0; i--) {
      formattedInteger = integerPart[i] + formattedInteger;
      count++;
      if (count % 3 == 0 && i != 0) {
        formattedInteger = '.$formattedInteger';
      }
    }

    String finalResult = '$formattedInteger,$cents';

    return TextEditingValue(
      text: finalResult,
      selection: TextSelection.collapsed(offset: finalResult.length),
    );
  }
}