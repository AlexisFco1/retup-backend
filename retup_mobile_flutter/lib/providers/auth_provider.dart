import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/racha_service.dart';
import '../services/eventos_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final RachaService _rachaService = RachaService();

  bool _isAuthenticated = false;
  String? _userId;
  String? _userName;
  String? _userEmail;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;
  bool _debeCambiarPassword = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get debeCambiarPassword => _debeCambiarPassword;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Nombre completo: nombre + apellidos → full_name → parte del email
  String _nombreCompleto(dynamic user, String email) {
    if (user is Map) {
      final partes = [
        user['first_name'],
        user['last_name_1'],
        user['last_name_2'],
      ]
          .where((p) => p != null && p.toString().trim().isNotEmpty)
          .map((p) => p.toString().trim())
          .toList();
      if (partes.isNotEmpty) return partes.join(' ');

      final fullName = user['full_name']?.toString().trim() ?? '';
      if (fullName.isNotEmpty) return fullName;
    }
    return email.split('@')[0];
  }

  // LOGIN REAL
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _authService.login(email, password);

      if (response['success'] == true) {
        _isAuthenticated = true;
        _token = response['token'];
        _userId = response['userId']?.toString();
        _userEmail = email;
        _userName = _nombreCompleto(response['user'], email);
        // Entró con una contraseña temporal: la app le pedirá crear una propia
        _debeCambiarPassword = response['user'] is Map &&
            response['user']['debe_cambiar_password'] == true;

        // 🆕 REGISTRAR LOGIN EN RACHA para todos los retos
        await _registrarLoginEnRachas();

        // Dashboard: inicio de sesión = apertura de la app (sin await, no bloquea)
        EventosService().registrarActividad('login');

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Error al iniciar sesión';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error de conexión: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // SIGNUP REAL
  // SIGNUP REAL
  Future<bool> signup({
    required String email,
    required String password,
    required String firstName,
    required String lastName1,
    String lastName2 = '',
    int? age,
    String? gender,
    String? department,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _authService.signup(
        email: email,
        password: password,
        firstName: firstName,
        lastName1: lastName1,
        lastName2: lastName2,
        age: age,
        gender: gender,
        department: department,
      );

      if (response['success'] == true) {
        _isAuthenticated = true;
        _token = response['token'];
        _userId = response['userId']?.toString();
        _userEmail = email;
        _userName = [firstName, lastName1].join(' ');

        // 🆕 REGISTRAR LOGIN EN RACHA para todos los retos
        await _registrarLoginEnRachas();

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Error al registrarse';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error de conexión: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 🆕 MÉTODO PARA REGISTRAR LOGIN Y VERIFICAR RACHA
  Future<void> _registrarLoginEnRachas() async {
    if (_userId == null || _token == null) return;

    try {
      print('✅ Login registrado en el sistema de racha');

      // Aquí se puede agregar más lógica si es necesaria
      // Por ahora solo se registra en backend
    } catch (e) {
      print('⚠️ Error registrando login en racha: $e');
      // No lanzar error, solo loguear - no debe bloquear el login principal
    }
  }

  // 🆕 MÉTODO PARA VERIFICAR RACHA (se llama desde la UI después de login)
  Future<void> verificarRachaAlLogin() async {
    if (_userId == null || _token == null) return;

    try {
      print('🔍 Verificando racha después del login...');
      await _rachaService.verificarRacha(_userId!, _token!);
      print('✅ Verificación de racha completada');
    } catch (e) {
      print('⚠️ Error verificando racha: $e');
      // No lanzar error - esto es un verificación, no debe bloquear
    }
  }

  // CAMBIAR LA CONTRASEÑA TEMPORAL
  // Al cambiarla, Supabase cierra las sesiones abiertas: por eso se vuelve
  // a iniciar sesión automáticamente con la contraseña nueva.
  Future<bool> cambiarPasswordTemporal(String passwordNueva) async {
    if (_token == null || _userEmail == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final respuesta =
        await _authService.cambiarPasswordTemporal(_token!, passwordNueva);
    if (respuesta['success'] != true) {
      _errorMessage =
          respuesta['message'] ?? 'No se pudo cambiar la contraseña';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // Nueva sesión con la contraseña nueva (debe_cambiar_password ya es false)
    final email = _userEmail!;
    final entro = await login(email, passwordNueva);
    if (!entro) {
      // Caso raro: la contraseña sí se cambió; que entre de nuevo a mano
      await logout();
      _errorMessage =
          'Tu contraseña se ha cambiado. Inicia sesión con la nueva.';
      notifyListeners();
    }
    return entro;
  }

  // LOGOUT
  Future<void> logout() async {
    try {
      await _authService.logout();
      _isAuthenticated = false;
      _debeCambiarPassword = false;
      _userId = null;
      _userName = null;
      _userEmail = null;
      _token = null;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al cerrar sesión: ${e.toString()}';
      notifyListeners();
    }
  }
}
