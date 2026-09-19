import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  final String _baseUrl = 'https://retup-backend.onrender.com/api';

  // 📨 CREAR NOTIFICACIÓN
  Future<Map<String, dynamic>> createNotification({
    required String recipientUserId,
    required String senderUserId,
    required String type,
    required String message,
    required String token,
    String? retoId,
    String? pillId,
  }) async {
    try {
      print('🔔 Enviando notificación...');
      print('   Recipient: $recipientUserId');
      print('   Message: $message');

      final response = await http.post(
        Uri.parse('$_baseUrl/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'recipient_user_id': recipientUserId,
          'sender_user_id': senderUserId,
          'type': type,
          'message': message,
          'reto_id': retoId,
          'pill_id': pillId,
        }),
      );

      print('   Status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        print('✅ Notificación creada exitosamente');
        return jsonData['data'];
      } else {
        throw Exception('Error al crear notificación: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en createNotification: $e');
      rethrow;
    }
  }

  // 📥 OBTENER NOTIFICACIONES SIN LEER
  Future<List<Map<String, dynamic>>> getUnreadNotifications({
    required String userId,
    required String token,
  }) async {
    try {
      print('🔔 Obteniendo notificaciones sin leer de $userId...');

      final response = await http.get(
        Uri.parse('$_baseUrl/notifications/$userId/unread'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('   Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as List;
        print('✅ Notificaciones obtenidas: ${data.length}');
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
            'Error al cargar notificaciones: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en getUnreadNotifications: $e');
      return [];
    }
  }

// 📥 OBTENER TODAS LAS NOTIFICACIONES (LEÍDAS Y NO LEÍDAS)
  Future<List<Map<String, dynamic>>> getAllNotifications({
    required String userId,
    required String token,
  }) async {
    try {
      print('🔔 Obteniendo todas las notificaciones de $userId...');

      final response = await http.get(
        Uri.parse('$_baseUrl/notifications/$userId/all'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('   Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as List;
        print('✅ Todas las notificaciones obtenidas: ${data.length}');
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
            'Error al cargar notificaciones: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en getAllNotifications: $e');
      return [];
    }
  }

  // 🔢 CONTAR NOTIFICACIONES SIN LEER
  Future<int> getUnreadCount({
    required String userId,
    required String token,
  }) async {
    try {
      final notifications = await getUnreadNotifications(
        userId: userId,
        token: token,
      );
      print('🔔 Total notificaciones sin leer: ${notifications.length}');
      return notifications.length;
    } catch (e) {
      print('❌ Error en getUnreadCount: $e');
      return 0;
    }
  }

  // ✅ MARCAR COMO LEÍDA
  Future<void> markAsRead({
    required String notificationId,
    required String token,
  }) async {
    try {
      print('🔔 Marcando notificación como leída: $notificationId');

      final response = await http.put(
        Uri.parse('$_baseUrl/notifications/$notificationId/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('   Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Notificación marcada como leída');
      } else {
        throw Exception('Error al marcar como leída: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en markAsRead: $e');
      rethrow;
    }
  }

  // ✅ MARCAR MÚLTIPLES NOTIFICACIONES COMO LEÍDAS (BATCH)
  Future<void> markAllAsRead({
    required List<String> notificationIds,
    required String token,
  }) async {
    try {
      print(
          '🔔 Marcando ${notificationIds.length} notificaciones como leídas...');

      final response = await http.put(
        Uri.parse('$_baseUrl/notifications/batch/mark-as-read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'notification_ids': notificationIds,
        }),
      );

      print('   Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print(
            '✅ ${jsonData['marked_count']} notificaciones marcadas como leídas');
      } else {
        throw Exception('Error al marcar como leídas: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en markAllAsRead: $e');
      rethrow;
    }
  }
}
