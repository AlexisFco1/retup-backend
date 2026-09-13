// racha_provider.dart - ACTUALIZADO

import 'package:flutter/material.dart';
import '../services/racha_service.dart';

class RachaProvider extends ChangeNotifier {
  final RachaService _rachaService = RachaService();

  // Estado para estadísticas por reto
  Map<String, dynamic> estadisticasPorReto = {};

  // Estado para leaderboard
  Map<String, dynamic> leaderboard = {};

  bool isLoading = false;
  String? errorMessage;

  // ===== ESTADÍSTICAS POR RETO =====

  Future<void> cargarEstadisticas(
    String userId,
    String retoId,
    String token,
  ) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final stats = await _rachaService.obtenerEstadisticasMes(
        userId,
        retoId,
        token,
      );

      estadisticasPorReto[retoId] = stats;
      isLoading = false;
      notifyListeners();

      print('✅ Estadísticas cargadas para reto: $retoId');
    } catch (e) {
      print('❌ Error en cargarEstadisticas: $e');
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cargarEstadisticasMultipleRetos(
    String userId,
    List<String> retoIds,
    String token,
  ) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      estadisticasPorReto.clear();

      for (String retoId in retoIds) {
        try {
          final stats = await _rachaService.obtenerEstadisticasMes(
            userId,
            retoId,
            token,
          );
          estadisticasPorReto[retoId] = stats;
        } catch (e) {
          print('⚠️  Error cargando stats para reto $retoId: $e');
        }
      }

      isLoading = false;
      notifyListeners();

      print('✅ Estadísticas cargadas para ${estadisticasPorReto.length} retos');
    } catch (e) {
      print('❌ Error en cargarEstadisticasMultipleRetos: $e');
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  // ===== LEADERBOARD =====

  Future<void> cargarLeaderboard(String token) async {
    try {
      final lb = await _rachaService.obtenerLeaderboard(token);
      leaderboard = lb;
      notifyListeners();

      print('✅ Leaderboard cargado: ${leaderboard.length} usuarios');
    } catch (e) {
      print('❌ Error en cargarLeaderboard: $e');
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ===== REGISTRO DE EVENTOS =====

  Future<void> registrarLogin(
    String userId,
    String retoId,
    String token,
  ) async {
    try {
      await _rachaService.registrarLogin(userId, retoId, token);
      await cargarEstadisticas(userId, retoId, token);
      print('✅ Login registrado para reto: $retoId');
    } catch (e) {
      print('❌ Error en registrarLogin: $e');
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> registrarPildoraCompletada(
    String userId,
    String retoId,
    String token,
  ) async {
    try {
      await _rachaService.registrarPildoraCompletada(userId, retoId, token);
      await cargarEstadisticas(userId, retoId, token);
      print('✅ Píldora completada registrada para reto: $retoId');
    } catch (e) {
      print('❌ Error en registrarPildoraCompletada: $e');
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> completoPildoraHoy(
    String userId,
    String retoId,
    String token,
  ) async {
    return await _rachaService.completoPildoraHoy(userId, retoId, token);
  }

  Future<bool> hizoLoginHoy(
    String userId,
    String retoId,
    String token,
  ) async {
    return await _rachaService.hizoLoginHoy(userId, retoId, token);
  }

  // Obtener stats de un reto específico
  Map<String, dynamic>? obtenerStatsReto(String retoId) {
    return estadisticasPorReto[retoId];
  }

  // Obtener todos los leaderboards
  List<dynamic> obtenerLeaderboardRacha() {
    if (leaderboard['leaderboard_racha'] != null) {
      return leaderboard['leaderboard_racha'] as List<dynamic>;
    }
    return [];
  }

  List<dynamic> obtenerLeaderboardDiasCumplidos() {
    if (leaderboard['leaderboard_dias_cumplidos'] != null) {
      return leaderboard['leaderboard_dias_cumplidos'] as List<dynamic>;
    }
    return [];
  }
}
