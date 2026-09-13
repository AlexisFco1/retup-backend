import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class FeedbackService {
  static const String _baseUrl = 'https://retup-backend.onrender.com/api';

  /// Registra un voto de feedback a través del backend
  Future<void> registerFeedbackVote({
    required String token,
    required String respondentUserId,
    required String nominatedUserId,
    required String retoId,
    required String pillId,
    required int sectionNumber,
    required String voteType, // 'positive' o 'negative'
  }) async {
    try {
      print('\n═══════════════════════════════════════════════════════════');
      print('📝 [PASO 1] INICIANDO REGISTRO DE VOTO');
      print('═══════════════════════════════════════════════════════════');
      print('   Votante (respondent): $respondentUserId');
      print('   Votado (nominated): $nominatedUserId');
      print('   Reto ID: $retoId');
      print('   Píldora ID: $pillId');
      print('   Sección: $sectionNumber');
      print('   Tipo de voto: $voteType');

      final url = Uri.parse('$_baseUrl/nominations');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      print('\n🔐 [PASO 2] HEADERS');
      print('   Content-Type: application/json');
      print('   Authorization: Bearer ${token.substring(0, 20)}...');

      final body = jsonEncode({
        'respondent_user_id': respondentUserId,
        'nominated_user_id': nominatedUserId,
        'reto_id': retoId,
        'pill_id': pillId,
        'section_number': sectionNumber,
        'vote_type': voteType,
      });

      print('\n📦 [PASO 3] BODY (JSON)');
      print('   $body');

      print('\n🚀 [PASO 4] ENVIANDO POST A BACKEND...');
      print('   URL: $_baseUrl/nominations');
      print('   Esperando respuesta...');

      final response = await http
          .post(
        url,
        headers: headers,
        body: body,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏱️ TIMEOUT: La solicitud tardó más de 30 segundos');
          throw TimeoutException('HTTP request timeout after 30 seconds');
        },
      );

      print('\n📥 [PASO 5] RESPUESTA RECIBIDA');
      print('   Status Code: ${response.statusCode}');
      print('   Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('\n✅ [ÉXITO] Voto registrado correctamente en base de datos');
        print('═══════════════════════════════════════════════════════════\n');
      } else {
        print('\n❌ [ERROR HTTP] El servidor retornó un error');
        print('   Status: ${response.statusCode}');
        print('   Respuesta: ${response.body}');
        print('═══════════════════════════════════════════════════════════\n');
        throw Exception(
            'Error registrando voto: ${response.statusCode} - ${response.body}');
      }
    } on TimeoutException catch (e) {
      print('\n❌ [ERROR TIMEOUT] $e');
      print('═══════════════════════════════════════════════════════════\n');
      rethrow;
    } catch (e) {
      print('\n❌ [ERROR] $e');
      print('═══════════════════════════════════════════════════════════\n');
      rethrow;
    }
  }

  /// Calcula la puntuación de feedback para un usuario
  /// Consulta el backend para obtener el score basado en votos anónimos
  Future<double> calculateUserFeedbackScore(String userId, String token) async {
    try {
      print('\n═══════════════════════════════════════════════════════════');
      print('📊 [PASO 1] CALCULANDO FEEDBACK SCORE');
      print('═══════════════════════════════════════════════════════════');
      print('   Usuario ID: $userId');

      final url = Uri.parse('$_baseUrl/nominations/$userId/feedback-score');

      print('\n🚀 [PASO 2] ENVIANDO GET A BACKEND...');
      print('   URL: $_baseUrl/nominations/$userId/feedback-score');
      print('   Esperando respuesta...');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏱️ TIMEOUT: La solicitud tardó más de 30 segundos');
          throw TimeoutException('HTTP request timeout after 30 seconds');
        },
      );

      print('\n📥 [PASO 3] RESPUESTA RECIBIDA');
      print('   Status Code: ${response.statusCode}');
      print('   Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        print('\n✅ [PARSING JSON] Decodificando respuesta...');
        print('   JSON: $jsonResponse');

        final double feedbackScore =
            (jsonResponse['feedbackScore'] ?? 0.0).toDouble();
        final int totalVoters = jsonResponse['totalVoters'] ?? 0;
        final int positiveVoters = jsonResponse['positiveVoters'] ?? 0;
        final int totalVotes = jsonResponse['totalVotes'] ?? 0;

        print('\n📈 [RESULTADO] Feedback Score Calculado');
        print('   Score: $feedbackScore%');
        print('   Votantes válidos: $totalVoters');
        print('   Votantes positivos: $positiveVoters');
        print('   Total de votos: $totalVotes');
        print('═══════════════════════════════════════════════════════════\n');

        return feedbackScore;
      } else {
        print('\n❌ [ERROR HTTP] El servidor retornó un error');
        print('   Status: ${response.statusCode}');
        print('   Respuesta: ${response.body}');
        print('═══════════════════════════════════════════════════════════\n');
        throw Exception(
            'Error obteniendo feedback score: ${response.statusCode} - ${response.body}');
      }
    } on TimeoutException catch (e) {
      print('\n❌ [ERROR TIMEOUT] $e');
      print('═══════════════════════════════════════════════════════════\n');
      return 0.0;
    } catch (e) {
      print('\n❌ [ERROR] $e');
      print('═══════════════════════════════════════════════════════════\n');
      return 0.0;
    }
  }
}
