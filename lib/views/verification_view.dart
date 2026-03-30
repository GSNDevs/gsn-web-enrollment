import 'package:prueba_match/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:prueba_match/models/chofer_match_data.dart';
import 'package:prueba_match/screens/face_match_screen.dart';
import 'package:prueba_match/services/registro_service.dart';
import 'package:prueba_match/views/id_scan_view.dart';
import 'package:prueba_match/views/transport_document_view.dart';
import 'package:prueba_match/widgets/step_header.dart';
// import '../facetec_service.dart'; // FACETEC EXCLUDED

enum VerificationStatus {
  cargando,
  necesitaVerificacion,
  verificacionCompleta,
  error,
}

class VerificationView extends StatefulWidget {
  final int registroId;
  const VerificationView({super.key, required this.registroId});

  @override
  State<VerificationView> createState() => _VerificationViewState();
}

class _VerificationViewState extends State<VerificationView> {
  // final FaceTecService _facetecService = FaceTecService(); // FACETEC EXCLUDED
  final RegistroService _registroService = RegistroService();
  VerificationStatus _status = VerificationStatus.cargando;
  String _statusMessage = 'Verificando estado del chofer...';
  Color _statusColor = AppColors.background;

  @override
  void initState() {
    super.initState();
    _realizarChequeoInicial();
  }

  Future<void> _realizarChequeoInicial() async {
    try {
      final rut = await _registroService.getRutParaValidar(widget.registroId);
      if (rut == null || rut.isEmpty) {
        setState(() {
          _status = VerificationStatus.necesitaVerificacion;
          _statusMessage =
              'No se encontró RUT para validar. Inicie la verificación manual.';
          _statusColor = AppColors.warning;
        });
        return;
      }

      final resultado = await _registroService.verificarEstadoChofer(rut);

      if (resultado.estado == EstadoVerificacionChofer.valido) {
        setState(() {
          _statusMessage =
              'Chofer ya verificado. Se procederá a escanear la licencia.';
          _statusColor = AppColors.success;
        });

        // --- CORRECCIÓN PRINCIPAL ---
        // 1. Asocia el chofer existente a este nuevo registro de visita.
        final choferId = resultado.datosChofer!['id_chofer'] as int;
        await _registroService.asociarChoferARegistro(
          widget.registroId,
          choferId,
        );

        // 2. Convierte los datos del chofer obtenidos de la DB a nuestro modelo.
        final datosChoferDesdeDB = ChoferMatchData.fromDbMap(
          resultado.datosChofer!,
        );

        // 3. Verifica estado de la licencia asociada
        final resultLicencia = await _registroService.verificarEstadoLicencia(choferId);
        
        // 4. Espera un momento y navega a la siguiente pantalla correcta.
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          if (resultLicencia.estado == EstadoVerificacionChofer.valido) {
            // Chofer y licencia válidos -> Saltamos directo a fotos de container
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => TransportDocumentView(
                  registroId: widget.registroId,
                  photoType: PhotoType.bl, 
                 ),
              ),
            );
          } else {
            // Licencia no existe o está vencida -> Ir a escaneo
            setState(() {
              _statusMessage = 'Licencia no válida o no encontrada. Preparando escáner...';
            });
            await Future.delayed(const Duration(seconds: 1));
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => IDScanView(
                    registroId: widget.registroId,
                    datosChoferCarnet: datosChoferDesdeDB,
                  ),
                ),
              );
            }
          }
        }
      } else {
        String message;
        switch (resultado.estado) {
          case EstadoVerificacionChofer.noExiste:
            message = 'Chofer no encontrado. Inicie la verificación.';
            break;
          case EstadoVerificacionChofer.vencido:
            message = 'Verificación expirada. Inicie el proceso de nuevo.';
            break;
          default:
            message = 'Error de validación. Inicie la verificación.';
            break;
        }
        setState(() {
          _status = VerificationStatus.necesitaVerificacion;
          _statusMessage = message;
          _statusColor = AppColors.warning; // Warning for pending/failed status
        });
      }
    } catch (e) {
      setState(() {
        _status = VerificationStatus.error;
        _statusMessage = 'Error crítico al verificar: ${e.toString()}';
        _statusColor = AppColors.danger;
      });
    }
  }

  // Method continues...

  // ... (existing imports)

  // ... (inside class)

  Future<void> _startVerification() async {
    // Navigate to FaceMatchScreen and wait for result
    final ChoferMatchData? confirmedData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceMatchScreen(
          registroId: widget.registroId,
        ),
      ),
    );

    // If verification was successful and confirmed
    if (confirmedData != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IDScanView(
            registroId: widget.registroId,
            datosChoferCarnet: confirmedData,
          ),
        ),
      );
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const StepHeader(
              currentStep: 2,
              title: 'Verificación de Identidad',
              subtitle: 'Verificaremos tu identidad mediante reconocimiento facial.',
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _statusColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _status == VerificationStatus.cargando
                              ? Icons.hourglass_empty
                              : Icons.info_outline,
                          size: 40,
                          color: _statusColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary, // Texto claro
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(height: 32),
              _buildMainContent(),
            ],
          ),
        ),
      ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_status) {
      case VerificationStatus.cargando:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.accent), // Indicador primario
        );
      case VerificationStatus.necesitaVerificacion:
      case VerificationStatus.error:
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _startVerification,
            icon: const Icon(Icons.face_retouching_natural),
            label: const Text('INICIAR VERIFICACIÓN'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent, // Cian primario
              foregroundColor: AppColors.background, // Texto contrastante
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      case VerificationStatus.verificacionCompleta:
        return const SizedBox.shrink();
    }
  }
}
