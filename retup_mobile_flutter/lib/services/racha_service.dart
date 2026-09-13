import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class RachaService {
  static final RachaService _instance = RachaService._internal();
  final String baseUrl = 'https://retup-backend.onrender.com/api';

  factory RachaService() {
    return _instance;
  }

  RachaService._internal();

  // Register user login for current day
  Future<void> registrarLogin(
      String userId, String retoId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/racha/registrar-login'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
          'reto_id': retoId,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to register login: ${response.body}');
      }
    } catch (e) {
      print('Error registering login: $e');
      rethrow;
    }
  }

  // Register pildora completion for current day
  Future<void> registrarPildoraCompletada(
      String userId, String retoId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/racha/registrar-pildora'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
          'reto_id': retoId,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to register pildora: ${response.body}');
      }
    } catch (e) {
      print('Error registering pildora: $e');
      rethrow;
    }
  }

  // Get monthly statistics
  Future<Map<String, dynamic>> obtenerEstadisticasMes(
      String userId, String retoId, String token) async {
    try {
      final now = DateTime.now();
      final mesActual = now.month;
      final anoActual = now.year;

      final response = await http.get(
        Uri.parse(
            '$baseUrl/racha/estadisticas-por-reto?user_id=$userId&reto_id=$retoId&mes=$mesActual&ano=$anoActual'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to get statistics: ${response.body}');
      }
    } catch (e) {
      print('Error getting statistics: $e');
      return {};
    }
  }

  // Get daily progress for current month
  Future<List<Map<String, dynamic>>> obtenerProgresoMes(
      String userId, String retoId, String token) async {
    try {
      final now = DateTime.now();
      final mesActual = now.month;
      final anoActual = now.year;

      final response = await http.get(
        Uri.parse(
            '$baseUrl/racha/progreso?user_id=$userId&reto_id=$retoId&mes=$mesActual&ano=$anoActual'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final progreso = data['data'] as List? ?? [];
        return List<Map<String, dynamic>>.from(progreso);
      } else {
        throw Exception('Failed to get progress: ${response.body}');
      }
    } catch (e) {
      print('Error getting progress: $e');
      return [];
    }
  }

  // Helper function to check if a date is a business day
  bool _esDialaboral(DateTime fecha) {
    final dia = fecha.weekday;
    return dia >= 1 && dia <= 5;
  }

  // Get all business days for a specific month
  List<DateTime> obtenerDiasLaboralesMes(int mes, int ano) {
    final diasLaborales = <DateTime>[];
    final primerDia = DateTime(ano, mes, 1);
    final ultimoDia =
        mes == 12 ? DateTime(ano + 1, 1, 0) : DateTime(ano, mes + 1, 0);

    for (int i = 1; i <= ultimoDia.day; i++) {
      final fecha = DateTime(ano, mes, i);
      if (_esDialaboral(fecha)) {
        diasLaborales.add(fecha);
      }
    }

    return diasLaborales;
  }

  // Check if user completed pildora today
  Future<bool> completoPildoraHoy(
      String userId, String retoId, String token) async {
    try {
      final hoy = DateTime.now();
      final fechaStr = DateFormat('yyyy-MM-dd').format(hoy);

      final response = await http.get(
        Uri.parse(
            '$baseUrl/racha/check?user_id=$userId&reto_id=$retoId&fecha=$fechaStr&tipo=pildora'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['completado'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error checking pildora: $e');
      return false;
    }
  }

  // Check if user did login today
  Future<bool> hizoLoginHoy(String userId, String retoId, String token) async {
    try {
      final hoy = DateTime.now();
      final fechaStr = DateFormat('yyyy-MM-dd').format(hoy);

      final response = await http.get(
        Uri.parse(
            '$baseUrl/racha/check?user_id=$userId&reto_id=$retoId&fecha=$fechaStr&tipo=login'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['completado'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error checking login: $e');
      return false;
    }
  }
}
