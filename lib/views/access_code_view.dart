import 'package:prueba_match/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:prueba_match/services/registro_service.dart';
import 'package:prueba_match/views/vehicle_selection_view.dart';

class AccessCodeView extends StatefulWidget {
  const AccessCodeView({super.key});

  @override
  @override
  State<AccessCodeView> createState() => _AccessCodeViewState();
}

class _AccessCodeViewState extends State<AccessCodeView> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _registroService = RegistroService();

  @override
  void initState() {
    super.initState();
  }

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _validateCode() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final codigo = _codeController.text.trim();
      final registroId = await _registroService.getRegistroIdPorCodigo(codigo);

      if (registroId != null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  VehicleSelectionView(registroId: registroId),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage =
              'El código de acceso no es válido o no fue encontrado.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Ocurrió un error: ${e.toString().replaceAll('Exception: ', '')}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.background, // Fondo principal
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Validación de Acceso',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingrese su código para comenzar.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              // Logo / Icono Principal
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 60,
                    color: AppColors.accent, // Icono destacado
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Tarjeta de Formulario
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),

                        // Input
                        TextFormField(
                          controller: _codeController,
                          style: const TextStyle(fontSize: 18),
                          decoration: InputDecoration(
                            labelText: 'Código de Acceso',
                            prefixIcon: const Icon(Icons.vpn_key),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.accent, width: 2),
                            ),
                            filled: true,
                            fillColor: AppColors.background, // Contraste contra tarjeta surface
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Este campo es requerido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Mensaje de Error
                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.1), // Fondo error claro
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.danger),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppColors.danger,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Botón
                        if (_isLoading)
                          const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accent, // Indicador de proceso
                            ),
                          )
                        else
                          ElevatedButton(
                            onPressed: _validateCode,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppColors.accent, // Botones primarios
                              foregroundColor: AppColors.background, // Texto sobre el cyan (mejor contraste)
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Validar e Iniciar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
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
