// racha_service.dart - ACTUALIZADO

import 'package:http/http.dart' as http;
import 'dart:convert';

class RachaService {
  final String baseUrl = 'https://retup-backend.onrender.com/api';

  // ===== EXISTING METHODS (keep these) =====

  Future<Map<String, dynamic>> registrarLogin(
    String userId,
    String retoId,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/racha/registrar-login'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'reto_id': retoId,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Error al registrar login: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en registrarLogin: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>> registrarPildoraCompletada(
    String userId,
    String retoId,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/racha/registrar-pildora'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'reto_id': retoId,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Error al registrar píldora: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en registrarPildoraCompletada: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>> obtenerEstadisticasMes(
    String userId,
    String retoId,
    String token,
  ) async {
    try {
      final now = DateTime.now();
      final mes = now.month;
      final ano = now.year;

      final response = await http.get(
        Uri.parse(
          '$baseUrl/racha/estadisticas-por-reto?user_id=$userId&reto_id=$retoId&mes=$mes&ano=$ano',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        // Extraer solo la parte 'data' de la respuesta
        return jsonResponse['data'] ?? {};
      }
      throw Exception('Error al obtener estadísticas: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en obtenerEstadisticasMes: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>> obtenerProgresoMes(
    String userId,
    String retoId,
    String token,
  ) async {
    try {
      final now = DateTime.now();
      final mes = now.month;
      final ano = now.year;

      final response = await http.get(
        Uri.parse(
          '$baseUrl/racha/progreso?user_id=$userId&reto_id=$retoId&mes=$mes&ano=$ano',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Error al obtener progreso: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en obtenerProgresoMes: $e');
      throw e;
    }
  }

  Future<bool> completoPildoraHoy(
    String userId,
    String retoId,
    String token,
  ) async {
    try {
      final stats = await obtenerEstadisticasMes(userId, retoId, token);
      return stats['completó_píldora_hoy'] ?? false;
    } catch (e) {
      print('❌ Error en completoPildoraHoy: $e');
      return false;
    }
  }

  Future<bool> hizoLoginHoy(
    String userId,
    String retoId,
    String token,
  ) async {
    try {
      final stats = await obtenerEstadisticasMes(userId, retoId, token);
      return stats['hizo_login_hoy'] ?? false;
    } catch (e) {
      print('❌ Error en hizoLoginHoy: $e');
      return false;
    }
  }

  // ===== NEW METHOD: Get leaderboard =====

  // ===== NEW METHOD: Get leaderboard =====

  Future<Map<String, dynamic>> obtenerLeaderboard(String token) async {
    try {
      final now = DateTime.now();
      final mes = now.month;
      final ano = now.year;

      final response = await http.get(
        Uri.parse(
            '$baseUrl/racha/leaderboard-dias-cumplidos?mes=$mes&ano=$ano'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print(
          '🏆 GET /racha/leaderboard-dias-cumplidos - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Extraer la parte 'data' si viene envuelta
        if (jsonResponse['data'] != null) {
          return jsonResponse['data'] as Map<String, dynamic>;
        }

        return jsonResponse;
      }
      throw Exception('Error al obtener leaderboard: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en obtenerLeaderboard: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>> verificarRacha(
    String userId,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/racha/verificar-racha'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Error al verificar racha: ${response.statusCode}');
    } catch (e) {
      print('❌ Error en verificarRacha: $e');
      throw e;
    }
  }
}
