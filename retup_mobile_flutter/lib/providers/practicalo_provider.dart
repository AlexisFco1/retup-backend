import 'package:flutter/material.dart';
import '../services/practicalo_service.dart';

class PracticaloProvider extends ChangeNotifier {
  final PracticaloService _practicaloService = PracticaloService();

  // Estado
  List<Map<String, dynamic>> _practicaloRecibidas = [];
  List<Map<String, dynamic>> _practicaloEnviadas = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _promedioCalificacion;

  // Getters
  List<Map<String, dynamic>> get practicaloRecibidas => _practicaloRecibidas;
  List<Map<String, dynamic>> get practicaloEnviadas => _practicaloEnviadas;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get promedioCalificacion => _promedioCalificacion;

  /// Cargar practicalo recibidas
  Future<void> cargarRecibidas({
    required String token,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _practicaloRecibidas = await _practicaloService.obtenerRecibidas(
        token: token,
        userId: userId,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cargar practicalo enviadas
  Future<void> cargarEnviadas({
    required String token,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _practicaloEnviadas = await _practicaloService.obtenerEnviadas(
        token: token,
        userId: userId,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Crear invitación
  Future<bool> crearInvitacion({
    required String token,
    required String recipientUserId,
    required String retoId,
    required String pillId,
    required String message,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await _practicaloService.crearInvitacion(
        token: token,
        recipientUserId: recipientUserId,
        retoId: retoId,
        pillId: pillId,
        message: message,
      );

      if (result != null) {
        _practicaloEnviadas.add(result);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Responder invitación
  Future<bool> responderInvitacion({
    required String token,
    required String practicaloId,
    required String response,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final success = await _practicaloService.responderInvitacion(
        token: token,
        practicaloId: practicaloId,
        response: response,
      );

      if (success) {
        // Actualizar la lista local
        final index =
            _practicaloRecibidas.indexWhere((p) => p['id'] == practicaloId);
        if (index != -1) {
          _practicaloRecibidas[index]['response'] = response;
          _practicaloRecibidas[index]['response_date'] =
              DateTime.now().toIso8601String();
        }
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Confirmar reunión
  Future<bool> confirmarReunion({
    required String token,
    required String practicaloId,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final success = await _practicaloService.confirmarReunion(
        token: token,
        practicaloId: practicaloId,
      );

      if (success) {
        // Actualizar estado
        final index =
            _practicaloEnviadas.indexWhere((p) => p['id'] == practicaloId);
        if (index != -1) {
          _practicaloEnviadas[index]['confirmed_by_sender'] = true;
          _practicaloEnviadas[index]['status'] = 'completed';
        }
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Calificar
  Future<bool> calificar({
    required String token,
    required String practicaloId,
    required int starRating,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final success = await _practicaloService.calificar(
        token: token,
        practicaloId: practicaloId,
        starRating: starRating,
      );

      if (success) {
        // Actualizar estado
        final index =
            _practicaloRecibidas.indexWhere((p) => p['id'] == practicaloId);
        if (index != -1) {
          _practicaloRecibidas[index]['star_rating'] = starRating;
        }
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Obtener promedio de calificación
  Future<void> cargarPromedioCalificacion({
    required String token,
    required String userId,
    required String retoId,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _promedioCalificacion =
          await _practicaloService.obtenerPromedioCalificacion(
        token: token,
        userId: userId,
        retoId: retoId,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}
