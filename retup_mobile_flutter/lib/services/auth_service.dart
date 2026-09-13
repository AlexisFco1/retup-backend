import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String _baseUrl = 'https://retup-backend.onrender.com/api';
  static const _secureStorage = FlutterSecureStorage();

  // LOGIN
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Guardar token en storage seguro
        if (data['token'] != null) {
          await _secureStorage.write(
            key: 'userToken',
            value: data['token'],
          );
        }

        return {
          'success': true,
          'token': data['token'],
          'userId': data['user']?['id'] ?? data['userId'],
          'message': 'Login exitoso',
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Error en login',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  // SIGNUP - ACTUALIZADO CON FULL_NAME
  Future<Map<String, dynamic>> signup(
    String email,
    String password,
    String fullName,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'full_name': fullName,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Guardar token
        if (data['token'] != null) {
          await _secureStorage.write(
            key: 'userToken',
            value: data['token'],
          );
        }

        return {
          'success': true,
          'token': data['token'],
          'userId': data['user']?['id'] ?? data['userId'],
          'message': 'Registro exitoso',
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Error en registro',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  // LOGOUT
  Future<void> logout() async {
    try {
      await _secureStorage.delete(key: 'userToken');
    } catch (e) {
      print('Error al cerrar sesión: $e');
    }
  }

  // Obtener token almacenado
  static Future<String?> getToken() async {
    return await _secureStorage.read(key: 'userToken');
  }
}
