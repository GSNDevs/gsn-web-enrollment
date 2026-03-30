import 'package:prueba_match/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:prueba_match/services/registro_service.dart';
import 'package:prueba_match/views/scheduling_view.dart';
import 'package:prueba_match/widgets/step_header.dart';

class DangerousCargoView extends StatefulWidget {
  final int registroId;

  const DangerousCargoView({super.key, required this.registroId});

  @override
  State<DangerousCargoView> createState() => _DangerousCargoViewState();
}

class _DangerousCargoViewState extends State<DangerousCargoView> {
  final RegistroService _registroService = RegistroService();
  bool _isLoading = false;

  /// Guarda la selección del usuario y navega a la pantalla de agendamiento.
  Future<void> _selectOption(bool isDangerous) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _registroService.actualizarCargaPeligrosa(
        registroId: widget.registroId,
        esPeligrosa: isDangerous,
      );

      if (!mounted) return;

      // Navega a la nueva pantalla de agendamiento en lugar de finalizar.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SchedulingView(registroId: widget.registroId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la selección: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
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
        automaticallyImplyLeading: false, // Oculta el botón de retroceso
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const StepHeader(
                    currentStep: 6,
                    title: 'Información de Carga',
                    subtitle: 'Indique si la carga que transporta es peligrosa.',
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    '¿La carga es peligrosa?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),
                  // Botón para "Sí"
                  ElevatedButton(
                    onPressed: () => _selectOption(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Sí'),
                  ),
                  const SizedBox(height: 20),
                  // Botón para "NO"
                  ElevatedButton(
                    onPressed: () => _selectOption(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('NO'),
                  ),
                ],
              ),
            ),
    );
  }
}
