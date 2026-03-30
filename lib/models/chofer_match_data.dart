import 'package:flutter/foundation.dart';
/// Modelo para contener los datos obtenidos del proceso de FaceTec + OCR para un chofer.
class ChoferMatchData {
  // Datos del OCR
  final String? nombres;
  final String? apellidos;
  final String? run; // RUT del chofer
  final String? numeroDocumento;
  final String? nacionalidad;
  final String? sexo;
  final String? fechaNacimiento;
  final String? fechaVencimiento;
  final String? fechaEmision;
  final String? claseLicencia; // <-- NUEVO CAMPO
  final String? fotoCaraCarnet; // <-- 1. NUEVO CAMPO AÃƒÆ’Ã¢â‚¬ËœADIDO

  // Foto de Liveness
  final String? fotoMatch; // Base64 de la Audit Trail Image

  ChoferMatchData({
    this.nombres,
    this.apellidos,
    this.run,
    this.numeroDocumento,
    this.nacionalidad,
    this.sexo,
    this.fechaNacimiento,
    this.fechaVencimiento,
    this.fechaEmision,
    this.claseLicencia, // <-- NUEVO CAMPO
    this.fotoMatch,
    this.fotoCaraCarnet, // <-- 2. AÃƒÆ’Ã¢â‚¬ËœADIDO AL CONSTRUCTOR
  });

  /// Factory para crear una instancia desde el objeto JSON 'documentData' del OCR.
  factory ChoferMatchData.fromDocumentData(
    Map<String, dynamic> documentDataJson,
  ) {
    String? findValue(String key, List<dynamic> groups) {
      for (var group in groups) {
        final fields = group['fields'] as List<dynamic>? ?? [];
        for (var field in fields) {
          if (field['fieldKey'] == key) {
            return field['value'];
          }
        }
      }
      return null;
    }

    try {
      final scannedValues = documentDataJson['scannedValues'];
      if (scannedValues == null || scannedValues['groups'] == null) {
        return ChoferMatchData();
      }
      final groups = scannedValues['groups'] as List<dynamic>;
      return ChoferMatchData(
        nombres: findValue('firstName', groups),
        apellidos: findValue('lastName', groups),
        run: findValue('idNumber2', groups),
        numeroDocumento: findValue('idNumber', groups),
        nacionalidad: findValue('nationality', groups),
        sexo: findValue('sex', groups),
        fechaNacimiento: findValue('dateOfBirth', groups),
        fechaVencimiento: findValue('dateOfExpiration', groups),
        fechaEmision: findValue('dateOfIssue', groups),
        claseLicencia: findValue('class', groups), // <-- NUEVO CAMPO
      );
    } catch (e) {
      debugPrint('Error al parsear documentData: $e');
      return ChoferMatchData();
    }
  }

  factory ChoferMatchData.fromDbMap(Map<String, dynamic> data) {
    return ChoferMatchData(
      nombres: data['nombres_chofer'],
      apellidos: data['apellidos_chofer'],
      run: data['rut_chofer'],
      numeroDocumento: data['numero_documento'],
      fechaNacimiento: data['fecha_nacimiento'],
      fechaVencimiento: data['fecha_vencimiento'],
      fechaEmision: data['fecha_emision'],
      fotoMatch: data['foto_match'],
    );
  }

  /// Crea una copia de esta instancia con los campos proporcionados reemplazados.
  ChoferMatchData copyWith({
    String? nombres,
    String? apellidos,
    String? run,
    String? numeroDocumento,
    String? nacionalidad,
    String? sexo,
    String? fechaNacimiento,
    String? fechaVencimiento,
    String? fechaEmision,
    String? claseLicencia, // <-- NUEVO CAMPO
    String? fotoMatch,
    String? fotoCaraCarnet,
  }) {
    return ChoferMatchData(
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      run: run ?? this.run,
      numeroDocumento: numeroDocumento ?? this.numeroDocumento,
      nacionalidad: nacionalidad ?? this.nacionalidad,
      sexo: sexo ?? this.sexo,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      fechaEmision: fechaEmision ?? this.fechaEmision,
      claseLicencia: claseLicencia ?? this.claseLicencia, // <-- NUEVO CAMPO
      fotoMatch: fotoMatch ?? this.fotoMatch,
      fotoCaraCarnet: fotoCaraCarnet ?? this.fotoCaraCarnet,
    );
  }
}
