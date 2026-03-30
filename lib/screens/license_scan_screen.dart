import 'package:prueba_match/utils/app_colors.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:prueba_match/models/chofer_match_data.dart';
import 'package:prueba_match/services/face_match_service.dart';
import 'package:prueba_match/utils/image_helper.dart';
import 'package:prueba_match/utils/rut_utils.dart';
import 'package:prueba_match/models/license_data.dart';
import 'package:prueba_match/views/license_confirmation_view.dart';
import 'package:prueba_match/views/custom_camera_view.dart';

class LicenseScanScreen extends StatefulWidget {
  final int registroId;
  final ChoferMatchData? existingChoferData;

  const LicenseScanScreen({
    super.key,
    required this.registroId,
    this.existingChoferData,
  });

  @override
  State<LicenseScanScreen> createState() => _LicenseScanScreenState();
}

class _LicenseScanScreenState extends State<LicenseScanScreen> {
  final FaceMatchService _faceMatchService = FaceMatchService();
  final ImageHelper _imageHelper = ImageHelper();

  // Bytes de imagen
  Uint8List? _documentBytes;

  // State
  bool _isProcessing = false;
  String? _statusMessage;

  Future<void> _pickPhoto() async {
    final Uint8List? bytes = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomCameraView(mode: CameraMode.document),
      ),
    );
    if (bytes != null) {
      final compressed = await _imageHelper.compressBytes(bytes, quality: 80);
      setState(() {
        _documentBytes = compressed ?? bytes;
      });
    }
  }

  DateTime? _parseExpirationDate(String? sourceDate) {
    if (sourceDate == null || sourceDate.isEmpty) return null;
    try {
      const monthMap = {
        'ENE': 1, 'FEB': 2, 'MAR': 3, 'ABR': 4, 'MAY': 5, 'JUN': 6,
        'JUL': 7, 'AGO': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DIC': 12,
        'JAN': 1, 'APR': 4, 'AUG': 8, 'DEC': 12,
      };

      final parts = sourceDate.trim().split(RegExp(r'[\s./-]+'));
      
      if (parts.length == 3) {
        int year, month, day;

        if (parts[0].length == 4) {
          year = int.parse(parts[0]);
          month = monthMap[parts[1].toUpperCase()] ?? int.parse(parts[1]);
          day = int.parse(parts[2]);
        } else {
          day = int.parse(parts[0]);
          month = monthMap[parts[1].toUpperCase()] ?? int.parse(parts[1]);
          year = parts[2].length == 2 ? int.parse('20${parts[2]}') : int.parse(parts[2]);
        }
        return DateTime(year, month, day);
      }
    } catch (e) {
      // Ignorar errores de parseo por OCR
    }
    return null;
  }

  Future<void> _process() async {
    // Validation
    if (_documentBytes == null) {
      _showSnack("Debes capturar el documento.");
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Procesando...";
    });

    try {
      // SCAN ONLY (OCR)
      final response = await _faceMatchService.processOCR(_documentBytes!);
      final data = response['data'];
      
      final String licenseRut = data['rut']?.toString() ?? '';
      final String? expectedRut = widget.existingChoferData?.run;
      final String? fechaControl = data['fecha_ultimo_control']?.toString();
      
      if (expectedRut != null && RutUtils.clean(licenseRut) != RutUtils.clean(expectedRut)) {
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                 Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
                 SizedBox(width: 8),
                 Expanded(child: Text('RUT no coincide', style: TextStyle(color: AppColors.textPrimary))),
              ],
            ),
            content: const Text(
              'La licencia escaneada no corresponde al conductor registrado. Por favor, asegúrese de escanear la licencia correcta.',
              style: TextStyle(color: AppColors.textPrimary70),
            ),
            backgroundColor: AppColors.surface,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text(
                  'ESCANEAR DE NUEVO',
                  style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
        
        if (mounted) {
          setState(() {
            _documentBytes = null;
          });
        }
        return;
      }

      if (fechaControl == null || fechaControl.trim().isEmpty) {
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                 Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
                 SizedBox(width: 8),
                 Expanded(child: Text('Fecha no detectada', style: TextStyle(color: AppColors.textPrimary))),
              ],
            ),
            content: const Text(
              'No se pudo extraer la fecha de emisión de la licencia. Por favor, asegúrese de escanear la licencia claramente, sin reflejos ni sombras.',
              style: TextStyle(color: AppColors.textPrimary70),
            ),
            backgroundColor: AppColors.surface,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text(
                  'ESCANEAR DE NUEVO',
                  style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
        
        if (mounted) {
          setState(() {
            _documentBytes = null;
          });
        }
        return;
      }

      // Vencimiento validation
      final String? fechaVencimiento = data['fecha_vencimiento']?.toString();
      final DateTime? parsedVencimiento = _parseExpirationDate(fechaVencimiento);
      
      if (parsedVencimiento != null) {
        final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        
        if (parsedVencimiento.isBefore(today)) {
          if (!mounted) return;
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                   Icon(Icons.block, color: AppColors.danger, size: 28),
                   SizedBox(width: 8),
                   Expanded(child: Text('Licencia Vencida', style: TextStyle(color: AppColors.textPrimary))),
                ],
              ),
              content: const Text(
                'La licencia escaneada se encuentra vencida. No es posible autorizar el ingreso con una licencia expirada.',
                style: TextStyle(color: AppColors.textPrimary70),
              ),
              backgroundColor: AppColors.surface,
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  child: const Text(
                    'ESCANEAR DE NUEVO',
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
          
          if (mounted) {
            setState(() {
              _documentBytes = null;
            });
          }
          return;
        }
      }

      final String frontImageBase64 = base64Encode(_documentBytes!);

      final licenseData = LicenseData(
        rut: data['rut'],
        nombres: data['nombres'],
        apellidos: data['apellidos'],
        fechaNacimiento: data['fecha_nacimiento'],
        fechaEmision: data['fecha_ultimo_control'],
        fechaVencimiento: data['fecha_vencimiento'],
        clase: data['clase_licencia'],
        direccion: data['domicilio'],
        fotoLicencia: frontImageBase64,
      );

      if (!mounted) return;

      // Navigate to LicenseConfirmationView
      final LicenseData? confirmedData = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LicenseConfirmationView(
            initialData: licenseData,
            registroId: widget.registroId,
          ),
        ),
      );

      // If verified, pop with success data
      if (confirmedData != null && mounted) {
        Navigator.pop(context, confirmedData);
      }
    } catch (e) {
      _showSnack("Error en el proceso: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const String title = "Escaneo de Licencia";
    const String instruction = "Captura una foto clara de la licencia de conducir.";

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(title, style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildInstructionCard(instruction),
            const SizedBox(height: 24),
            _buildPhotoCard(
              "Licencia de Conducir",
              "Toca para capturar",
              _documentBytes,
              Icons.credit_card,
              () => _pickPhoto(),
            ),
            const SizedBox(height: 32),
            if (_isProcessing)
              Column(
                children: [
                  const CircularProgressIndicator(color: AppColors.accent),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage ?? 'Procesando...',
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
                  onPressed: _documentBytes != null ? _process : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    'VALIDAR LICENCIA',
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
                      style: const TextStyle(
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
