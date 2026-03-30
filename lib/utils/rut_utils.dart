class RutUtils {
  // Limpia el RUT dejando solo números y K
  static String clean(String text) {
    return text.replaceAll(RegExp(r'[^0-9kK]'), '').toUpperCase();
  }

  // Valida si un RUT es matemáticamente correcto
  static bool isValid(String rut) {
    if (rut.isEmpty || rut.length < 8) return false;
    rut = clean(rut);

    try {
      final cuerpo = rut.substring(0, rut.length - 1);
      final dv = rut.substring(rut.length - 1);
      return _calculateDV(cuerpo) == dv;
    } catch (e) {
      return false;
    }
  }

  // Formatea visualmente: 123456789 -> 12.345.678-9
  static String format(String rut) {
    rut = clean(rut);
    if (rut.length < 2) return rut;

    String cuerpo = rut.substring(0, rut.length - 1);
    String dv = rut.substring(rut.length - 1);

    String cuerpoFormateado = '';
    for (int i = cuerpo.length - 1, j = 1; i >= 0; i--, j++) {
      cuerpoFormateado = cuerpo[i] + cuerpoFormateado;
      if (j % 3 == 0 && i > 0) cuerpoFormateado = '.$cuerpoFormateado';
    }

    return '$cuerpoFormateado-$dv';
  }

  static String _calculateDV(String cuerpo) {
    int suma = 0;
    int multiplicador = 2;

    for (int i = cuerpo.length - 1; i >= 0; i--) {
      suma += int.parse(cuerpo[i]) * multiplicador;
      multiplicador = multiplicador == 7 ? 2 : multiplicador + 1;
    }

    int resto = 11 - (suma % 11);
    if (resto == 11) return '0';
    if (resto == 10) return 'K';
    return resto.toString();
  }
}
