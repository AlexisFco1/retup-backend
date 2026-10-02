import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'dart:async';

class ApiService {
  static const String baseUrl = 'https://retup-backend.onrender.com/api';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

  // GET request
  Future<http.Response> get(String path) async {
    final token = await _getToken();
    final headers = _buildHeaders(token);

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl$path'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      return response;
    } catch (e) {
      if (e is SocketException || e is TimeoutException) {
        throw Exception(
            'No hay conexión a internet. Verifica tu conexión e intenta nuevamente.');
      }
      throw Exception('Error en la solicitud. Intenta nuevamente.');
    }
  }

  // POST request
  Future<http.Response> post(String path, {dynamic data}) async {
    final token = await _getToken();
    final headers = _buildHeaders(token);

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: _encodeBody(data),
          )
          .timeout(const Duration(seconds: 30));

      return response;
    } catch (e) {
      if (e is SocketException || e is TimeoutException) {
        throw Exception(
            'No hay conexión a internet. Verifica tu conexión e intenta nuevamente.');
      }
      throw Exception('Error en la solicitud. Intenta nuevamente.');
    }
  }

  // PUT request
  Future<http.Response> put(String path, {dynamic data}) async {
    final token = await _getToken();
    final headers = _buildHeaders(token);

    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: _encodeBody(data),
          )
          .timeout(const Duration(seconds: 30));

      return response;
    } catch (e) {
      // Detectar tipo de error y devolver mensaje genérico
      if (e is SocketException || e is TimeoutException) {
        throw Exception(
            'No hay conexión a internet. Verifica tu conexión e intenta nuevamente.');
      }
      throw Exception('Error en la solicitud. Intenta nuevamente.');
    }
  }

  // DELETE request
  Future<http.Response> delete(String path) async {
    final token = await _getToken();
    final headers = _buildHeaders(token);

    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl$path'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      return response;
    } catch (e) {
      if (e is SocketException || e is TimeoutException) {
        throw Exception(
            'No hay conexión a internet. Verifica tu conexión e intenta nuevamente.');
      }
      throw Exception('Error en la solicitud. Intenta nuevamente.');
    }
  }

  // ===== Métodos de Token =====

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'userToken', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'userToken');
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'userToken');
  }

  // ===== Métodos Privados =====

  Future<String?> _getToken() async {
    return await _storage.read(key: 'userToken');
  }

  Map<String, String> _buildHeaders(String? token) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  String _encodeBody(dynamic data) {
    if (data == null) return '';

    if (data is String) return data;

    if (data is Map) {
      return _jsonEncode(Map<String, dynamic>.from(data));
    }

    return data.toString();
  }

  String _jsonEncode(Map<String, dynamic> data) {
    final buffer = StringBuffer('{');
    final entries = data.entries.toList();

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      buffer.write('"${entry.key}":${_encodeValue(entry.value)}');
      if (i < entries.length - 1) buffer.write(',');
    }

    buffer.write('}');
    return buffer.toString();
  }

  dynamic _encodeValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return '"$value"';
    if (value is num || value is bool) return value.toString();
    if (value is List) return jsonEncodeList(value);
    if (value is Map) {
      final map = value.cast<String, dynamic>();
      return _jsonEncode(map);
    }
    return '"$value"';
  }

  String jsonEncodeList(List list) {
    final buffer = StringBuffer('[');
    for (int i = 0; i < list.length; i++) {
      buffer.write(_encodeValue(list[i]));
      if (i < list.length - 1) buffer.write(',');
    }
    buffer.write(']');
    return buffer.toString();
  }
}
