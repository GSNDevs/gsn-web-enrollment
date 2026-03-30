import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prueba_match/models/chofer_match_data.dart';
import 'package:prueba_match/models/license_data.dart';
import 'package:prueba_match/utils/rut_utils.dart';
import 'package:prueba_match/utils/document_utils.dart';
import 'package:prueba_match/utils/image_helper.dart';
import 'package:prueba_match/views/transport_document_view.dart';

enum EstadoVerificacionChofer { valido, vencido, noExiste }

class ResultadoVerificacion {
  final EstadoVerificacionChofer estado;
  final Map<String, dynamic>? datosChofer;

  ResultadoVerificacion({required this.estado, this.datosChofer});
}

class RegistroService {
  final _client = Supabase.instance.client;

  Future<String?> getRutParaValidar(int registroId) async {
    try {
      final response = await _client
          .from('registro_choferes')
          .select('rut_a_validar')
          .eq('id_registro', registroId)
          .single();
      return response['rut_a_validar'] as String?;
    } catch (e) {
      debugPrint('Error obteniendo RUT a validar: $e');
      return null;
    }
  }

  Future<ResultadoVerificacion> verificarEstadoChofer(String rut) async {
    try {
      final rutFormateado = RutUtils.format(rut);

      final response = await _client
          .from('choferes')
          .select()
          .eq('rut_chofer', rutFormateado)
          .maybeSingle();

      if (response == null) {
        return ResultadoVerificacion(estado: EstadoVerificacionChofer.noExiste);
      }

      final chofer = response;
      final fechaVencimientoStr = chofer['fecha_vencimiento'] as String?;
      final fechaCreacionStr = chofer['creado_en'] as String?;

      if (fechaVencimientoStr == null || fechaCreacionStr == null) {
        return ResultadoVerificacion(
          estado: EstadoVerificacionChofer.valido,
          datosChofer: chofer,
        );
      }

      final fechaVencimiento = DateTime.parse(fechaVencimientoStr);
      final fechaCreacion = DateTime.parse(fechaCreacionStr);
      final hoy = DateTime.now();
      final haceUnAnio = hoy.subtract(const Duration(days: 365));
      if (fechaVencimiento.isBefore(hoy)) {
        return ResultadoVerificacion(
          estado: EstadoVerificacionChofer.vencido,
          datosChofer: chofer,
        );
      }

      if (fechaCreacion.isBefore(haceUnAnio)) {
        return ResultadoVerificacion(
          estado: EstadoVerificacionChofer.vencido,
          datosChofer: chofer,
        );
      }

      return ResultadoVerificacion(
        estado: EstadoVerificacionChofer.valido,
        datosChofer: chofer,
      );
    } catch (e) {
      debugPrint('Error al verificar estado del chofer: $e');
      rethrow;
    }
  }

  Future<ResultadoVerificacion> verificarEstadoLicencia(int idChofer) async {
    try {
      final response = await _client
          .from('licencias_conducir')
          .select()
          .eq('id_chofer', idChofer)
          .order('creado_en', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return ResultadoVerificacion(estado: EstadoVerificacionChofer.noExiste);
      }

      final fechaVencimientoStr = response['fecha_vencimiento'] as String?;
      if (fechaVencimientoStr == null) {
        // Asumimos vencida o que no sabemos si está vigente, forzamos escaneo 
        return ResultadoVerificacion(
          estado: EstadoVerificacionChofer.vencido,
          datosChofer: response,
        );
      }

      final fechaVencimiento = DateTime.parse(fechaVencimientoStr);
      final hoy = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

      if (fechaVencimiento.isBefore(hoy)) {
        return ResultadoVerificacion(
          estado: EstadoVerificacionChofer.vencido,
          datosChofer: response,
        );
      }

      return ResultadoVerificacion(
        estado: EstadoVerificacionChofer.valido,
        datosChofer: response,
      );
    } catch (e) {
      debugPrint('Error al verificar estado de licencia: $e');
      rethrow;
    }
  }

  Future<void> asociarChoferARegistro(int registroId, int choferId) async {
    try {
      await _client
          .from('registro_choferes')
          .update({'id_chofer': choferId, 'resultado_match': true})
          .eq('id_registro', registroId);
      debugPrint('Chofer ID $choferId asociado al registro ID $registroId.');
    } catch (e) {
      debugPrint('Error al asociar chofer a registro: $e');
      throw Exception('No se pudo asociar el chofer existente.');
    }
  }

