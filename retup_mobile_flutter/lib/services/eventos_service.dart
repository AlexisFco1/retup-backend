import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'api_service.dart';

/// ═══════════════════════════════════════════════════════════════════
/// EVENTOS DE ACTIVIDAD (para los indicadores del Dashboard web)
/// ───────────────────────────────────────────────────────────────────
/// REGLA DE ORO: este servicio NUNCA lanza errores ni bloquea la UI.
/// Si un envío falla, la app sigue funcionando exactamente igual.
/// ═══════════════════════════════════════════════════════════════════
class EventosService {
  static final EventosService _instance = EventosService._internal();
  factory EventosService() => _instance;
  EventosService._internal();

  final ApiService _api = ApiService();

  /// Registra un evento general.
  /// tipo: 'app_open' | 'app_resume' | 'login' | 'pill_start' | 'pill_complete'
  /// origen: 'reto' | 'suelta' (solo para eventos de píldora)
  Future<void> registrarActividad(
    String tipo, {
    String? retoId,
    String? pillId,
    String? origen,
  }) async {
    try {
      final body = jsonEncode({
        'event_type': tipo,
        if (retoId != null && retoId.isNotEmpty) 'reto_id': retoId,
        if (pillId != null && pillId.isNotEmpty) 'pill_id': pillId,
        if (origen != null) 'origen': origen,
      });

      final respuesta = await _api.post('/eventos/actividad', data: body);

      if (respuesta.statusCode != 201) {
        print(
            '⚠️ [Eventos] actividad "$tipo" respondió ${respuesta.statusCode}');
      }
    } catch (e) {
      print('⚠️ [Eventos] No se pudo registrar actividad "$tipo": $e');
    }
  }

  /// Envía una o varias secciones visitadas de una píldora.
  Future<void> enviarSecciones(List<Map<String, dynamic>> eventos) async {
    if (eventos.isEmpty) return;
    try {
      final body = jsonEncode({'eventos': eventos});

      final respuesta = await _api.post('/eventos/secciones', data: body);

      if (respuesta.statusCode != 201) {
        print('⚠️ [Eventos] secciones respondió ${respuesta.statusCode}');
      }
    } catch (e) {
      print('⚠️ [Eventos] No se pudieron enviar secciones: $e');
    }
  }
}

/// ═══════════════════════════════════════════════════════════════════
/// RECORRIDO DE UNA PÍLDORA
/// Mide UNA visita a una píldora, sección por sección.
/// Uso desde la pantalla:
///   entrar(1)                       -> al mostrar la primera sección
///   cambiarDeSeccion('siguiente', 2) -> al pulsar Siguiente
///   cambiarDeSeccion('anterior', 1)  -> al pulsar Anterior
///   salir('enviar')                 -> al completar la píldora
///   salir('salir')                  -> al abandonar la pantalla
/// ═══════════════════════════════════════════════════════════════════
class RecorridoPildora {
  final String pillId;
  final String? retoId;
  final String origen; // 'reto' | 'suelta'

  /// Identifica esta visita (si vuelve a entrar otro día, será otra visita)
  final String sesionId = const Uuid().v4();

  int? _seccionAbierta;
  DateTime? _horaEntrada;

  RecorridoPildora({
    required this.pillId,
    this.retoId,
    this.origen = 'reto',
  });

  bool get haySeccionAbierta => _seccionAbierta != null;

  /// Marca la entrada a una sección (número de pantalla 1..9)
  void entrar(int numeroSeccion) {
    _seccionAbierta = numeroSeccion;
    _horaEntrada = DateTime.now().toUtc();
  }

  /// Cierra la sección abierta y la envía al backend (sin bloquear la UI).
  /// exitType: 'siguiente' | 'anterior' | 'enviar' | 'salir'
  void salir(String exitType) {
    if (_seccionAbierta == null || _horaEntrada == null) return;

    final evento = <String, dynamic>{
      'pill_id': pillId,
      if (retoId != null && retoId!.isNotEmpty) 'reto_id': retoId,
      'origen': origen,
      'pill_session_id': sesionId,
      'section_number': _seccionAbierta,
      'entered_at': _horaEntrada!.toIso8601String(),
      'left_at': DateTime.now().toUtc().toIso8601String(),
      'exit_type': exitType,
    };

    // Se limpia ANTES de enviar: así nunca se envía dos veces la misma sección
    _seccionAbierta = null;
    _horaEntrada = null;

    // Sin await a propósito: la pantalla no espera a la red
    EventosService().enviarSecciones([evento]);
  }

  /// Cierra la sección actual y abre la siguiente en un solo paso
  void cambiarDeSeccion(String exitType, int nuevaSeccion) {
    salir(exitType);
    entrar(nuevaSeccion);
  }
}
