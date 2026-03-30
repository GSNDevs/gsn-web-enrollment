import 'package:flutter/services.dart';

class DocumentUtils {
  // Limpia el número de documento dejando números y letras
  static String clean(String text) {
    return text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  // Formatea: 123456789 -> 123.456.789
  static String format(String documentNumber) {
    String cleaned = clean(documentNumber);
    if (cleaned.isEmpty) return documentNumber;

    String formatted = '';
    int count = 0;

    // Recorremos de atrás para adelante
    for (int i = cleaned.length - 1; i >= 0; i--) {
      formatted = cleaned[i] + formatted;
      count++;
      if (count % 3 == 0 && i > 0) {
        formatted = '.$formatted';
      }
    }

    return formatted;
  }
}

class DateTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;
    text = text.replaceAll(RegExp(r'[^0-9]'), '');

    if (text.length > 8) {
      text = text.substring(0, 8);
    }

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if ((i == 1 || i == 3) && i != text.length - 1) {
        formatted += '/';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class DocumentNumberTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.toUpperCase();
    text = text.replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (text.length > 9) {
      text = text.substring(0, 9);
    }

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if ((i == 2 || i == 5) && i != text.length - 1) {
        formatted += '.';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
