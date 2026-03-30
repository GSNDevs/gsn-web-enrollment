import 'package:flutter/foundation.dart';
/// Un modelo de datos especÃƒÆ’Ã‚Â­fico para contener la informaciÃƒÆ’Ã‚Â³n
/// extraÃƒÆ’Ã‚Â­da del OCR de una licencia de conducir.
class LicenseData {
  final String? nombres;
  final String? apellidos;
  final String? rut;
  final String? fechaNacimiento;
  final String? fechaEmision;
  final String? fechaVencimiento;
  final String? clase;
  final String? direccion;
  final String? fotoLicencia; // <-- NUEVO CAMPO

  LicenseData({
    this.nombres,
    this.apellidos,
    this.rut,
    this.fechaNacimiento,
    this.fechaEmision,
    this.fechaVencimiento,
    this.clase,
    this.direccion,
    this.fotoLicencia, // <-- NUEVO CAMPO
  });

  /// Factory para crear una instancia desde el JSON del OCR de FaceTec.
  factory LicenseData.fromDocumentData(Map<String, dynamic> documentDataJson) {
    // --- LÃƒÆ’Ã¢â‚¬Å“GICA MEJORADA ---
    // Esta funciÃƒÆ’Ã‚Â³n ahora busca una clave (`key`) solo dentro de un grupo especÃƒÆ’Ã‚Â­fico (`targetGroupKey`).
    String? findValueInGroup(
      String key,
      List<dynamic> groups,
      String targetGroupKey,
    ) {
      for (var group in groups) {
        // Solo busca dentro del grupo que nos interesa (ej: 'idInfo')
        if (group['groupKey'] == targetGroupKey) {
          final fields = group['fields'] as List<dynamic>? ?? [];
          for (var field in fields) {
            if (field['fieldKey'] == key) {
              return field['value'];
            }
          }
        }
      }
      return null;
    }

    try {
      final scannedValues = documentDataJson['scannedValues'];
      if (scannedValues == null || scannedValues['groups'] == null) {
        return LicenseData();
      }
      final groups = scannedValues['groups'] as List<dynamic>;

      return LicenseData(
        nombres: findValueInGroup('firstName', groups, 'userInfo'),
        apellidos: findValueInGroup('lastName', groups, 'userInfo'),
        rut: findValueInGroup('idNumber', groups, 'idInfo'),
        fechaNacimiento: findValueInGroup('dateOfBirth', groups, 'userInfo'),
        fechaEmision: findValueInGroup('dateOfIssue', groups, 'idInfo'),
        fechaVencimiento: findValueInGroup(
          'dateOfExpiration',
          groups,
          'idInfo',
        ),
        clase: findValueInGroup(
          'class',
          groups,
          'idInfo',
        ), // <-- AHORA ES ESPECÃƒÆ’Ã‚ÂFICO
        direccion: findValueInGroup('address1', groups, 'addressInfo'),
      );
    } catch (e) {
      debugPrint('Error al parsear documentData de licencia: $e');
      return LicenseData();
    }
  }

  /// Crea una copia con los campos actualizados desde la UI de confirmaciÃƒÆ’Ã‚Â³n.
  LicenseData copyWith({
    String? nombres,
    String? apellidos,
    String? rut,
    String? fechaNacimiento,
    String? fechaEmision,
    String? fechaVencimiento,
    String? clase,
    String? direccion,
    String? fotoLicencia, // <-- NUEVO CAMPO
  }) {
    return LicenseData(
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      rut: rut ?? this.rut,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      fechaEmision: fechaEmision ?? this.fechaEmision,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      clase: clase ?? this.clase,
      direccion: direccion ?? this.direccion,
      fotoLicencia: fotoLicencia ?? this.fotoLicencia, // <-- NUEVO CAMPO
    );
  }
}
