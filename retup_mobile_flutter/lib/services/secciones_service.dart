import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/seccion_model.dart';

class SeccionesService {
  static const String baseUrl = 'http://localhost:5000/api';
  final _secureStorage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _secureStorage.read(key: 'userToken'); // ✅
  }

  // Obtener todas las secciones de una píldora
  Future<List<Seccion>> getByPildoraId(String pildoraId) async {
    try {
      final token = await _getToken();

      final response = await http.get(
        Uri.parse('$baseUrl/pildoras/$pildoraId/secciones'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print(
          '🔍 GET /api/pildoras/$pildoraId/secciones - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as List;
        final secciones =
            jsonResponse.map((data) => Seccion.fromJson(data)).toList();

        // Ordenar por screen_number
        secciones.sort((a, b) => a.screenNumber.compareTo(b.screenNumber));

        print('📺 Secciones encontradas: ${secciones.length}');
        return secciones;
      } else {
        throw Exception('Error al cargar secciones: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en getByPildoraId: $e');
      throw Exception('Error al obtener secciones: $e');
    }
  }

  // Obtener una sección específica
  Future<Seccion?> getById(String seccionId) async {
    try {
      final token = await _getToken();

      final response = await http.get(
        Uri.parse('$baseUrl/secciones/$seccionId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return Seccion.fromJson(jsonResponse);
      } else {
        return null;
      }
    } catch (e) {
      print('Error en getById: $e');
      return null;
    }
  }
}
