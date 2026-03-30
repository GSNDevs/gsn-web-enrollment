import 'package:prueba_match/utils/app_colors.dart';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum CameraMode { selfie, document, fullScreen }

class CustomCameraView extends StatefulWidget {
  final CameraMode mode;

  const CustomCameraView({super.key, required this.mode});

  @override
  State<CustomCameraView> createState() => _CustomCameraViewState();
}

class _CustomCameraViewState extends State<CustomCameraView> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitializing = true;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No se encontraron cámaras');
      }

      CameraDescription selectedCamera;
      if (widget.mode == CameraMode.selfie) {
        selectedCamera = _cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        );
      } else {
        selectedCamera = _cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );
      }

      // Usar resolución alta pero no máxima para mejorar rendimiento
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();

      // lockCaptureOrientation no está disponible en web
      if (!kIsWeb) {
        try {
          await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
        } catch (_) {
          // Silenciar error si no es soportado
        }
      }

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('Error al inicializar cámara: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inicializar la cámara')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture || _isCapturing) return;

    try {
      setState(() {
        _isCapturing = true;
      });

      final XFile image = await _controller!.takePicture();
      Uint8List bytes = await image.readAsBytes();

      // Procesar la imagen en un isolate (compute) para no bloquear el UI
      final processedBytes = await compute(
        _processImage,
        _ImageProcessRequest(
          bytes: bytes,
          isSelfie: widget.mode == CameraMode.selfie,
        ),
      );

      if (mounted) {
        Navigator.pop(context, processedBytes);
      }
    } catch (e) {
      debugPrint('Error capturando foto: $e');
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al tomar la foto')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _controller == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.textPrimary)),
      );
    }

    // Mostrar indicador de procesamiento después de capturar
    if (_isCapturing) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              const SizedBox(height: 16),
              Text(
                'Procesando imagen...',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(child: _buildCameraPreview()),
          Positioned.fill(child: _buildOverlay()),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textPrimary, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.textPrimary, width: 4),
                      color: AppColors.textPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                SizedBox(width: 48), // Spacer for alignment
              ],
            ),
          ),
          if (widget.mode != CameraMode.fullScreen)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Text(
                widget.mode == CameraMode.selfie ? 'Centra tu rostro en el óvalo' : 'Centra el documento en el recuadro',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: AppColors.background, blurRadius: 4)],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(color: AppColors.background);
    }

    if (kIsWeb) {
      // En web móvil (iPhone Safari), el navegador entrega el video
      // ya rotado en la orientación correcta del dispositivo.
      // No debemos manipular aspect ratios ni hacer zoom/crop.
      // Simplemente dejamos que el CameraPreview llene el espacio disponible.
      return SizedBox.expand(
        child: CameraPreview(_controller!),
      );
    }

    // En plataformas nativas: usar FittedBox.cover para llenar la pantalla
    // manteniendo el aspect ratio y recortando lo que sobre.
    final previewSize = _controller!.value.previewSize;
    if (previewSize == null) {
      return SizedBox.expand(child: CameraPreview(_controller!));
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    if (widget.mode == CameraMode.fullScreen) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;
    final bool isSelfie = widget.mode == CameraMode.selfie;
    
    final double holeWidth = isSelfie ? size.width * 0.85 : size.width * 0.9;
    final double holeHeight = isSelfie ? size.height * 0.65 : (size.width * 0.9) / 1.6;
    
    final BorderRadius borderRadius = isSelfie 
        ? BorderRadius.circular(holeHeight)
        : BorderRadius.circular(16.0);

    return Stack(
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Colors.black54,
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: holeWidth,
                    height: holeHeight,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: borderRadius,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: holeWidth,
            height: holeHeight,
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(holeWidth, holeHeight),
                  painter: DottedBorderPainter(
                    color: Colors.blueAccent,
                    strokeWidth: 2.0,
                    gap: 6.0,
                    borderRadius: borderRadius,
                  ),
                ),
                if (widget.mode == CameraMode.document)
                  Positioned(
                    left: 20,
                    bottom: 20,
                    child: CustomPaint(
                      size: Size(holeWidth * 0.25, holeHeight * 0.6),
                      painter: PersonSilhouettePainter(
                        color: Colors.blueAccent.withValues(alpha: 0.5),
                        strokeWidth: 2.0,
                        gap: 4.0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PersonSilhouettePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  PersonSilhouettePainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.gap = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path();
    final double w = size.width;
    final double h = size.height;

    final double headRadius = w * 0.35;
    path.addOval(Rect.fromCircle(
      center: Offset(w / 2, headRadius + 5),
      radius: headRadius,
    ));

    path.moveTo(0, h);
    path.quadraticBezierTo(0, headRadius * 2 + 10, w / 2, headRadius * 2 + 10);
    path.quadraticBezierTo(w, headRadius * 2 + 10, w, h);

    final Path dashPath = Path();
    for (ui.PathMetric pathMetric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + gap),
          Offset.zero,
        );
        distance += gap * 2;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant PersonSilhouettePainter oldDelegate) => false;
}

class DottedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final BorderRadius borderRadius;

  DottedBorderPainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.gap = 5.0,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final RRect rrect = borderRadius.toRRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path path = Path()..addRRect(rrect);
    
    final Path dashPath = Path();
    double distance = 0.0;
    for (ui.PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + gap),
          Offset.zero,
        );
        distance += gap * 2;
      }
      distance = 0.0;
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DottedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
           oldDelegate.strokeWidth != strokeWidth ||
           oldDelegate.gap != gap ||
           oldDelegate.borderRadius != borderRadius;
  }
}

// --- Procesamiento de imagen en isolate (fuera del hilo principal) ---

class _ImageProcessRequest {
  final Uint8List bytes;
  final bool isSelfie;

  _ImageProcessRequest({required this.bytes, required this.isSelfie});
}

/// Procesa la imagen en un isolate separado:
/// - Redimensiona a un máximo razonable (1200px de ancho)
/// - Voltea horizontalmente si es selfie
/// - Comprime a JPEG calidad 80
/// Todo en un solo paso de decode/encode.
Uint8List _processImage(_ImageProcessRequest request) {
  img.Image? decoded = img.decodeImage(request.bytes);
  if (decoded == null) return request.bytes;

  // Redimensionar si es muy grande (max 1200px de ancho)
  if (decoded.width > 1200) {
    decoded = img.copyResize(decoded, width: 1200, maintainAspect: true);
  }

  // Voltear horizontalmente si es selfie (mirror)
  if (request.isSelfie) {
    decoded = img.flipHorizontal(decoded);
  }

  // Codificar como JPEG con calidad 80 (buen balance calidad/peso)
  final compressed = img.encodeJpg(decoded, quality: 80);
  return Uint8List.fromList(compressed);
}
