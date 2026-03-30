import 'package:prueba_match/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Importación añadida para DateFormat
import 'package:prueba_match/services/registro_service.dart';
import 'package:prueba_match/views/access_code_view.dart';
import 'package:prueba_match/widgets/step_header.dart';

class SchedulingView extends StatefulWidget {
  final int registroId;
  const SchedulingView({super.key, required this.registroId});

  @override
  State<SchedulingView> createState() => _SchedulingViewState();
}

class _SchedulingViewState extends State<SchedulingView> {
  final RegistroService _registroService = RegistroService();

  DateTime? _selectedDate;
  int? _selectedBlockId;
  List<Map<String, dynamic>> _blocks = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _fetchTimeBlocks();
  }

  Future<void> _fetchTimeBlocks() async {
    try {
      final blocks = await _registroService.getBloquesDisponibles(
        _selectedDate!,
      );
      setState(() {
        _blocks = blocks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error al cargar los bloques horarios.";
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'ES'), // Para mostrar el calendario en español
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveAndFinish() async {
    if (_selectedDate == null || _selectedBlockId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar una fecha y un bloque horario.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _registroService.crearAgendamiento(
        registroId: widget.registroId,
        fecha: _selectedDate!,
        bloqueId: _selectedBlockId!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agendamiento completado con éxito.'),
          backgroundColor: AppColors.success,
        ),
      );

      // Regresa a la pantalla de código de acceso, limpiando todas las demás.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AccessCodeView()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar el agendamiento: ${e.toString()}'),
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
        automaticallyImplyLeading: false,
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.danger),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const StepHeader(
                    currentStep: 7,
                    title: 'Agendar Visita',
                    subtitle: 'Seleccione la fecha y el bloque horario de su llegada.',
                  ),
                  const SizedBox(height: 24),
                  _buildDatePicker(),
                  const SizedBox(height: 24),
                  const Text(
                    'Seleccione un bloque horario:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildTimeBlockGrid(),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _saveAndFinish,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.accent, // Acento primario
                      foregroundColor: AppColors.background, // Texto interno contrastante
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Confirmar y Finalizar'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDatePicker() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fecha Seleccionada',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                Text(
                  _selectedDate == null
                      ? 'No seleccionada'
                      : DateFormat(
                          'EEEE d \'de\' MMMM',
                          'es_ES',
                        ).format(_selectedDate!),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.calendar_today, color: AppColors.accent), // Ícono destacado
              onPressed: _pickDate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBlockGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: _blocks.length,
      itemBuilder: (context, index) {
        final block = _blocks[index];
        final isSelected = _selectedBlockId == block['id_bloque'];

        return ElevatedButton(
          onPressed: () {
            setState(() {
              _selectedBlockId = block['id_bloque'];
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected
                ? AppColors.accent // Acento para bloque seleccionado
                : AppColors.surface, // Superficie para inactivo
            foregroundColor: isSelected
                ? AppColors.background // Texto oscuro sobre acento
                : AppColors.textPrimary, // Blanco sobre superficie
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border), // Borde
            ),
            elevation: isSelected ? 4 : 1,
          ),
          child: Text(
            block['descripcion'],
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}
