import 'package:prueba_match/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:prueba_match/services/registro_service.dart';
import 'package:prueba_match/views/dangerous_cargo_view.dart';
import 'package:prueba_match/widgets/step_header.dart';

class VehicleDataView extends StatefulWidget {
  final int registroId;

  const VehicleDataView({super.key, required this.registroId});

  @override
  State<VehicleDataView> createState() => _VehicleDataViewState();
}

class _VehicleDataViewState extends State<VehicleDataView> {
  final _formKey = GlobalKey<FormState>();
  final _patenteController = TextEditingController();
  final _containerController = TextEditingController();
  final _registroService = RegistroService();

  bool _isLoading = false;

  @override
  void dispose() {
    _patenteController.dispose();
    _containerController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _registroService.actualizarDatosVehiculo(
        registroId: widget.registroId,
        patente: _patenteController.text.trim(),
        container: _containerController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              DangerousCargoView(registroId: widget.registroId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar los datos: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepHeader(
                currentStep: 5,
                title: 'Datos del Vehículo',
                subtitle: 'Ingrese los identificadores del vehículo y la carga.',
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _patenteController,
                decoration: const InputDecoration(
                  labelText: 'Patente del Vehículo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.abc),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Este campo es obligatorio.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _containerController,
                decoration: const InputDecoration(
                  labelText: 'Identificador del Container',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Este campo es obligatorio.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.accent, // Acento
                    foregroundColor: AppColors.background, // Texto contrastante
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Guardar y Continuar'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
