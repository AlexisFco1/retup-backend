import 'dart:io';
import 'package:flutter/material.dart';
import '../models/social_post_model.dart';
import '../services/social_service.dart';

class SocialProvider extends ChangeNotifier {
  final SocialService _service = SocialService();

  List<SocialPost> _posts = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<SocialPost> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Cargar posts
  Future<void> loadPosts(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _posts = await _service.getPosts(token);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error cargando publicaciones';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refrescar posts
  Future<void> refreshPosts(String token) async {
    try {
      _posts = await _service.getPosts(token);
      notifyListeners();
    } catch (e) {
      print('❌ Error refrescando posts: $e');
    }
  }

  // Crear post de texto
  Future<bool> createTextPost(String text, String token) async {
    final success = await _service.createTextPost(text, token);
    if (success) await refreshPosts(token);
    return success;
  }

  // Crear post de imagen
  Future<bool> createImagePost(
      File image, String? caption, String token) async {
    final success = await _service.createImagePost(image, caption, token);
    if (success) await refreshPosts(token);
    return success;
  }

  // Crear post de audio
  Future<bool> createAudioPost(
      File audio, String? caption, String token) async {
    final success = await _service.createAudioPost(audio, caption, token);
    if (success) await refreshPosts(token);
    return success;
  }

  // Crear encuesta
  Future<bool> createPollPost(
      String question, List<String> options, String token) async {
    final success = await _service.createPollPost(question, options, token);
    if (success) await refreshPosts(token);
    return success;
  }

  // Votar en encuesta
  Future<bool> votePoll(String postId, String optionId, String token) async {
    final success = await _service.votePoll(postId, optionId, token);
    if (success) await refreshPosts(token);
    return success;
  }

  // Toggle like
  Future<bool> toggleLike(String postId, String token) async {
    final success = await _service.toggleLike(postId, token);
    if (success) await refreshPosts(token);
    return success;
  }

  // 🆕 EDITAR POST
  Future<bool> editPost(String postId, String newText, String token) async {
    final success = await _service.editPost(postId, newText, token);
    if (success) await refreshPosts(token);
    return success;
  }

  // 🆕 BORRAR POST
  Future<bool> deletePost(String postId, String token) async {
    final success = await _service.deletePost(postId, token);
    if (success) await refreshPosts(token);
    return success;
  }

  // 🆕 OBTENER COMENTARIOS
  Future<List<SocialComment>> getComments(String postId, String token) async {
    try {
      return await _service.getComments(postId, token);
    } catch (e) {
      print('❌ Error obteniendo comentarios: $e');
      return [];
    }
  }

  // 🆕 AGREGAR COMENTARIO
  Future<SocialComment?> addComment(
      String postId, String text, String token) async {
    final comment = await _service.addComment(postId, text, token);
    if (comment != null) await refreshPosts(token);
    return comment;
  }

  // 🆕 REGISTRAR VISTA
  Future<void> registerView(String postId, String token) async {
    await _service.registerView(postId, token);
  }

  // 🆕 TOGGLE PIN
  Future<void> togglePin(String postId, String token) async {
    await _service.togglePin(postId, token);
    await refreshPosts(token);
  }
}
