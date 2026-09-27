import 'reto_model.dart';

/// Un reto elegido en un desplegable (slot 1 o 2) de un mes
class PlanSlot {
  final int slot;
  final String retoId;

  PlanSlot({required this.slot, required this.retoId});

  factory PlanSlot.fromJson(Map<String, dynamic> json) {
    return PlanSlot(
      slot: (json['slot'] as num).toInt(),
      retoId: json['reto_id'] ?? '',
    );
  }
}

/// Un mes de la sección "Retos Planificados"
class MesPlanificacion {
  final int anio;
  final int mes;
  final String nombre; // Ej: "Octubre 2026"
  final String fechaBloqueo; // 'YYYY-MM-DD'
  final bool bloqueado;
  final List<PlanSlot> planes;

  MesPlanificacion({
    required this.anio,
    required this.mes,
    required this.nombre,
    required this.fechaBloqueo,
    required this.bloqueado,
    required this.planes,
  });

  factory MesPlanificacion.fromJson(Map<String, dynamic> json) {
    return MesPlanificacion(
      anio: (json['anio'] as num).toInt(),
      mes: (json['mes'] as num).toInt(),
      nombre: json['nombre'] ?? '',
      fechaBloqueo: json['fecha_bloqueo'] ?? '',
      bloqueado: json['bloqueado'] == true,
      planes: ((json['planes'] as List?) ?? [])
          .map((p) => PlanSlot.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Id del reto elegido en ese desplegable, o null si está vacío
  String? retoEnSlot(int slot) {
    for (final p in planes) {
      if (p.slot == slot) return p.retoId;
    }
    return null;
  }

  /// Solo el nombre del mes, sin el año. Ej: "Octubre"
  String get nombreMes => nombre.split(' ').first;

  /// Fecha de bloqueo en formato DD/MM/YYYY
  String get fechaBloqueoTexto {
    final partes = fechaBloqueo.split('-');
    if (partes.length != 3) return fechaBloqueo;
    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  bool esMismoMes(MesPlanificacion otro) =>
      anio == otro.anio && mes == otro.mes;
}

/// Toda la información que necesita la Home
class PlanificacionData {
  final String hoy;
  final String mesVigenteNombre;
  final List<MesPlanificacion> meses;
  final List<Reto> retos; // Retos de la empresa
  final Set<String> retosCompletados; // Ids de retos ya completados
  final List<Reto> retosDelMes; // Retos inscritos en el mes vigente

  PlanificacionData({
    required this.hoy,
    required this.mesVigenteNombre,
    required this.meses,
    required this.retos,
    required this.retosCompletados,
    required this.retosDelMes,
  });

  factory PlanificacionData.fromJson(Map<String, dynamic> json) {
    final mesVigente = (json['mes_vigente'] as Map<String, dynamic>?) ?? {};
    return PlanificacionData(
      hoy: json['hoy'] ?? '',
      mesVigenteNombre: mesVigente['nombre'] ?? '',
      meses: ((json['meses'] as List?) ?? [])
          .map((m) => MesPlanificacion.fromJson(m as Map<String, dynamic>))
          .toList(),
      retos: ((json['retos'] as List?) ?? [])
          .map((r) => Reto.fromJson(r as Map<String, dynamic>))
          .toList(),
      retosCompletados: ((json['retos_completados'] as List?) ?? [])
          .map((id) => id.toString())
          .toSet(),
      retosDelMes: ((json['retos_del_mes'] as List?) ?? [])
          .map((r) => Reto.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Título de un reto a partir de su id
  String tituloReto(String retoId) {
    for (final r in retos) {
      if (r.id == retoId) return r.title;
    }
    return 'Reto';
  }
}
