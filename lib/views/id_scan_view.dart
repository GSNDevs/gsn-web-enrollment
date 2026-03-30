import 'package:prueba_match/utils/app_colors.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:prueba_match/models/license_data.dart';
import 'package:prueba_match/models/chofer_match_data.dart';
import 'package:prueba_match/services/registro_service.dart';
import 'package:prueba_match/widgets/step_header.dart';
import 'package:prueba_match/views/transport_document_view.dart';
import 'package:prueba_match/screens/license_scan_screen.dart';

class IDScanView extends StatefulWidget {
  final int registroId;
  final ChoferMatchData datosChoferCarnet;

  const IDScanView({
    super.key,
    required this.registroId,
    required this.datosChoferCarnet,
  });

  @override
  State<IDScanView> createState() => _IDScanViewState();
}

class _IDScanViewState extends State<IDScanView> {
  final RegistroService _registroService = RegistroService();
  // final FaceTecService _facetecService = FaceTecService(); // FACETEC EXCLUDED
  bool _isLoading = false;
  String _statusMessage =
      'A continuación, escanea la licencia de conducir para validarla.';
  Color _statusColor = AppColors.textSecondary;

  Future<void> _scanLicense() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Iniciando escaneo de licencia...';
      _statusColor = AppColors.accent;
    });

    try {
      // 1. Navegar a LicenseScanScreen y esperar resultado
      final LicenseData? confirmedData = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LicenseScanScreen(
            registroId: widget.registroId,
            existingChoferData: widget.datosChoferCarnet,
          ),
        ),
      );

      // 2. Si se confirmó el escaneo
      if (confirmedData != null) {
        setState(() {
          _statusMessage = 'Guardando datos de la licencia...';
        });

        // 3. Guardar en servicio
        await _registroService.guardarDatosLicenciaEscaneada(
          widget.datosChoferCarnet.run!,
          confirmedData,
        );

        setState(() {
          _statusMessage = '✅ ¡Validación completada! Avanzando...';
          _statusColor = AppColors.success;
        });

        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => TransportDocumentView(
                registroId: widget.registroId,
                photoType: PhotoType.bl,
              ),
            ),
          );
        }
      } else {
        setState(() {
          _statusMessage = 'Proceso de escaneo cancelado.';
          _statusColor = AppColors.warning;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'ERROR en el escaneo:\n${e.toString()}';
        _statusColor = AppColors.danger;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StepHeader(
              currentStep: 3,
              title: 'Escaneo de Licencia',
              subtitle: 'Por favor, escanea tu licencia de conducir para validarla.',
            ),
            _buildTipsCard(),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8.0),
                color: AppColors.surface,
              ),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: _statusColor),
              ),
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppColors.accent))
            else
              ElevatedButton.icon(
                onPressed: _scanLicense,
                icon: const Icon(Icons.document_scanner),
                label: const Text('ESCANEAR LICENCIA'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.accent, // Acento botón primario
                  foregroundColor: AppColors.background, // Texto contrastante interior
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Consejos para un buen escaneo:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildTipRow('Asegúrate de que la licencia esté vigente.'),
            const SizedBox(height: 12),
            _buildTipRow('Ilumina bien el documento.'),
            const SizedBox(height: 12),
            _buildTipRow('Evita reflejos o sombras sobre la licencia.'),
          ],
        ),
      ),
    );
  }

  Widget _buildTipRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: AppColors.success, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
