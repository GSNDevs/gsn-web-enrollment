import 'package:prueba_match/utils/app_colors.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:prueba_match/services/registro_service.dart';
import 'package:prueba_match/views/vehicle_data_view.dart';
import 'package:prueba_match/utils/image_helper.dart';
import 'package:prueba_match/views/custom_camera_view.dart';
import 'package:prueba_match/widgets/step_header.dart';

enum PhotoType { bl }

class TransportDocumentView extends StatefulWidget {
  final int registroId;
  final PhotoType photoType;

  const TransportDocumentView({
    super.key,
    required this.registroId,
    required this.photoType,
  });

  @override
  State<TransportDocumentView> createState() => _TransportDocumentViewState();
}

class _TransportDocumentViewState extends State<TransportDocumentView> {
  final RegistroService _registroService = RegistroService();
  final ImageHelper _imageHelper = ImageHelper();

  bool _isUploading = false;
  Uint8List? _capturedBytes;
  String? _tipoVehiculo;
  bool _isLoadingType = true;
  bool _hasNoBL = false;

  @override
  void initState() {
    super.initState();
    _loadTipoVehiculo();
  }

  Future<void> _loadTipoVehiculo() async {
    final tipo = await _registroService.obtenerTipoVehiculo(widget.registroId);
    if (mounted) {
      setState(() {
        _tipoVehiculo = tipo;
        _isLoadingType = false;
      });
    }
  }

  Future<void> _takePicture() async {
    final Uint8List? bytes = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomCameraView(mode: CameraMode.fullScreen),
      ),
    );
    if (bytes != null) {
      final compressed = await _imageHelper.compressBytes(bytes, quality: 80);
      setState(() => _capturedBytes = compressed ?? bytes);
    }
  }

  Future<void> _confirmAndUpload() async {
    if (_capturedBytes == null) return;
    setState(() => _isUploading = true);

    try {
      final imageBase64 = base64Encode(_capturedBytes!);

      await _registroService.actualizarFoto(
        registroId: widget.registroId,
        fotoBase64: imageBase64,
        tipo: widget.photoType,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto del documento guardada.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => VehicleDataView(registroId: widget.registroId),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la foto: ${e.toString()}')),
        );
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const StepHeader(
              currentStep: 4,
              title: 'Documento de Transporte',
              subtitle: 'Captura el Bill of Lading o Guía de Despacho.',
            ),
            _buildInstructionCard(
              "Por favor, captura una foto clara del documento de transporte (BL o Guía).",
            ),
            if (_tipoVehiculo == 'Vehiculo Menor') ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _hasNoBL = !_hasNoBL;
                    if (_hasNoBL) {
                      _capturedBytes = null;
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _hasNoBL ? AppColors.accent.withAlpha(26) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hasNoBL ? AppColors.accent : AppColors.border,
                      width: _hasNoBL ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasNoBL ? Icons.check_box : Icons.check_box_outline_blank,
                        color: _hasNoBL ? AppColors.accent : AppColors.textSecondary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "No aplica / No tengo BL",
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            IgnorePointer(
              ignoring: _hasNoBL,
              child: Opacity(
                opacity: _hasNoBL ? 0.4 : 1.0,
                child: _buildPhotoCard(
                  "Documento (BL)",
                  "Toca para capturar",
                  _capturedBytes,
                  Icons.description,
                  _takePicture,
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_isUploading || _isLoadingType)
              Column(
                children: [
                  const CircularProgressIndicator(color: AppColors.accent),
                  const SizedBox(height: 16),
                  Text(
                    _isUploading ? "Guardando documento..." : "Cargando...",
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else if (_capturedBytes != null)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _confirmAndUpload,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    "CONFIRMAR DOCUMENTO",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              )
            else if (_hasNoBL)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => VehicleDataView(registroId: widget.registroId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text(
                    "CONTINUAR SIN BL",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.accent, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(
    String title,
    String subtitle,
    Uint8List? bytes,
    IconData icon,
    VoidCallback onTap,
  ) {
    final bool hasImage = bytes != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage ? AppColors.accent : AppColors.border,
            width: hasImage ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                Image.memory(bytes, fit: BoxFit.cover)
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 40,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              if (hasImage)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, size: 20, color: AppColors.accent),
                  ),
                ),
              if (hasImage)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: AppColors.background26,
                    child: Text(
                      title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
