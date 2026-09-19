import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  // Cargar el contador de notificaciones sin leer
  Future<void> loadUnreadCount({
    required String userId,
    required String token,
  }) async {
    try {
      final count = await _notificationService.getUnreadCount(
        token: token,
        userId: userId,
      );
      _unreadCount = count;
      notifyListeners();
    } catch (e) {
      print('❌ Error cargando contador: $e');
    }
  }

  // Resetear el contador a 0
  void resetUnreadCount() {
    _unreadCount = 0;
    notifyListeners();
  }

  // Incrementar el contador en 1
  void incrementUnreadCount() {
    _unreadCount++;
    notifyListeners();
  }
}
