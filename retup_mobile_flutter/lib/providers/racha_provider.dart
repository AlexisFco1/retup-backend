import 'package:flutter/material.dart';
import '../services/racha_service.dart';

class RachaProvider extends ChangeNotifier {
  final RachaService _rachaService = RachaService();

  Map<String, dynamic> _estadisticasMes = {};
  List<Map<String, dynamic>> _progresoDiario = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  int get diaPildora => _estadisticasMes['dia_pildora'] ?? 0;
  int get diasRacha => _estadisticasMes['dias_racha'] ?? 0;
  int get diasCumplidos => _estadisticasMes['dias_cumplidos'] ?? 0;
  int get diasNoCumplidos => _estadisticasMes['dias_no_cumplidos'] ?? 0;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get progresoDiario => _progresoDiario;

  // Load statistics for the current month
  Future<void> cargarEstadisticas(
      String userId, String retoId, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _estadisticasMes =
          await _rachaService.obtenerEstadisticasMes(userId, retoId, token);
      _progresoDiario =
          await _rachaService.obtenerProgresoMes(userId, retoId, token);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register login for today (CON TOKEN)
  Future<void> registrarLogin(
      String userId, String retoId, String token) async {
    try {
      await _rachaService.registrarLogin(userId, retoId, token);
      // Reload statistics after registering login
      await cargarEstadisticas(userId, retoId, token);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Register pildora completion for today (CON TOKEN)
  Future<void> registrarPildoraCompletada(
      String userId, String retoId, String token) async {
    try {
      await _rachaService.registrarPildoraCompletada(userId, retoId, token);
      // Reload statistics after registering pildora
      await cargarEstadisticas(userId, retoId, token);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Get business days for a month
  List<DateTime> obtenerDiasLaboralesMes(int mes, int ano) {
    return _rachaService.obtenerDiasLaboralesMes(mes, ano);
  }

  // Check if pildora was completed today
  Future<bool> completoPildoraHoy(
      String userId, String retoId, String token) async {
    try {
      return await _rachaService.completoPildoraHoy(userId, retoId, token);
    } catch (e) {
      print('Error: $e');
      return false;
    }
  }

  // Check if login was done today
  Future<bool> hizoLoginHoy(String userId, String retoId, String token) async {
    try {
      return await _rachaService.hizoLoginHoy(userId, retoId, token);
    } catch (e) {
      print('Error: $e');
      return false;
    }
  }
}
