import 'package:flutter/material.dart';
import '../services/retos_service.dart';
import '../models/reto_model.dart';

// Clase local para agregar datos del frontend
class RetoLocal {
  final Reto reto;
  final String emoji;
  final int totalPildoras;
  int pildorasCompletadas;

  RetoLocal({
    required this.reto,
    required this.emoji,
    required this.totalPildoras,
    this.pildorasCompletadas = 0,
  });

  double get progreso => pildorasCompletadas / totalPildoras;
}

class RetoProvider extends ChangeNotifier {
  final RetosService _retosService = RetosService();

  List<RetoLocal> _retos = [];

  RetoLocal? _retoSeleccionado;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<RetoLocal> get retos => _retos;
  RetoLocal? get retoSeleccionado => _retoSeleccionado;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Cargar todos los retos del backend y combinarlos con datos locales
  Future<void> cargarRetos() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      Future.microtask(() => notifyListeners());

      final retosBackend = await _retosService.getAll();

      // Combinar con datos locales
      _retos = retosBackend.map((reto) {
        return RetoLocal(
          reto: reto,
          emoji: _getEmojiLocal(reto.id),
          totalPildoras: reto.totalPills ?? 10,
          pildorasCompletadas: _getPillorasCompletadasLocal(reto.id),
        );
      }).toList();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cargar retos del usuario actual
  Future<void> cargarRetosDelUsuario(String userId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      Future.microtask(() => notifyListeners());

      final retosBackend = await _retosService.getByUserId(userId);

      _retos = retosBackend.map((reto) {
        return RetoLocal(
          reto: reto,
          emoji: _getEmojiLocal(reto.id),
          totalPildoras: reto.totalPills ?? 10,
          pildorasCompletadas: _getPillorasCompletadasLocal(reto.id),
        );
      }).toList();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Seleccionar reto
  void seleccionarReto(RetoLocal retoLocal) {
    _retoSeleccionado = retoLocal;
    notifyListeners();
  }

  // Completar píldora
  Future<void> completarPildora(String retoId) async {
    try {
      final retoLocal = _retos.firstWhere((r) => r.reto.id == retoId);
      if (retoLocal.pildorasCompletadas < retoLocal.totalPildoras) {
        retoLocal.pildorasCompletadas++;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Métodos privados para obtener datos locales
  String _getEmojiLocal(String retoId) {
    // Usa el retoId como key para emojis
    final emojisLocal = {
      '97a7b8bb-c155-43d3-8667-194a998cc10d': '🎯', // Habla que te escuchen
    };
    return emojisLocal[retoId] ?? '📚';
  }

  int _getPillorasCompletadasLocal(String retoId) {
    // Por defecto, ninguna píldora completada al cargar
    return 0;
  }

  // Crear reto
  Future<bool> crearReto(Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      notifyListeners();

      final newReto = await _retosService.create(data);
      if (newReto != null) {
        _retos.add(RetoLocal(
          reto: newReto,
          emoji: '📚',
          totalPildoras: newReto.totalPills ?? 10,
        ));
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Actualizar reto
  Future<bool> actualizarReto(String id, Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      notifyListeners();

      final success = await _retosService.update(id, data);
      if (success) {
        await cargarRetos();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Eliminar reto
  Future<bool> eliminarReto(String id) async {
    try {
      _isLoading = true;
      notifyListeners();

      final success = await _retosService.delete(id);
      if (success) {
        _retos.removeWhere((retoLocal) => retoLocal.reto.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
