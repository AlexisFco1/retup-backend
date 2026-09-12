import 'dart:convert';
import '../models/pildora_model.dart';
import 'api_service.dart';

class PillorasService {
  final ApiService _apiService = ApiService();

  Future<List<Pildora>> getAll() async {
    try {
      final response = await _apiService.get('/pildoras');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as List;
        List<Pildora> pildoras =
            jsonResponse.map((pildora) => Pildora.fromJson(pildora)).toList();
        return pildoras;
      }
    } catch (e) {
      print('Error getting pildoras: $e');
    }
    return [];
  }

  Future<List<Pildora>> getByRetoId(String retoId) async {
    try {
      final response = await _apiService.get('/retos/$retoId/pills');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as List;
        List<Pildora> pildoras =
            jsonResponse.map((pildora) => Pildora.fromJson(pildora)).toList();
        return pildoras;
      }
    } catch (e) {
      print('Error getting pildoras por reto: $e');
    }
    return [];
  }

  Future<Pildora?> getById(String id) async {
    try {
      final response = await _apiService.get('/pildoras/$id');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return Pildora.fromJson(jsonResponse);
      }
    } catch (e) {
      print('Error getting pildora: $e');
    }
    return null;
  }

  Future<Pildora?> create(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/pildoras', data: data);
      if (response.statusCode == 201 || response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return Pildora.fromJson(jsonResponse);
      }
    } catch (e) {
      print('Error creating pildora: $e');
    }
    return null;
  }

  Future<bool> update(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.put('/pildoras/$id', data: data);
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating pildora: $e');
    }
    return false;
  }

  Future<bool> delete(String id) async {
    try {
      final response = await _apiService.delete('/pildoras/$id');
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print('Error deleting pildora: $e');
    }
    return false;
  }
}
