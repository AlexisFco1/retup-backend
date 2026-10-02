import 'dart:convert';
import '../models/reto_model.dart';
import '../models/pildora_model.dart';
import 'api_service.dart';

/// Píldora del Top 10 mejor calificadas
class PildoraDestacada {
  final Pildora pildora;
  final String retoTitle;
  final double promedio;
  final int totalCalificaciones;

  PildoraDestacada({
    required this.pildora,
    required this.retoTitle,
    required this.promedio,
    required this.totalCalificaciones,
  });

  factory PildoraDestacada.fromJson(Map<String, dynamic> json) {
    return PildoraDestacada(
      pildora: Pildora.fromJson(json),
      retoTitle: json['reto_title'] ?? '',
      promedio: (json['promedio'] as num?)?.toDouble() ?? 0.0,
      totalCalificaciones: (json['total_calificaciones'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Reto de los Top 10 (más inscritos / mejor calificados)
class RetoDestacado {
  final Reto reto;
  final int inscritos;
  final double promedio;
  final int totalUsuarios;
  final int totalPildoras;

  RetoDestacado({
    required this.reto,
    required this.inscritos,
    required this.promedio,
    required this.totalUsuarios,
    required this.totalPildoras,
  });

  factory RetoDestacado.fromJson(Map<String, dynamic> json) {
    return RetoDestacado(
      reto: Reto.fromJson(json),
      inscritos: (json['inscritos'] as num?)?.toInt() ?? 0,
      promedio: (json['promedio'] as num?)?.toDouble() ?? 0.0,
      totalUsuarios: (json['total_usuarios'] as num?)?.toInt() ?? 0,
      totalPildoras: (json['total_pildoras'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Todo lo que muestra la pantalla Inicio (menos el reto inscrito)
class HomeDestacados {
  final List<PildoraDestacada> topPildoras;
  final List<RetoDestacado> topInscritos;
  final List<RetoDestacado> topCalificados;

  HomeDestacados({
    required this.topPildoras,
    required this.topInscritos,
    required this.topCalificados,
  });

  factory HomeDestacados.fromJson(Map<String, dynamic> json) {
    List<T> _lista<T>(
        String clave, T Function(Map<String, dynamic>) convertir) {
      final datos = json[clave];
      if (datos is! List) return [];
      return datos
          .map((e) => convertir(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return HomeDestacados(
      topPildoras: _lista('top_pildoras', PildoraDestacada.fromJson),
      topInscritos: _lista('top_inscritos', RetoDestacado.fromJson),
      topCalificados: _lista('top_calificados', RetoDestacado.fromJson),
    );
  }
}

/// Estado de una píldora suelta para el usuario
class EstadoPildoraSuelta {
  final int? selfAssessmentScore;
  final bool completadaSuelta;
  final bool completadaEnReto;

  EstadoPildoraSuelta({
    this.selfAssessmentScore,
    required this.completadaSuelta,
    required this.completadaEnReto,
  });

  /// Ya la hizo (como suelta o dentro de su reto) → solo lectura
  bool get yaLaHizo => completadaSuelta || completadaEnReto;

  factory EstadoPildoraSuelta.fromJson(Map<String, dynamic> json) {
    return EstadoPildoraSuelta(
      selfAssessmentScore: (json['self_assesment_score'] as num?)?.toInt(),
      completadaSuelta: json['is_completed'] == true,
      completadaEnReto: json['completada_en_reto'] == true,
    );
  }
}

class HomeService {
  final ApiService _apiService = ApiService();

  /// GET /api/home/destacados
  Future<HomeDestacados> obtenerDestacados() async {
    final response = await _apiService.get('/home/destacados');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return HomeDestacados.fromJson(json);
    }

    throw Exception(
      _mensajeError(response.body, 'No se pudieron cargar los destacados'),
    );
  }

  // ═══════════════ PÍLDORAS SUELTAS ═══════════════
  // No afectan Rachas ni rankings (se guardan en pildoras_sueltas)

  /// GET /api/pildoras-sueltas/:pillId
  Future<EstadoPildoraSuelta> obtenerEstadoSuelta(String pillId) async {
    final response = await _apiService.get('/pildoras-sueltas/$pillId');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return EstadoPildoraSuelta.fromJson(
        Map<String, dynamic>.from(json['data'] as Map),
      );
    }

    throw Exception(
      _mensajeError(response.body, 'No se pudo cargar la píldora'),
    );
  }

  /// PUT /api/pildoras-sueltas/:pillId/autopercepcion
  Future<void> guardarAutopercepcionSuelta(String pillId, int score) async {
    final response = await _apiService.put(
      '/pildoras-sueltas/$pillId/autopercepcion',
      data: jsonEncode({'self_assesment_score': score}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        _mensajeError(response.body, 'No se pudo guardar la autopercepción'),
      );
    }
  }

  /// POST /api/pildoras-sueltas/:pillId/completar
  Future<void> completarSuelta(
    String pillId, {
    int? pillRating, // Opcional
    String? pillFeedbackMessage,
  }) async {
    final response = await _apiService.post(
      '/pildoras-sueltas/$pillId/completar',
      data: jsonEncode({
        'pill_rating': pillRating,
        'pill_feedback_message': pillFeedbackMessage,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        _mensajeError(response.body, 'No se pudo terminar la píldora'),
      );
    }
  }

  /// PUT /api/pildoras-sueltas/:pillId/calificar (píldora ya completada)
  Future<void> calificarSuelta(
    String pillId, {
    int? pillRating,
    String? pillFeedbackMessage,
  }) async {
    final response = await _apiService.put(
      '/pildoras-sueltas/$pillId/calificar',
      data: jsonEncode({
        'pill_rating': pillRating,
        'pill_feedback_message': pillFeedbackMessage,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        _mensajeError(response.body, 'No se pudo guardar la calificación'),
      );
    }
  }

  /// Extrae el mensaje de error que devuelve el backend ({ error: '...' })
  String _mensajeError(String body, String porDefecto) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json['error'] != null) {
        return json['error'].toString();
      }
    } catch (_) {}
    return porDefecto;
  }
}
