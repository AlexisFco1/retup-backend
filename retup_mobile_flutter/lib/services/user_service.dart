import 'dart:convert';
import '../models/user_model.dart';
import 'api_service.dart';

class UsersService {
  final ApiService _apiService = ApiService();

  Future<User?> getProfile() async {
    try {
      final response = await _apiService.get('/users/me');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return User.fromJson(jsonResponse);
      }
    } catch (e) {
      print('Error getting profile: $e');
    }
    return null;
  }

  Future<User?> getById(int id) async {
    try {
      final response = await _apiService.get('/users/$id');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return User.fromJson(jsonResponse);
      }
    } catch (e) {
      print('Error getting user: $e');
    }
    return null;
  }

  Future<List<User>> getAll() async {
    try {
      final response = await _apiService.get('/users');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // El servidor devuelve { success: true, data: [...] }
        final data = jsonResponse['data'] as List;
        List<User> users = data.map((user) => User.fromJson(user)).toList();

        print('✅ Usuarios cargados: ${users.length}');
        for (var user in users) {
          print('👤 ${user.fullName} - ${user.email}');
        }

        return users;
      }
    } catch (e) {
      print('❌ Error getting users: $e');
    }
    return [];
  }

  Future<bool> update(int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.put('/users/$id', data: data);
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating user: $e');
    }
    return false;
  }
}
