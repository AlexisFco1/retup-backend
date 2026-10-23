// racha_provider.dart - ACTUALIZADO

import 'package:flutter/material.dart';
import '../services/racha_service.dart';

class RachaProvider extends ChangeNotifier {
  final RachaService _rachaService = RachaService();

  // Estado para estadísticas por reto
  Map<String, dynamic> estadisticasPorReto = {};

  // Estado para leaderboard
  Map<String, dynamic> leaderboard = {};
  Map<String, List<Map<String, dynamic>>> progresoDiarioPorReto = {};
  // Estado para preferencias de regalo por reto
  Map<String, String?> preferenciaRegaloPorReto = {};
  String? preferenciaRegaloGlobal;
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

  // ===== CARGA COMPLETA DE LA PANTALLA RACHAS (un solo refresco) =====
  // Pide todo EN PARALELO y avisa a la pantalla UNA sola vez al final.
  // El spinner de pantalla completa solo sale la primera vez (sin datos);
  // en recargas se mantiene el contenido visible y se actualiza de golpe.
  Future<void> cargarPantallaRachas(
    String userId,
    List<String> retoIds,
    String token,
  ) async {
    final primeraCarga = estadisticasPorReto.isEmpty;
    if (primeraCarga) {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
    }

    try {
      final nuevasStats = <String, dynamic>{};
      final nuevoProgreso = <String, List<Map<String, dynamic>>>{};
      Map<String, dynamic>? nuevoLeaderboard;
      String? nuevaPreferencia;
      bool preferenciaCargada = false;

      final tareas = <Future<void>>[];

      for (final retoId in retoIds) {
        // Estadísticas del reto (el backend recalcula la racha aquí)
        tareas.add(() async {
          try {
            nuevasStats[retoId] = await _rachaService.obtenerEstadisticasMes(
              userId,
              retoId,
              token,
            );
          } catch (e) {
            print('⚠️ Error cargando stats para reto $retoId: $e');
          }
        }());

        // Bolitas / calendario del reto
        tareas.add(() async {
          try {
            nuevoProgreso[retoId] = await _rachaService.obtenerProgresoDiario(
              userId,
              retoId,
              token,
            );
          } catch (e) {
            print('⚠️ Error cargando progreso diario del reto $retoId: $e');
          }
        }());
      }

      // Ranking
      tareas.add(() async {
        try {
          nuevoLeaderboard = await _rachaService.obtenerLeaderboard(token);
        } catch (e) {
          print('⚠️ Error cargando leaderboard: $e');
        }
      }());

      // Premio elegido
      tareas.add(() async {
        try {
          nuevaPreferencia =
              await _rachaService.obtenerPreferenciaRegaloGlobal(userId, token);
          preferenciaCargada = true;
        } catch (e) {
          print('⚠️ Error cargando preferencia global: $e');
        }
      }());

      // Esperar a que TODO termine
      await Future.wait(tareas);

      // Aplicar todos los datos juntos
      estadisticasPorReto
        ..clear()
        ..addAll(nuevasStats);
      progresoDiarioPorReto.addAll(nuevoProgreso);
      if (nuevoLeaderboard != null) leaderboard = nuevoLeaderboard!;
      if (preferenciaCargada) preferenciaRegaloGlobal = nuevaPreferencia;
      errorMessage = null;

      print('✅ Pantalla Rachas cargada: ${estadisticasPorReto.length} retos');
    } catch (e) {
      print('❌ Error en cargarPantallaRachas: $e');
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners(); // ÚNICO refresco de la pantalla
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

  Future<void> verificarRacha(
    String userId,
    String token,
  ) async {
    try {
      await _rachaService.verificarRacha(userId, token);
      print('✅ Racha verificada para usuario: $userId');
    } catch (e) {
      print('⚠️ Error al verificar racha: $e');
      // No lanzar error aquí, solo logear para no interrumpir el login
    }
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

  List<dynamic> obtenerLeaderboardUnificado() {
    if (leaderboard['leaderboard_unificado'] != null) {
      return leaderboard['leaderboard_unificado'] as List<dynamic>;
    }
    return [];
  }
  // ===== PROGRESO DIARIO =====

  Future<void> cargarProgresoDiario(
    String userId,
    String retoId,
    String token,
  ) async {
    try {
      final progreso = await _rachaService.obtenerProgresoDiario(
        userId,
        retoId,
        token,
      );
      print('🔍 DEBUG: Registros traídos del backend: ${progreso.length}');
      print('🔍 DEBUG: Primeros registros: ${progreso.take(3).toList()}');
      progresoDiarioPorReto[retoId] = progreso;
      notifyListeners();

      print(
          '✅ Progreso diario cargado para reto: $retoId (${progreso.length} días)');
    } catch (e) {
      print('❌ Error en cargarProgresoDiario: $e');
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  List<Map<String, dynamic>>? obtenerProgresoDiario(String retoId) {
    return progresoDiarioPorReto[retoId];
  }

  // ===== GUARDAR PREFERENCIA DE REGALO =====
  Future<void> guardarPreferenciaRegalo(
    String userId,
    String retoId,
    String regaloTipo,
    String token,
  ) async {
    try {
      await _rachaService.guardarPreferenciaRegalo(
        userId,
        retoId,
        regaloTipo,
        token,
      );

      // Actualizar estado local
      preferenciaRegaloPorReto[retoId] = regaloTipo;
      notifyListeners();

      print('✅ Preferencia de regalo guardada: $regaloTipo para reto $retoId');
    } catch (e) {
      print('❌ Error en guardarPreferenciaRegalo: $e');
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ===== OBTENER PREFERENCIA DE REGALO =====
  Future<void> cargarPreferenciaRegalo(
    String userId,
    String retoId,
    String token,
  ) async {
    try {
      final regalo = await _rachaService.obtenerPreferenciaRegalo(
        userId,
        retoId,
        token,
      );

      preferenciaRegaloPorReto[retoId] = regalo;
      notifyListeners();

      print('✅ Preferencia de regalo cargada para reto $retoId: $regalo');
    } catch (e) {
      print('⚠️ Error cargando preferencia de regalo: $e');
      // No lanzar error, solo logear
    }
  }

  // ===== OBTENER PREFERENCIA GUARDADA =====
  String? obtenerPreferenciaRegalo(String retoId) {
    return preferenciaRegaloPorReto[retoId];
  }

  // ===== GUARDAR PREFERENCIA DE REGALO GLOBAL =====
  Future<void> guardarPreferenciaRegaloGlobal(
    String userId,
    String regaloTipo,
    String token,
  ) async {
    try {
      await _rachaService.guardarPreferenciaRegaloGlobal(
        userId,
        regaloTipo,
        token,
      );

      preferenciaRegaloGlobal = regaloTipo;
      notifyListeners();

      print('✅ Preferencia global guardada: $regaloTipo');
    } catch (e) {
      print('❌ Error en guardarPreferenciaRegaloGlobal: $e');
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ===== CARGAR PREFERENCIA DE REGALO GLOBAL =====
  Future<void> cargarPreferenciaRegaloGlobal(
    String userId,
    String token,
  ) async {
    try {
      final regalo = await _rachaService.obtenerPreferenciaRegaloGlobal(
        userId,
        token,
      );

      preferenciaRegaloGlobal = regalo;
      notifyListeners();

      print('✅ Preferencia global cargada: $regalo');
    } catch (e) {
      print('⚠️ Error cargando preferencia global: $e');
    }
  }
}
