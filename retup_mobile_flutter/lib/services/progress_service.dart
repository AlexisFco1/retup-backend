import 'dart:convert';
import '../models/progress_model.dart';
import '../models/pill_progress_model.dart';
import 'api_service.dart';

class ProgressService {
  final ApiService _apiService = ApiService();

  Future<UserProgress?> getUserProgress(String userId) async {
    try {
      final response = await _apiService.get('/user-progress?user_id=$userId');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['data'] is List && jsonResponse['data'].isNotEmpty) {
          return UserProgress.fromJson(jsonResponse['data'][0]);
        }
      }
    } catch (e) {
      print('Error getting user progress: $e');
    }
    return null;
  }

  Future<PillProgress?> getPillProgress(String userId, String pillId) async {
    try {
      final response = await _apiService
          .get('/user-progress?user_id=$userId&pill_id=$pillId');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['data'] is List && jsonResponse['data'].isNotEmpty) {
          return PillProgress.fromJson(jsonResponse['data'][0]);
        }
      }
    } catch (e) {
      print('Error getting pill progress: $e');
    }
    return null;
  }

  Future<bool> createPillProgress(String userId, String pillId) async {
    try {
      final response = await _apiService.post('/user-progress', data: {
        'user_id': userId,
        'pill_id': pillId,
        'current_screen': 1,
      });
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error creating pill progress: $e');
    }
    return false;
  }

  Future<bool> completePill(String progressId) async {
    try {
      final response = await _apiService.put(
        '/user-progress/$progressId',
        data: {
          'is_completed': true,
          'current_screen': 9,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error completing pill: $e');
    }
    return false;
  }

  Future<bool> updateProgress(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.put('/user-progress/$id', data: data);
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating progress: $e');
    }
    return false;
  }
}
