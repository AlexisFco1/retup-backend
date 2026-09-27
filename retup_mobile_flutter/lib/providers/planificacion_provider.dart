import 'package:flutter/material.dart';
import '../models/planificacion_model.dart';
import '../models/reto_model.dart';
import '../services/planificacion_service.dart';

class PlanificacionProvider extends ChangeNotifier {
  final PlanificacionService _service = PlanificacionService();

  PlanificacionData? _data;
  bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _guardando = {};
  int _version = 0; // Sirve para refrescar los desplegables tras guardar

  PlanificacionData? get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get version => _version;

  String _clave(int anio, int mes, int slot) => '$anio-$mes-$slot';

  bool estaGuardando(MesPlanificacion mes, int slot) =>
      _guardando.contains(_clave(mes.anio, mes.mes, slot));

  /// Carga (o recarga) toda la planificación desde el backend
  Future<void> cargar() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _data = await _service.obtener();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ Error cargando planificación: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Guarda o quita (retoId = null) el reto de un desplegable.
  /// Devuelve null si todo salió bien, o el mensaje de error.
  Future<String?> asignarReto(
      MesPlanificacion mes, int slot, String? retoId) async {
    final clave = _clave(mes.anio, mes.mes, slot);
    _guardando.add(clave);
    notifyListeners();

    String? error;
    try {
      await _service.asignar(
        anio: mes.anio,
        mes: mes.mes,
        slot: slot,
        retoId: retoId,
      );
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      print('❌ Error guardando planificación: $error');
    }

    // Recargamos siempre para que la pantalla muestre lo que hay en la BD
    try {
      _data = await _service.obtener();
    } catch (_) {}

    _guardando.remove(clave);
    _version++;
    notifyListeners();
    return error;
  }

  /// Retos que pueden aparecer en un desplegable concreto
  List<Reto> opcionesPara(MesPlanificacion mes, int slot) {
    final data = _data;
    if (data == null) return [];

    // Retos ya elegidos en OTROS desplegables (cualquier mes)
    final usados = <String>{};
    for (final m in data.meses) {
      for (final p in m.planes) {
        final esEsteDesplegable = m.esMismoMes(mes) && p.slot == slot;
        if (!esEsteDesplegable) usados.add(p.retoId);
      }
    }

    final actual = mes.retoEnSlot(slot);

    return data.retos.where((r) {
      if (r.id == actual) return true; // Mantener el valor actual en la lista
      if (usados.contains(r.id)) return false;
      if (data.retosCompletados.contains(r.id)) return false;
      return true;
    }).toList();
  }
}
