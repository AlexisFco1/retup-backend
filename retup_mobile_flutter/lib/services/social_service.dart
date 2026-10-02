import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/social_post_model.dart';
import 'api_service.dart';

class SocialService {
  final ApiService _api = ApiService();

  // Obtener todas las publicaciones
  Future<List<SocialPost>> getPosts(String token,
      {int page = 1, int limit = 20}) async {
    try {
      final response = await _api.get('/social/posts?page=$page&limit=$limit');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final list = data['posts'] ?? data['data'] ?? [];
          return (list as List).map((p) => SocialPost.fromJson(p)).toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ Error obteniendo posts: $e');
      return [];
    }
  }

  // Crear publicación de texto
  Future<bool> createTextPost(String textContent, String token) async {
    try {
      // jsonEncode escapa saltos de línea y comillas (si no, el JSON se rompe)
      final response = await _api.post('/social/posts',
          data: jsonEncode({
            'content_type': 'text',
            'text_content': textContent,
          }));
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('❌ Error creando post de texto: $e');
      return false;
    }
  }

  // Subir imagen y crear post
  Future<bool> createImagePost(
      File imageFile, String? caption, String token) async {
    try {
      final supabase = Supabase.instance.client;
      final fileName =
          'images/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';

      await supabase.storage.from('social-media').upload(fileName, imageFile);
      final imageUrl =
          supabase.storage.from('social-media').getPublicUrl(fileName);

      final response = await _api.post('/social/posts', data: {
        'content_type': 'image',
        'text_content': caption ?? '',
        'media_url': imageUrl,
      });
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('❌ Error creando post de imagen: $e');
      return false;
    }
  }

  // Subir audio y crear post
  Future<bool> createAudioPost(
      File audioFile, String? caption, String token) async {
    try {
      final supabase = Supabase.instance.client;
      final fileName = 'audios/${DateTime.now().millisecondsSinceEpoch}.m4a';

      await supabase.storage.from('social-media').upload(fileName, audioFile);
      final audioUrl =
          supabase.storage.from('social-media').getPublicUrl(fileName);

      final response = await _api.post('/social/posts', data: {
        'content_type': 'audio',
        'text_content': caption ?? '',
        'media_url': audioUrl,
      });
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('❌ Error creando post de audio: $e');
      return false;
    }
  }

  // Crear encuesta
  Future<bool> createPollPost(
      String question, List<String> options, String token) async {
    try {
      final response = await _api.post('/social/posts', data: {
        'content_type': 'poll',
        'text_content': question,
        'poll_options': options,
      });
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('❌ Error creando encuesta: $e');
      return false;
    }
  }

  // Votar en encuesta
  Future<bool> votePoll(String postId, String optionId, String token) async {
    try {
      final response = await _api.post('/social/polls/vote', data: {
        'post_id': postId,
        'poll_option_id': optionId,
      });
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error votando: $e');
      return false;
    }
  }

  // Like / Unlike
  Future<bool> toggleLike(String postId, String token) async {
    try {
      final response = await _api.post('/social/posts/$postId/like');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error en like: $e');
      return false;
    }
  }

  // 🆕 EDITAR POST
  Future<bool> editPost(String postId, String newText, String token) async {
    try {
      final response = await _api.put('/social/posts/$postId', data: {
        'text_content': newText,
      });
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error editando post: $e');
      return false;
    }
  }

  // 🆕 BORRAR POST
  Future<bool> deletePost(String postId, String token) async {
    try {
      final response = await _api.delete('/social/posts/$postId');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error borrando post: $e');
      return false;
    }
  }

  // 🆕 OBTENER COMENTARIOS
  Future<List<SocialComment>> getComments(String postId, String token) async {
    try {
      final response = await _api.get('/social/posts/$postId/comments');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((c) => SocialComment.fromJson(c))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ Error obteniendo comentarios: $e');
      return [];
    }
  }

  // 🆕 CREAR COMENTARIO
  Future<SocialComment?> addComment(
      String postId, String text, String token) async {
    try {
      final response = await _api.post('/social/posts/$postId/comments', data: {
        'comment_text': text,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return SocialComment.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error creando comentario: $e');
      return null;
    }
  }

  // 🆕 REGISTRAR VISTA
  Future<void> registerView(String postId, String token) async {
    try {
      await _api.post('/social/posts/$postId/view');
    } catch (e) {
      print('❌ Error registrando vista: $e');
    }
  }

  // 🆕 TOGGLE PIN
  Future<bool> togglePin(String postId, String token) async {
    try {
      final response = await _api.post('/social/posts/$postId/pin');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['pinned'] ?? false;
      }
      return false;
    } catch (e) {
      print('❌ Error en pin: $e');
      return false;
    }
  }
}
