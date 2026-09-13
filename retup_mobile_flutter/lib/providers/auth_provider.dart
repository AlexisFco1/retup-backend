import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/racha_service.dart'; // ← AGREGAR ESTE IMPORT
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final RachaService _rachaService = RachaService(); // ← AGREGAR ESTA LÍNEA

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

        // ← AGREGAR ESTAS LÍNEAS: Registrar login en rachas
        if (_userId != null && _token != null) {
          await _rachaService.registrarLogin(_userId!, _token!);
        }

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

        // ← AGREGAR ESTAS LÍNEAS: Registrar login en rachas (signup también es primer login)
        if (_userId != null) {
          await _rachaService.registrarLogin(_userId!, _token!); // ✅
        }

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
