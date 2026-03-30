import 'package:prueba_match/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:prueba_match/models/chofer_match_data.dart';
import 'package:prueba_match/services/registro_service.dart';
import 'package:prueba_match/utils/rut_utils.dart';
import 'package:prueba_match/views/id_scan_view.dart';
import 'package:prueba_match/widgets/step_header.dart';
import 'package:prueba_match/utils/document_utils.dart';
import 'package:flutter/services.dart';

class ConfirmationView extends StatefulWidget {
  final ChoferMatchData initialData;
  final int registroId;

  const ConfirmationView({
    super.key,
    required this.initialData,
    required this.registroId,
  });

  @override
  State<ConfirmationView> createState() => _ConfirmationViewState();
}

class _ConfirmationViewState extends State<ConfirmationView> {
  final _formKey = GlobalKey<FormState>();
  final RegistroService _registroService = RegistroService();

  bool _isLoading = false;

  late final TextEditingController _nombresController;
  late final TextEditingController _apellidosController;
  late final TextEditingController _runController;
  late final TextEditingController _numeroDocumentoController;
  late final TextEditingController _nacionalidadController;
  late final TextEditingController _fechaNacimientoController;
  late final TextEditingController _fechaEmisionController;
  late final TextEditingController _fechaVencimientoController;
  late final TextEditingController _sexoController;

  String? _formatDateForUI(String? sourceDate) {
    if (sourceDate == null || sourceDate.isEmpty) return sourceDate;
    
    const monthMap = {
      'ENE': '01', 'FEB': '02', 'MAR': '03', 'ABR': '04', 'MAY': '05', 'JUN': '06',
      'JUL': '07', 'AGO': '08', 'SEP': '09', 'OCT': '10', 'NOV': '11', 'DIC': '12',
      'JAN': '01', 'APR': '04', 'AUG': '08', 'DEC': '12',
    };

    final parts = sourceDate.trim().split(RegExp(r'[\s./-]+'));
    
    if (parts.length == 3) {
      String day, monthNum, year;

      if (parts[0].length == 4) {
        // Formato yyyy-MM-dd
        year = parts[0];
        monthNum = monthMap[parts[1].toUpperCase()] ?? parts[1].padLeft(2, '0');
        day = parts[2].padLeft(2, '0');
      } else {
        // Formato dd-MM-yyyy o similar
        day = parts[0].padLeft(2, '0');
        monthNum = monthMap[parts[1].toUpperCase()] ?? parts[1].padLeft(2, '0');
        year = parts[2].length == 2 ? '20${parts[2]}' : parts[2];
      }

      return '$day/$monthNum/$year';
    }

    return sourceDate;
  }

  @override
  void initState() {
    super.initState();
    _nombresController = TextEditingController(
      text: widget.initialData.nombres,
    );
    _apellidosController = TextEditingController(
      text: widget.initialData.apellidos,
    );
    _runController = TextEditingController(text: widget.initialData.run);
    _numeroDocumentoController = TextEditingController(
      text: widget.initialData.numeroDocumento,
    );
    _nacionalidadController = TextEditingController(
      text: widget.initialData.nacionalidad,
    );
    _fechaNacimientoController = TextEditingController(
      text: _formatDateForUI(widget.initialData.fechaNacimiento),
    );
    _fechaEmisionController = TextEditingController(
      text: _formatDateForUI(widget.initialData.fechaEmision),
    );
    _fechaVencimientoController = TextEditingController(
      text: _formatDateForUI(widget.initialData.fechaVencimiento),
    );
    _sexoController = TextEditingController(text: widget.initialData.sexo);
  }

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _runController.dispose();
    _numeroDocumentoController.dispose();
    _nacionalidadController.dispose();
    _fechaNacimientoController.dispose();
    _fechaEmisionController.dispose();
    _fechaVencimientoController.dispose();
    _sexoController.dispose();
    super.dispose();
  }

  Future<void> _onConfirmAndSave() async {
    if (_formKey.currentState!.validate() == false) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final confirmedData = widget.initialData.copyWith(
        nombres: _nombresController.text,
        apellidos: _apellidosController.text,
        run: _runController.text,
        numeroDocumento: _numeroDocumentoController.text,
        nacionalidad: _nacionalidadController.text,
        fechaNacimiento: _fechaNacimientoController.text,
        fechaEmision: _fechaEmisionController.text,
        fechaVencimiento: _fechaVencimientoController.text,
        sexo: _sexoController.text,
      );

      // Guardamos los datos en Supabase antes de continuar
      await _registroService.procesarDatosVerificacion(
        widget.registroId,
        confirmedData,
      );

      if (!mounted) return;

      // Navegamos a la siguiente pantalla
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => IDScanView(
            registroId: widget.registroId,
            datosChoferCarnet: confirmedData,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar los datos: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
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
      backgroundColor: AppColors.background, // Fondo principal
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepHeader(
                currentStep: 3,
                title: 'Datos del Carnet',
                subtitle: 'Revisa y confirma la información extraída de tu documento.',
              ),
              _buildInstructionCard(),
              const SizedBox(height: 24),

              _buildSectionCard("Datos Personales", [
                _buildTextFormField(
                  controller: _nombresController,
                  label: 'Nombres',
                ),
                _buildTextFormField(
                  controller: _apellidosController,
                  label: 'Apellidos',
                ),
                _buildTextFormField(
                  controller: _fechaNacimientoController,
                  label: 'Fecha de Nacimiento',
                ),
                _buildTextFormField(
                  controller: _nacionalidadController,
                  label: 'Nacionalidad',
                ),
                _buildTextFormField(
                  controller: _sexoController,
                  label: 'Sexo',
                ),
              ]),

              const SizedBox(height: 16),

              _buildSectionCard("Datos del Documento", [
                _buildTextFormField(
                  controller: _runController,
                  label: 'RUN (RUT)',
                ),
                _buildTextFormField(
                  controller: _numeroDocumentoController,
                  label: 'N° de Documento',
                ),
                _buildTextFormField(
                  controller: _fechaEmisionController,
                  label: 'Fecha de Emisión',
                ),
                _buildTextFormField(
                  controller: _fechaVencimientoController,
                  label: 'Fecha de Vencimiento',
                ),
              ]),

              const SizedBox(height: 32),

              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.accent), // Acento
                )
              else
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _onConfirmAndSave,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('CONFIRMAR Y CONTINUAR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent, // Acento primario
                      foregroundColor: AppColors.background, // Texto interno
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
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, // Superficie dark
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.accent), // Acento
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Por favor, revisa y corrige los datos si es necesario.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary, // Texto principal
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary, // Blanco principal
              ),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
  }) {
    List<TextInputFormatter>? formatters;
    TextInputType keyboardType = TextInputType.text;

    if (label.contains('Fecha')) {
      formatters = [DateTextFormatter()];
      keyboardType = TextInputType.number;
    } else if (label.contains('N° de Documento')) {
      formatters = [DocumentNumberTextFormatter()];
      keyboardType = TextInputType.text;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: label.contains('Fecha') ? 'dd/mm/YYYY' : null,
          helperText: label.contains('Fecha') ? 'Formato: dd/mm/YYYY (Día/Mes/Año)' : null,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: AppColors.background, // Contraste contra tarjeta surface
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Este campo no puede estar vacío';
          }
          if (label.contains('RUN') || label.contains('RUT')) {
            if (!RutUtils.isValid(value)) {
              return 'RUT inválido';
            }
          }
          return null;
        },
      ),
    );
  }
}
