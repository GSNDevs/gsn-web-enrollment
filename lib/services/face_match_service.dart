import 'dart:typed_data';
import 'package:dio/dio.dart';

/// Servicio encargado de la comunicación con la API de verificación de identidad.
class FaceMatchService {
  // Configuración de Dio con timeout extendido a 70 segundos
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 70),
      receiveTimeout: const Duration(seconds: 70),
    ),
  );

  /// Verifica el estado de salud de la API
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await _dio.get('https://verify.gware.cl/health');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e, "Error al verificar salud");
    }
  }

  /// Procesa el OCR del documento (acepta bytes en vez de File)
  Future<Map<String, dynamic>> processOCR(Uint8List documentBytes) async {
    try {
      final formData = FormData.fromMap({
        'document': MultipartFile.fromBytes(
          documentBytes,
          filename: 'doc.jpg',
        ),
      });
      final response = await _dio.post(
        'https://ocr.gware.cl/ocr',
        data: formData,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e, "Error en procesamiento OCR");
    }
  }

  /// Compara dos rostros (Selfie vs Documento) usando bytes
  Future<Map<String, dynamic>> compareFaces({
    required Uint8List image1,
    required Uint8List image2,
  }) async {
    try {
      final formData = FormData.fromMap({
        'selfie': MultipartFile.fromBytes(
          image1,
          filename: 'selfie.jpg',
        ),
        'document': MultipartFile.fromBytes(
          image2,
          filename: 'doc.jpg',
        ),
      });
      final response = await _dio.post(
        'https://verify.gware.cl/verify',
        data: formData,
      );
      
      final Map<String, dynamic> responseData = response.data as Map<String, dynamic>;
      
      if (responseData['data'] != null) {
        final faceMatch = responseData['data']['face_match'];
        return {
          'status': responseData['status'],
          'code': responseData['code'],
          'message': responseData['message'],
          'data': faceMatch ?? {
            'verified': false,
            'similarity_percentage': 0,
          },
        };
      }
      return responseData;
    } on DioException catch (e) {
      throw _handleError(e, "Error en comparación facial");
    }
  }

  /// Realiza la verificación completa (OCR + Face Match) usando bytes
  Future<Map<String, dynamic>> fullVerification({
    required Uint8List documentBytes,
    required Uint8List selfieBytes,
  }) async {
    try {
      final formData = FormData.fromMap({
        'document': MultipartFile.fromBytes(
          documentBytes,
          filename: 'doc.jpg',
        ),
        'selfie': MultipartFile.fromBytes(
          selfieBytes,
          filename: 'selfie.jpg',
        ),
      });
      final response = await _dio.post(
        'https://verify.gware.cl/verify',
        data: formData,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e, "Error en verificación integral");
    }
  }

  String _handleError(DioException e, String context) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return "$context: Se agotó el tiempo de espera (70s).";
    }
    if (e.response != null && e.response?.data is Map) {
      return e.response?.data['message'] ?? "$context: Error del servidor";
    }
    return "$context: ${e.message}";
  }
}
