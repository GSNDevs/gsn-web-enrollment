import 'package:prueba_match/utils/app_colors.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:prueba_match/models/chofer_match_data.dart';
import 'package:prueba_match/services/face_match_service.dart';
import 'package:prueba_match/views/confirmation_view.dart';
import 'package:prueba_match/views/custom_camera_view.dart';

class FaceMatchScreen extends StatefulWidget {
  final int registroId;

  const FaceMatchScreen({
    super.key,
    required this.registroId,
  });

  @override
  State<FaceMatchScreen> createState() => _FaceMatchScreenState();
}

class _FaceMatchScreenState extends State<FaceMatchScreen> {
  final FaceMatchService _faceMatchService = FaceMatchService();

  // Bytes de imágenes
  Uint8List? _selfieBytes;
  Uint8List? _documentBytes;

  // State
  bool _isProcessing = false;
  String? _statusMessage;

  Future<void> _pickPhoto(bool isSelfie) async {
    final Uint8List? bytes = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomCameraView(mode: isSelfie ? CameraMode.selfie : CameraMode.document),
      ),
    );
    if (bytes != null) {
      // Los bytes ya vienen optimizados desde CustomCameraView
      // (redimensionados + comprimidos en un isolate)
      setState(() {
        if (isSelfie) {
          _selfieBytes = bytes;
        } else {
          _documentBytes = bytes;
        }
      });
    }
  }

  Future<void> _process() async {
    // Validation
    if (_selfieBytes == null) {
      _showSnack("Debes capturar la selfie.");
      return;
    }
    if (_documentBytes == null) {
      _showSnack("Debes capturar el documento.");
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Procesando...";
    });

    try {
      // FULL VERIFICATION (Match + OCR)
      final response = await _faceMatchService.fullVerification(
        documentBytes: _documentBytes!,
        selfieBytes: _selfieBytes!,
      );

      final data = response['data'];
      final bool verified = data['identity_verified'] ?? false;
      final docData = data['document'];
      final matchData = data['face_match'];

      if (!verified) {
        final sim = matchData?['similarity_percentage'] ?? 0;
        _showSnack("Identidad no verificada. Similitud: $sim%");
        return;
      }

      // Convert bytes to Base64
      final String livenessImageBase64 = base64Encode(_selfieBytes!);
      final String idFaceBase64 = base64Encode(_documentBytes!);

      // Map to ChoferMatchData
      final ocrData = ChoferMatchData(
        nombres: docData['nombres'],
        apellidos: docData['apellidos'],
        run: docData['rut'],
        nacionalidad: docData['nacionalidad'],
        sexo: docData['sexo'],
        fechaEmision: docData['fecha_emision'],
        fechaNacimiento: docData['fecha_nacimiento'],
        fechaVencimiento: docData['fecha_vencimiento'],
        numeroDocumento: docData['numero_documento'],
        fotoMatch: livenessImageBase64,
        fotoCaraCarnet: idFaceBase64,
      );

      if (!mounted) return;

      // Navigate to ConfirmationView
      final ChoferMatchData? confirmedData = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConfirmationView(
            initialData: ocrData,
            registroId: widget.registroId,
          ),
        ),
      );

      // If verified, pop with success data
      if (confirmedData != null && mounted) {
        Navigator.pop(context, confirmedData);
      }
    } catch (e) {
      _showSnack("Error: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = null;
        });
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    const String title = "Verificación Facial";
    const String instruction = "Por favor, captura una selfie clara y una foto de tu documento de identidad.";

    return Scaffold(
      appBar: AppBar(
        title: const Text(title),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInstructionCard(instruction),
            const SizedBox(height: 24),
            _buildPhotoCard(
              "Selfie",
              "Toca para capturar",
              _selfieBytes,
              Icons.face_retouching_natural,
              () => _pickPhoto(true),
            ),
            const SizedBox(height: 16),
            _buildPhotoCard(
              "Carnet / Documento",
              "Toca para capturar",
              _documentBytes,
              Icons.credit_card,
              () => _pickPhoto(false),
            ),
            const SizedBox(height: 32),
            if (_isProcessing)
              Column(
                children: [
                  const CircularProgressIndicator(color: AppColors.accent),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage ?? "Procesando...",
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _process,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    "VALIDAR IDENTIDAD",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
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
