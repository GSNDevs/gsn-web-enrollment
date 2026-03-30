import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class ImageHelper {
  static final ImageHelper _instance = ImageHelper._internal();
  factory ImageHelper() => _instance;
  ImageHelper._internal();

  final ImagePicker _picker = ImagePicker();

  /// Selecciona múltiples imágenes (Galería) y retorna lista de bytes comprimidos.
  Future<List<Uint8List>> pickMultipleImages({
    int quality = 70,
    int? minWidth,
    int? minHeight,
  }) async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isEmpty) return [];

      final List<Future<Uint8List?>> tasks = pickedFiles.map((xFile) {
        return compressFromXFile(
          xFile,
          quality: quality,
          minWidth: minWidth,
          minHeight: minHeight,
        );
      }).toList();

      final results = await Future.wait(tasks);
      return results.whereType<Uint8List>().toList();
    } catch (e) {
      debugPrint("Error seleccionando imágenes: $e");
      return [];
    }
  }

  /// Selecciona una sola imagen y retorna bytes comprimidos.
  Future<Uint8List?> pickImage({
    ImageSource source = ImageSource.camera,
    int quality = 70,
    int? minWidth,
    int? minHeight,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) return null;

      return compressFromXFile(
        pickedFile,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
      );
    } catch (e) {
      debugPrint("Error capturando imagen: $e");
      return null;
    }
  }

  /// Comprime desde un XFile (retorno de camera/image_picker).
  Future<Uint8List?> compressFromXFile(
    XFile xFile, {
    int quality = 70,
    int? minWidth,
    int? minHeight,
  }) async {
    try {
      final bytes = await xFile.readAsBytes();
      return compressBytes(bytes, quality: quality, minWidth: minWidth, minHeight: minHeight);
    } catch (e) {
      debugPrint("Error comprimiendo desde XFile: $e");
      return null;
    }
  }

  /// Comprime un [Uint8List] usando el paquete `image`.
  /// Retorna los bytes comprimidos como JPEG con la calidad indicada.
  /// Opcionalmente redimensiona si se pasan [minWidth]/[minHeight].
  Future<Uint8List?> compressBytes(
    List<int> bytes, {
    int quality = 70,
    int? minWidth,
    int? minHeight,
  }) async {
    try {
      img.Image? decoded = img.decodeImage(Uint8List.fromList(bytes));
      if (decoded == null) return null;

      // Redimensionar si se solicita
      if (minWidth != null || minHeight != null) {
        decoded = img.copyResize(
          decoded,
          width: minWidth ?? decoded.width,
          height: minHeight ?? decoded.height,
          maintainAspect: true,
        );
      }

      // Codificar como JPEG con calidad reducida
      final compressed = img.encodeJpg(decoded, quality: quality);
      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint("Error comprimiendo bytes: $e");
      return null;
    }
  }
}
