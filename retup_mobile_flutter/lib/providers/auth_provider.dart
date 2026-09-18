import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/racha_service.dart';
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

  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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
        _userName = email.split('@')[0];

        // 🆕 REGISTRAR LOGIN EN RACHA para todos los retos
        await _registrarLoginEnRachas();

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
  Future<bool> signup(String email, String password, String name) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _authService.signup(email, password, name);

      if (response['success'] == true) {
        _isAuthenticated = true;
        _token = response['token'];
        _userId = response['userId']?.toString();
        _userEmail = email;
        _userName = name;

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

  // LOGOUT
  Future<void> logout() async {
    try {
      await _authService.logout();
      _isAuthenticated = false;
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
