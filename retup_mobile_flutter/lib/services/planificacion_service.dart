import 'dart:convert';
import '../models/planificacion_model.dart';
import 'api_service.dart';

class PlanificacionService {
  final ApiService _apiService = ApiService();

  /// GET /api/planificacion
  Future<PlanificacionData> obtener() async {
    final response = await _apiService.get('/planificacion');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PlanificacionData.fromJson(json);
    }

    throw Exception(
      _mensajeError(response.body, 'No se pudo cargar la planificación'),
    );
  }

  /// PUT /api/planificacion
  /// retoId = null para quitar el reto de ese desplegable
  Future<void> asignar({
    required int anio,
    required int mes,
    required int slot,
    String? retoId,
  }) async {
    final response = await _apiService.put(
      '/planificacion',
      data: {
        'anio': anio,
        'mes': mes,
        'slot': slot,
        'reto_id': retoId,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        _mensajeError(response.body, 'No se pudo guardar la planificación'),
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
