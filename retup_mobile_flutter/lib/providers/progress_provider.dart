import 'package:flutter/material.dart';
import 'package:retup_mobile_flutter/models/progress_model.dart';
import 'package:retup_mobile_flutter/services/progress_service.dart';

class ProgressProvider extends ChangeNotifier {
  final ProgressService _progressService = ProgressService();

  UserProgress? _userProgress;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  UserProgress? get userProgress => _userProgress;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Obtener el nivel actual basado en XP
  int get nivelActual {
    if (_userProgress == null) return 1;
    return (_userProgress!.xp ~/ 100) + 1;
  }

  // Obtener XP para el siguiente nivel
  int get xpParaSiguienteNivel {
    if (_userProgress == null) return 100;
    int nivelActualValue = nivelActual;
    return (nivelActualValue * 100) - (_userProgress!.xp % 100);
  }

  // Cargar progreso del usuario (recibe int userId)
  Future<void> cargarProgreso(int userId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _progressService.getUserProgress(userId);
      _userProgress = response;
    } catch (error) {
      _errorMessage = 'Error al cargar el progreso: $error';
      print('Error loading progress: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Actualizar el progreso manualmente
  Future<void> actualizarProgreso() async {
    if (_userProgress == null) return;

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final success = await _progressService.updateProgress(
        _userProgress!.id,
        {
          'xp': _userProgress!.xp,
          'streak': _userProgress!.streak,
        },
      );

      if (success) {
        // Recargar el progreso después de actualizar
        await cargarProgreso(_userProgress!.userId);
      }
    } catch (error) {
      _errorMessage = 'Error al actualizar progreso: $error';
      print('Error updating progress: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
