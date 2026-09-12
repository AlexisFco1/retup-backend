import 'dart:convert';
import '../models/reto_model.dart';
import 'api_service.dart';

class RetosService {
  final ApiService _apiService = ApiService();

  Future<List<Reto>> getAll() async {
    try {
      final response = await _apiService.get('/retos');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as List;
        List<Reto> retos =
            jsonResponse.map((reto) => Reto.fromJson(reto)).toList();
        return retos;
      }
    } catch (e) {
      print('Error getting retos: $e');
    }
    return [];
  }

  Future<Reto?> getById(String id) async {
    try {
      final response = await _apiService.get('/retos/$id');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return Reto.fromJson(jsonResponse);
      }
    } catch (e) {
      print('Error getting reto: $e');
    }
    return null;
  }

  Future<List<Reto>> getByUserId(String userId) async {
    try {
      final response = await _apiService.get('/retos/user/$userId');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as List;
        List<Reto> retos =
            jsonResponse.map((reto) => Reto.fromJson(reto)).toList();
        return retos;
      }
    } catch (e) {
      print('Error getting user retos: $e');
    }
    return [];
  }

  Future<Reto?> create(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/retos', data: data);
      if (response.statusCode == 201 || response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return Reto.fromJson(jsonResponse);
      }
    } catch (e) {
      print('Error creating reto: $e');
    }
    return null;
  }

  Future<bool> update(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.put('/retos/$id', data: data);
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating reto: $e');
    }
    return false;
  }

  Future<bool> delete(String id) async {
    try {
      final response = await _apiService.delete('/retos/$id');
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print('Error deleting reto: $e');
    }
    return false;
  }
}
