import 'package:flutter/widgets.dart';
import '../services/api_service.dart';
import '../services/eventos_service.dart';

/// ═══════════════════════════════════════════════════════════════════
/// OBSERVADOR DE ACTIVIDAD (para el Dashboard web)
/// Registra 'app_resume' cuando la app vuelve a primer plano, para la
/// "Matriz de sesiones por día y hora". Nunca lanza errores.
/// ═══════════════════════════════════════════════════════════════════
class ObservadorActividad with WidgetsBindingObserver {
  DateTime? _ultimoEnvio;

  /// Evita registrar varios regresos seguidos (ej. abrir y cerrar la galería)
  static const Duration _intervaloMinimo = Duration(minutes: 1);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _registrarRegreso();
    }
  }

  Future<void> _registrarRegreso() async {
    try {
      final ahora = DateTime.now();
      if (_ultimoEnvio != null &&
          ahora.difference(_ultimoEnvio!) < _intervaloMinimo) {
        return;
      }

      // Solo si hay sesión iniciada (el logout borra el token)
      final token = await ApiService().getToken();
      if (token == null || token.isEmpty) return;

      _ultimoEnvio = ahora;
      await EventosService().registrarActividad('app_resume');
    } catch (e) {
      print('⚠️ [Eventos] No se pudo registrar app_resume: $e');
    }
  }
}
