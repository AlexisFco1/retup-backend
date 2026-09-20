import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reto_model.dart';

class PracticaloService {
  static const String _baseUrl = 'https://retup-backend.onrender.com/api';

  /// 1️⃣ CREAR INVITACIÓN DE PRACTICALO
  Future<Map<String, dynamic>?> crearInvitacion({
    required String token,
    required String recipientUserId,
    required String retoId,
    required String pillId,
    required String message,
  }) async {
    try {
      print('\n═══════════════════════════════════════════════════════════');
      print('🤝 CREAR INVITACIÓN PRACTICALO');
      print('═══════════════════════════════════════════════════════════');
      print('   Recipient: $recipientUserId');
      print('   Reto: $retoId');
      print('   Píldora: $pillId');
      print('   Message: $message');

      final url = Uri.parse('$_baseUrl/practicalo');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'recipient_user_id': recipientUserId,
        'reto_id': retoId,
        'pill_id': pillId,
        'message': message,
      });

      print('\n🚀 ENVIANDO POST...');
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      print('📥 Status: ${response.statusCode}');
      print('📥 Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final practicalo = jsonResponse['data'] ?? jsonResponse;
        print('✅ Invitación creada: ${practicalo['id']}');
        print('═══════════════════════════════════════════════════════════\n');
        return practicalo;
      } else {
        print('❌ Error: ${response.statusCode}');
        print('═══════════════════════════════════════════════════════════\n');
        throw Exception('Error creando invitación: ${response.body}');
      }
    } catch (e) {
      print('❌ Exception: $e');
      print('═══════════════════════════════════════════════════════════\n');
      rethrow;
    }
  }

  /// 2️⃣ OBTENER PRACTICALO RECIBIDAS
  Future<List<Map<String, dynamic>>> obtenerRecibidas({
    required String token,
    required String userId,
  }) async {
    try {
      print('\n═══════════════════════════════════════════════════════════');
      print('📥 OBTENER PRACTICALO RECIBIDAS');
      print('═══════════════════════════════════════════════════════════');
      print('   User: $userId');

      final url = Uri.parse('$_baseUrl/practicalo/received/$userId');
      final headers = {
        'Authorization': 'Bearer $token',
      };

      print('\n🚀 ENVIANDO GET...');
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      print('📥 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final data = jsonResponse['data'] as List;
        final practicaloList = data.cast<Map<String, dynamic>>();
        print('✅ Encontradas: ${practicaloList.length}');
        print('═══════════════════════════════════════════════════════════\n');
        return practicaloList;
      } else {
        print('❌ Error: ${response.statusCode}');
        print('═══════════════════════════════════════════════════════════\n');
        return [];
      }
    } catch (e) {
      print('❌ Exception: $e');
      print('═══════════════════════════════════════════════════════════\n');
      return [];
    }
  }

  /// 3️⃣ OBTENER PRACTICALO ENVIADAS
  Future<List<Map<String, dynamic>>> obtenerEnviadas({
    required String token,
    required String userId,
  }) async {
    try {
      print('\n═══════════════════════════════════════════════════════════');
      print('📤 OBTENER PRACTICALO ENVIADAS');
      print('═══════════════════════════════════════════════════════════');
      print('   User: $userId');

      final url = Uri.parse('$_baseUrl/practicalo/sent/$userId');
      final headers = {
        'Authorization': 'Bearer $token',
      };

      print('\n🚀 ENVIANDO GET...');
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      print('📥 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final data = jsonResponse['data'] as List;
        final practicaloList = data.cast<Map<String, dynamic>>();
        print('✅ Encontradas: ${practicaloList.length}');
        print('═══════════════════════════════════════════════════════════\n');
        return practicaloList;
      } else {
        print('❌ Error: ${response.statusCode}');
        print('═══════════════════════════════════════════════════════════\n');
        return [];
      }
    } catch (e) {
      print('❌ Exception: $e');
      print('═══════════════════════════════════════════════════════════\n');
      return [];
    }
  }

  /// 4️⃣ RESPONDER INVITACIÓN
  Future<bool> responderInvitacion({
    required String token,
    required String practicaloId,
    required String response, // 'yes_today', 'yes_later', 'no_thanks'
  }) async {
    try {
      print('\n═══════════════════════════════════════════════════════════');
      print('💬 RESPONDER INVITACIÓN');
      print('═══════════════════════════════════════════════════════════');
      print('   Practicalo ID: $practicaloId');
      print('   Response: $response');

      final url = Uri.parse('$_baseUrl/practicalo/$practicaloId/response');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({'response': response});

      print('\n🚀 ENVIANDO PUT...');
      final httpResponse = await http
          .put(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      print('📥 Status: ${httpResponse.statusCode}');

      if (httpResponse.statusCode == 200) {
        print('✅ Respuesta registrada');
        print('═══════════════════════════════════════════════════════════\n');
        return true;
      } else {
        print('❌ Error: ${httpResponse.statusCode}');
        print('═══════════════════════════════════════════════════════════\n');
        return false;
      }
    } catch (e) {
      print('❌ Exception: $e');
      print('═══════════════════════════════════════════════════════════\n');
      return false;
    }
  }

  /// 5️⃣ CONFIRMAR REUNIÓN
  Future<bool> confirmarReunion({
    required String token,
    required String practicaloId,
  }) async {
    try {
      print('\n═══════════════════════════════════════════════════════════');
      print('✅ CONFIRMAR REUNIÓN');
      print('═══════════════════════════════════════════════════════════');
      print('   Practicalo ID: $practicaloId');

      final url = Uri.parse('$_baseUrl/practicalo/$practicaloId/confirm');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      print('\n🚀 ENVIANDO PUT...');
      final response = await http
          .put(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      print('📥 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Reunión confirmada');
        print('═══════════════════════════════════════════════════════════\n');
        return true;
      } else {
        print('❌ Error: ${response.statusCode}');
        print('═══════════════════════════════════════════════════════════\n');
        return false;
      }
    } catch (e) {
      print('❌ Exception: $e');
      print('═══════════════════════════════════════════════════════════\n');
      return false;
    }
  }

  /// 6️⃣ CALIFICAR
  Future<bool> calificar({
    required String token,
    required String practicaloId,
    required int starRating, // 1-5
  }) async {
    try {
      print('\n═══════════════════════════════════════════════════════════');
      print('⭐ CALIFICAR');
      print('═══════════════════════════════════════════════════════════');
      print('   Practicalo ID: $practicaloId');
      print('   Rating: $starRating');

      final url = Uri.parse('$_baseUrl/practicalo/$practicaloId/rate');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({'star_rating': starRating});

      print('\n🚀 ENVIANDO PUT...');
      final response = await http
          .put(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      print('📥 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Calificación registrada');
        print('═══════════════════════════════════════════════════════════\n');
        return true;
      } else {
        print('❌ Error: ${response.statusCode}');
        print('═══════════════════════════════════════════════════════════\n');
        return false;
      }
    } catch (e) {
      print('❌ Exception: $e');
      print('═══════════════════════════════════════════════════════════\n');
      return false;
    }
  }

  /// 7️⃣ OBTENER PROMEDIO DE CALIFICACIÓN
  Future<Map<String, dynamic>?> obtenerPromedioCalificacion({
    required String token,
    required String userId,
    required String retoId,
  }) async {
    try {
      print('\n═══════════════════════════════════════════════════════════');
      print('📊 OBTENER PROMEDIO DE CALIFICACIÓN');
      print('═══════════════════════════════════════════════════════════');
      print('   User: $userId');
      print('   Reto: $retoId');

      final url = Uri.parse('$_baseUrl/practicalo/rating/$userId/$retoId');
      final headers = {
        'Authorization': 'Bearer $token',
      };

      print('\n🚀 ENVIANDO GET...');
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      print('📥 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final data = jsonResponse['data'] as Map<String, dynamic>;
        print('✅ Promedio: ${data['average_rating']}');
        print('═══════════════════════════════════════════════════════════\n');
        return data;
      } else {
        print('❌ Error: ${response.statusCode}');
        print('═══════════════════════════════════════════════════════════\n');
        return null;
      }
    } catch (e) {
      print('❌ Exception: $e');
      print('═══════════════════════════════════════════════════════════\n');
      return null;
    }
  }
}