  Future<int> procesarDatosVerificacion(
    int registroId,
    ChoferMatchData datos,
  ) async {
    try {
      final rutFormateado = RutUtils.format(datos.run ?? '');
      final numeroDocumentoFormateado = DocumentUtils.format(
        datos.numeroDocumento ?? '',
      );
      final imageHelper = ImageHelper();
      final ts = DateTime.now().millisecondsSinceEpoch;

      // --- Comprimir y subir foto_match al bucket 'choferes' ---
      String? fotoMatchUrl;
      if (datos.fotoMatch != null && datos.fotoMatch!.isNotEmpty) {
        final rawBytes = base64Decode(datos.fotoMatch!);
        final compressed = await imageHelper.compressBytes(
          rawBytes,
          quality: 70,
        );
        final uploadBytes = compressed ?? rawBytes;
        final path = '$rutFormateado/foto_match_$ts.jpg';
        await _client.storage
            .from('choferes')
            .uploadBinary(
              path,
              uploadBytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        fotoMatchUrl = _client.storage.from('choferes').getPublicUrl(path);
        debugPrint('foto_match subida: $fotoMatchUrl');
      }

      // --- Comprimir y subir foto_cara_carnet al bucket 'choferes' ---
      String? fotoCaraCarnetUrl;
      if (datos.fotoCaraCarnet != null && datos.fotoCaraCarnet!.isNotEmpty) {
        final rawBytes = base64Decode(datos.fotoCaraCarnet!);
        final compressed = await imageHelper.compressBytes(
          rawBytes,
          quality: 70,
        );
        final uploadBytes = compressed ?? rawBytes;
        final path = '$rutFormateado/foto_cara_carnet_$ts.jpg';
        await _client.storage
            .from('choferes')
            .uploadBinary(
              path,
              uploadBytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        fotoCaraCarnetUrl = _client.storage.from('choferes').getPublicUrl(path);
        debugPrint('foto_cara_carnet subida: $fotoCaraCarnetUrl');
      }

      final existingResponse = await _client
          .from('choferes')
          .select('id_chofer, fecha_vencimiento')
          .eq('rut_chofer', rutFormateado)
          .maybeSingle();

      int choferId;

      if (existingResponse != null) {
        // EXISTE -> Verificamos si está vencido antes de actualizar
        choferId = existingResponse['id_chofer'] as int;

        final fechaVencimientoStr = existingResponse['fecha_vencimiento'] as String?;
        bool isExpired = true;

        if (fechaVencimientoStr != null) {
          final fechaVencimientoDB = DateTime.parse(fechaVencimientoStr);
          final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
          if (fechaVencimientoDB.isAfter(today) ||
              fechaVencimientoDB.isAtSameMomentAs(today)) {
            isExpired = false;
          }
        }

        if (isExpired) {
          final datosUpdate = {
            'numero_documento': numeroDocumentoFormateado,
            'fecha_emision': _formatarFechaParaSupabase(datos.fechaEmision),
            'fecha_vencimiento': _formatarFechaParaSupabase(datos.fechaVencimiento),
            'actualizado_en': DateTime.now().toIso8601String(),
          };
          
          if (fotoMatchUrl != null) datosUpdate['foto_match'] = fotoMatchUrl;
          if (fotoCaraCarnetUrl != null) datosUpdate['foto_cara_carnet'] = fotoCaraCarnetUrl;

          await _client
              .from('choferes')
              .update(datosUpdate)
              .eq('id_chofer', choferId);
              
          debugPrint('Chofer existente vencido. Se actualizaron datos de documento y fotos.');
        } else {
          debugPrint('Chofer existente vigente. No se actualizarán sus datos base.');
        }
            
      } else {
        // NO EXISTE -> Insertamos registro completo nuevo
        final datosInsert = {
          'rut_chofer': rutFormateado,
          'nombres_chofer': datos.nombres,
          'apellidos_chofer': datos.apellidos,
          'numero_documento': numeroDocumentoFormateado,
          'fecha_nacimiento': _formatarFechaParaSupabase(datos.fechaNacimiento),
          'fecha_emision': _formatarFechaParaSupabase(datos.fechaEmision),
          'fecha_vencimiento': _formatarFechaParaSupabase(datos.fechaVencimiento),
          'nacionalidad': datos.nacionalidad,
          'sexo': datos.sexo,
          'foto_match': fotoMatchUrl,
          'foto_cara_carnet': fotoCaraCarnetUrl,
          'creado_en': DateTime.now().toIso8601String(),
        };

        final response = await _client
            .from('choferes')
            .insert(datosInsert)
            .select('id_chofer')
            .single();

        choferId = response['id_chofer'] as int;
      }

      await _client
          .from('registro_choferes')
          .update({'id_chofer': choferId, 'resultado_match': true})
          .eq('id_registro', registroId);

      return choferId;
    } catch (e) {
      debugPrint(
        'Error al procesar datos de verificación: $e',
      );
      throw Exception(
        'No se pudo guardar la información del chofer.',
      );
    }
  }

  Future<void> guardarDatosLicenciaEscaneada(
    String rutChofer,
    LicenseData datosLicencia,
  ) async {
    // Usamos el RUT formateado para buscar el chofer
    final rutBusqueda = RutUtils.format(rutChofer);

    final response = await _client
        .from('choferes')
        .select('id_chofer')
        .eq('rut_chofer', rutBusqueda)
        .single();

    final choferId = response['id_chofer'] as int?;

    if (choferId == null) {
      throw Exception(
        'No se encontró el chofer para asociar la licencia.',
      );
    }

    try {
      final rutLicenciaFormateado = RutUtils.format(datosLicencia.rut ?? '');

      // --- Comprimir y subir foto_licencia al bucket 'licencias' ---
      String? fotoLicenciaUrl;
      if (datosLicencia.fotoLicencia != null &&
          datosLicencia.fotoLicencia!.isNotEmpty) {
        final imageHelper = ImageHelper();
        final ts = DateTime.now().millisecondsSinceEpoch;
        final rawBytes = base64Decode(datosLicencia.fotoLicencia!);
        final compressed = await imageHelper.compressBytes(
          rawBytes,
          quality: 70,
        );
        final uploadBytes = compressed ?? rawBytes;
        final path = '$rutLicenciaFormateado/foto_licencia_$ts.jpg';
        await _client.storage
            .from('licencias')
            .uploadBinary(
              path,
              uploadBytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        fotoLicenciaUrl = _client.storage.from('licencias').getPublicUrl(path);
        debugPrint('foto_licencia subida: $fotoLicenciaUrl');
      }

      final mapaDeDatos = {
        'id_chofer': choferId,
        'rut': rutLicenciaFormateado,
        'nombres': datosLicencia.nombres,
        'apellidos': datosLicencia.apellidos,
        'clase': datosLicencia.clase,
        'direccion': datosLicencia.direccion,
        'foto_licencia': fotoLicenciaUrl,
        'fecha_emision': _formatarFechaParaSupabase(datosLicencia.fechaEmision),
        'fecha_vencimiento': _formatarFechaParaSupabase(
          datosLicencia.fechaVencimiento,
        ),
        'creado_en': DateTime.now().toIso8601String(),
      };

      final existingLicenseResponse = await _client
          .from('licencias_conducir')
          .select('id_licencia, fecha_vencimiento')
          .eq('id_chofer', choferId) // Buscar por id_chofer
          .order('creado_en', ascending: false) // Siempre revisar el último creado
          .limit(1)
          .maybeSingle();

      if (existingLicenseResponse != null) {
        // existe, verificamos vencimiento
        final fechaVencimientoStr =
            existingLicenseResponse['fecha_vencimiento'] as String?;
        bool isExpired = true;

        if (fechaVencimientoStr != null) {
          final fechaVencimiento = DateTime.parse(fechaVencimientoStr);
          final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
          if (fechaVencimiento.isAfter(today) ||
              fechaVencimiento.isAtSameMomentAs(today)) {
            isExpired = false;
          }
        }

        if (!isExpired) {
          // VIGENTE -> ACTUALIZAR (Sobrescribir el último vigente)
          final idLicencia = existingLicenseResponse['id_licencia'];
          await _client
              .from('licencias_conducir')
              .update(mapaDeDatos)
              .eq('id_licencia', idLicencia);
          debugPrint('Licencia vigente actualizada (ID: $idLicencia)');
          return;
        }
        // VENCIDA -> Crear Nuevo (fallthrough to insert)
        debugPrint('Licencia existente vencida. Creando nuevo registro.');
      } else {
        debugPrint('Licencia nueva. Creando registro.');
      }

      // 2. Insertar nueva (caso no existe o vencida)
      await _client.from('licencias_conducir').insert(mapaDeDatos);
    } catch (e) {
      debugPrint('Error al guardar datos de licencia: $e');
      throw Exception(
        'No se pudo guardar el histórico de la licencia.',
      );
    }
  }

  Future<int?> getRegistroIdPorCodigo(String codigo) async {
    try {
      final response = await _client
          .from('registro_choferes')
          .select('id_registro, id_agendamiento')
          .eq('codigo_acceso', codigo)
          .single();

      if (response['id_agendamiento'] != null) {
        throw Exception(
          'El código ya ha sido utilizado para agendar.',
        );
      }

      return response['id_registro'] as int?;
    } catch (e) {
      debugPrint('Error al validar código de acceso: $e');
      if (e.toString().contains(
        'El código ya ha sido utilizado',
      )) {
        rethrow;
      }
      return null;
    }
  }

  Future<void> actualizarTipoVehiculo(
    int registroId,
    String tipoVehiculo,
  ) async {
    try {
      await _client
          .from('registro_choferes')
          .update({'tipo_vehiculo': tipoVehiculo})
          .eq('id_registro', registroId);
    } catch (e) {
      debugPrint(
        'Error al actualizar el tipo de vehículo: $e',
      );
      throw Exception(
        'No se pudo guardar el tipo de vehículo.',
      );
    }
  }

  Future<String?> obtenerTipoVehiculo(int registroId) async {
    try {
      final response = await _client
          .from('registro_choferes')
          .select('tipo_vehiculo')
          .eq('id_registro', registroId)
          .single();
      return response['tipo_vehiculo'] as String?;
    } catch (e) {
      debugPrint('Error al obtener el tipo de vehículo: $e');
      return null;
    }
  }

  Future<void> actualizarDatosVehiculo({
    required int registroId,
    required String patente,
    required String container,
  }) async {
    try {
      await _client
          .from('registro_choferes')
          .update({
            'patente_ingresada': patente,
            'container_ingresado': container,
          })
          .eq('id_registro', registroId);
    } catch (e) {
      debugPrint('Error al guardar datos de vehículo: $e');
      throw Exception(
        'No se pudieron guardar los datos del vehículo.',
      );
    }
  }

  Future<void> actualizarFoto({
    required int registroId,
    required String fotoBase64,
    required PhotoType tipo,
  }) async {
    try {
      final String columnName;
      final String bucket;
      final String pathPrefix;

      switch (tipo) {
        case PhotoType.bl:
          columnName = 'foto_bl';
          bucket = 'documentos';
          pathPrefix = 'bl';
          break;
      }

      // --- Comprimir y subir al bucket correspondiente ---
      final imageHelper = ImageHelper();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final rawBytes = base64Decode(fotoBase64);
      final compressed = await imageHelper.compressBytes(rawBytes, quality: 70);
      final uploadBytes = compressed ?? rawBytes;
      final path = '$pathPrefix/$registroId/${columnName}_$ts.jpg';

      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            uploadBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final url = _client.storage.from(bucket).getPublicUrl(path);

      await _client
          .from('registro_choferes')
          .update({columnName: url})
          .eq('id_registro', registroId);

      debugPrint(
        'Foto de $tipo subida al bucket "$bucket" y URL guardada para registro ID: $registroId',
      );
    } catch (e) {
      debugPrint('Error al guardar la foto de $tipo: $e');
      throw Exception('No se pudo guardar la foto. Causa: ${e.toString()}');
    }
  }

  Future<void> actualizarCargaPeligrosa({
    required int registroId,
    required bool esPeligrosa,
  }) async {
    try {
      await _client
          .from('registro_choferes')
          .update({'carga_peligrosa': esPeligrosa})
          .eq('id_registro', registroId);
    } catch (e) {
      debugPrint('Error al actualizar estado de carga peligrosa: $e');
      throw Exception(
        'No se pudo guardar la selección de carga.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getBloquesDisponibles(
    DateTime fecha,
  ) async {
    try {
      final fechaStr = DateFormat('yyyy-MM-dd').format(fecha);

      // 1. Obtener todos los bloques configurados (desde la tabla o RPC)
      // Usamos el RPC existente que nos da la base.
      final responseBloques = await _client.rpc(
        'get_bloques_disponibles',
        params: {'fecha_seleccionada': fechaStr},
      );
      final todosLosBloques = List<Map<String, dynamic>>.from(responseBloques);

      // 2. Obtener conteo de agendamientos para esa fecha
      final responseAgendamientos = await _client
          .from('agendamientos')
          .select('id_bloque')
          .eq('fecha_agendada', fechaStr);

      final List<dynamic> agendamientos =
          responseAgendamientos as List<dynamic>;

      // Mapa para contar uso por bloque
      final Map<int, int> conteoPorBloque = {};
      for (var item in agendamientos) {
        final int idBloque = item['id_bloque'] as int;
        conteoPorBloque[idBloque] = (conteoPorBloque[idBloque] ?? 0) + 1;
      }

      final int limitePorBloque = 40;

      // 3. Filtrar bloques que no hayan alcanzado el límite
      final bloquesFiltrados = todosLosBloques.where((bloque) {
        final int id = bloque['id_bloque'] as int;
        final int usados = conteoPorBloque[id] ?? 0;
        return usados < limitePorBloque;
      }).toList();

      return bloquesFiltrados;
    } catch (e) {
      debugPrint('Error al obtener bloques disponibles: $e');
      throw Exception('No se pudieron cargar los horarios.');
    }
  }

  Future<void> crearAgendamiento({
    required int registroId,
    required DateTime fecha,
    required int bloqueId,
  }) async {
    try {
      // 1. Obtiene el id_chofer del registro_choferes actual.
      final registroResponse = await _client
          .from('registro_choferes')
          .select('id_chofer')
          .eq('id_registro', registroId)
          .single();

      final idChofer = registroResponse['id_chofer'];

      if (idChofer == null) {
        throw Exception(
          'No se encontró un chofer asociado a esta visita.',
        );
      }

      // 2. Prepara el nuevo agendamiento con todos los datos necesarios.
      final agendamiento = {
        'id_chofer': idChofer,
        'fecha_agendada': DateFormat('yyyy-MM-dd').format(fecha),
        'id_bloque': bloqueId,
      };

      // 3. Inserta el agendamiento y obtiene su ID.
      final agendamientoResponse = await _client
          .from('agendamientos')
          .insert(agendamiento)
          .select()
          .single();

      final nuevoAgendamientoId = agendamientoResponse['id_agendamiento'];

      // 4. Actualiza la tabla registro_choferes para vincularla con el agendamiento.
      await _client
          .from('registro_choferes')
          .update({'id_agendamiento': nuevoAgendamientoId})
          .eq('id_registro', registroId);
    } catch (e) {
      debugPrint('Error al crear agendamiento: $e');
      throw Exception('No se pudo crear el agendamiento.');
    }
  }

  String? _formatarFechaParaSupabase(String? fechaOcr) {
    if (fechaOcr == null || fechaOcr.isEmpty) return null;
    try {
      const monthMap = {
        'ENE': '01',
        'FEB': '02',
        'MAR': '03',
        'ABR': '04',
        'MAY': '05',
        'JUN': '06',
        'JUL': '07',
        'AGO': '08',
        'SEP': '09',
        'OCT': '10',
        'NOV': '11',
        'DIC': '12',
        'JAN': '01',
        'APR': '04',
        'AUG': '08',
        'DEC': '12',
      };
      final parts = fechaOcr.trim().split(RegExp(r'[\s./-]+'));
      if (parts.length != 3) return null;

      String year, monthNum, day;

      if (parts[0].length == 4) {
        // yyyy-mm-dd or similar
        year = parts[0];
        monthNum = monthMap[parts[1].toUpperCase()] ?? parts[1].padLeft(2, '0');
        day = parts[2].padLeft(2, '0');
      } else {
        // dd-mm-yyyy or similar
        day = parts[0].padLeft(2, '0');
        monthNum = monthMap[parts[1].toUpperCase()] ?? parts[1].padLeft(2, '0');
        year = parts[2].length == 2 ? '20${parts[2]}' : parts[2];
      }

      return '$year-$monthNum-$day';
    } catch (e) {
      debugPrint('No se pudo formatear la fecha "$fechaOcr": $e');
      return null;
    }
  }
}
