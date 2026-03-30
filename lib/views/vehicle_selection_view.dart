import 'package:prueba_match/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:prueba_match/services/registro_service.dart';
import 'package:prueba_match/views/verification_view.dart';
import 'package:prueba_match/widgets/step_header.dart';

class VehicleSelectionView extends StatefulWidget {
  final int registroId;

  const VehicleSelectionView({super.key, required this.registroId});

  @override
  State<VehicleSelectionView> createState() => _VehicleSelectionViewState();
}

class _VehicleSelectionViewState extends State<VehicleSelectionView> {
  final _registroService = RegistroService();
  bool _isLoading = false;

  Future<void> _selectVehicleType(String tipoVehiculo) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _registroService.actualizarTipoVehiculo(
        widget.registroId,
        tipoVehiculo,
      );
      if (mounted) {
        // Una vez guardado el tipo, navega a la siguiente pantalla (verificación facial)
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                VerificationView(registroId: widget.registroId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar el tipo de vehículo: ${e.toString()}',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
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
              currentStep: 1,
              title: 'Tipo de Vehículo',
              subtitle: 'Seleccione la categoría de su vehículo.',
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildVehicleButton(
                    context: context,
                    label: 'Ingreso Vehículos Menores',
                    icon: Icons.local_shipping_outlined,
                    onPressed: () => _selectVehicleType('Vehiculo Menor'),
                  ),
                  const SizedBox(height: 24),
                  _buildVehicleButton(
                    context: context,
                    label: 'Ingreso Vehículos Mayores',
                    icon: Icons.fire_truck_outlined,
                    onPressed: () => _selectVehicleType('Vehiculo Mayor'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: AppColors.accent),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Toque para seleccionar",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
