import 'dart:convert';
import 'api_service.dart';

class FavoritosService {
  final ApiService _apiService = ApiService();

  Future<List<String>> getFavoritos(String userId) async {
    try {
      final response = await _apiService.get('/favoritos?user_id=$userId');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['data'] is List) {
          return (jsonResponse['data'] as List)
              .map((f) => f['pill_id'].toString())
              .toList();
        }
      }
    } catch (e) {
      print('Error getting favoritos: $e');
    }
    return [];
  }

  Future<bool> addFavorito(String userId, String pillId) async {
    try {
      final response = await _apiService.post('/favoritos', data: {
        'user_id': userId,
        'pill_id': pillId,
      });
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error adding favorito: $e');
    }
    return false;
  }

  Future<bool> removeFavorito(String userId, String pillId) async {
    try {
      final response = await _apiService
          .delete('/favoritos?user_id=$userId&pill_id=$pillId');
      return response.statusCode == 200;
    } catch (e) {
      print('Error removing favorito: $e');
    }
    return false;
  }
}
