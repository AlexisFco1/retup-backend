import 'package:flutter/material.dart';
import 'package:retup_mobile_flutter/models/pildora_model.dart';
import 'package:retup_mobile_flutter/models/pill_progress_model.dart';
import 'package:retup_mobile_flutter/services/pildoras_service.dart';
import 'package:retup_mobile_flutter/services/progress_service.dart';

class PildoraProvider extends ChangeNotifier {
  final PillorasService _pillorasService = PillorasService();
  final ProgressService _progressService = ProgressService();

  List<Pildora> _pildoras = [];
  Pildora? _pildoraSeleccionada;
  PillProgress? _progressoActual;
  int _seccionActual = 1;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Pildora> get pildoras => _pildoras;
  Pildora? get pildoraSeleccionada => _pildoraSeleccionada;
  PillProgress? get progresoActual => _progressoActual;
  int get seccionActual => _seccionActual;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Cargar píldoras de un reto desde el backend
  Future<void> cargarPildorasDelReto(String retoId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _pillorasService.getByRetoId(retoId);
      _pildoras = response;

      // Seleccionar la primera píldora si hay
      if (_pildoras.isNotEmpty) {
        _pildoraSeleccionada = _pildoras[0];
        _seccionActual = 1;
      }
    } catch (error) {
      _errorMessage = 'Error al cargar píldoras: $error';
      print('Error loading pills: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Seleccionar una píldora y cargar su progreso
  Future<void> seleccionarPildora(Pildora pildora, String userId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _pildoraSeleccionada = pildora;
      _seccionActual = 1;

      // Obtener el progreso de esta píldora
      final progress =
          await _progressService.getPillProgress(userId, pildora.id);

      if (progress != null) {
        _progressoActual = progress;
        _seccionActual = progress.currentScreen;
      } else {
        // Crear un nuevo progreso si no existe
        await _progressService.createPillProgress(userId, pildora.id);
        _progressoActual =
            await _progressService.getPillProgress(userId, pildora.id);
      }
    } catch (error) {
      _errorMessage = 'Error al seleccionar píldora: $error';
      print('Error selecting pill: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Ir a la siguiente sección dentro de la píldora
  void irASiguiente() {
    if (_seccionActual < 9) {
      _seccionActual++;
      notifyListeners();
    }
  }

  // Ir a la sección anterior
  void irAlAnterior() {
    if (_seccionActual > 1) {
      _seccionActual--;
      notifyListeners();
    }
  }

  // Completar píldora
  Future<bool> completarPildora() async {
    if (_progressoActual == null) {
      _errorMessage = 'No hay progreso registrado';
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Guardar en backend
      final success = await _progressService.completePill(_progressoActual!.id);

      if (success) {
        _progressoActual = PillProgress(
          id: _progressoActual!.id,
          userId: _progressoActual!.userId,
          pillId: _progressoActual!.pillId,
          currentScreen: 9,
          selfAssessmentScore: _progressoActual!.selfAssessmentScore,
          isCompleted: true,
          completedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Pasar a la siguiente píldora
        final indexActual = _pildoras.indexOf(_pildoraSeleccionada!);
        if (indexActual < _pildoras.length - 1) {
          _pildoraSeleccionada = _pildoras[indexActual + 1];
          _seccionActual = 1;
          _progressoActual = null;
        } else {
          // No hay más píldoras
          _pildoraSeleccionada = null;
          _progressoActual = null;
        }
      }

      return success;
    } catch (error) {
      _errorMessage = 'Error al completar píldora: $error';
      print('Error completing pill: $error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Obtener el índice de la píldora actual
  int get indicePildoraActual {
    if (_pildoraSeleccionada == null) return 0;
    return _pildoras.indexOf(_pildoraSeleccionada!) + 1;
  }

  // Obtener total de píldoras
  int get totalPildoras => _pildoras.length;
}
