import 'package:flutter/services.dart';

class LeituraDecimalFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');

    // Remove tudo o que não for número
    String numerosLimpos = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numerosLimpos.isEmpty) return newValue.copyWith(text: '');

    // Converte para decimal
    double valor = int.parse(numerosLimpos) / 1000;
    String novoTexto = valor.toStringAsFixed(3).replaceAll('.', ',');

    return TextEditingValue(
      text: novoTexto,
      selection: TextSelection.collapsed(offset: novoTexto.length),
    );
  }
}
