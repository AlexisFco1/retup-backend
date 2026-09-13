import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/feedback_service.dart';
import '../widgets/custom_bottom_navigation_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late FeedbackService _feedbackService;
  int _currentNavIndex = 4;
  double _feedbackScore = 0.0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _feedbackService = FeedbackService();
    _loadFeedbackScore();
  }

  Future<void> _loadFeedbackScore() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.userId;

      if (userId == null) {
        setState(() {
          _errorMessage = 'No hay usuario autenticado';
          _isLoading = false;
        });
        return;
      }

      final token = authProvider.token ?? '';
      final score =
          await _feedbackService.calculateUserFeedbackScore(userId, token);

      setState(() {
        _feedbackScore = score;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar feedback: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _onNavTap(int index) {
    setState(() {
      _currentNavIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/social');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/rachas');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/practicalo');
        break;
      case 4:
        break;
    }
  }

  String _getFeedbackDescription(double score) {
    if (score >= 75) {
      return 'Excelente desempeño 🌟';
    } else if (score >= 50) {
      return 'Buen trabajo 👍';
    } else if (score >= 25) {
      return 'En desarrollo 📈';
    } else if (score > 0) {
      return 'Hay oportunidad de mejora 💪';
    } else {
      return 'Sin calificaciones aún';
    }
  }

  Color _getFeedbackColor(double score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.blue;
    if (score >= 25) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_errorMessage!,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _loadFeedbackScore,
                          child: const Text('Reintentar')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tarjeta de información del usuario
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Colors.blue[50]!, Colors.blue[100]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.blue[200]!, width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                  color: Colors.blue, shape: BoxShape.circle),
                              child: Center(
                                child: Text(
                                  (authProvider.userName ?? 'U')
                                      .characters
                                      .first
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(authProvider.userName ?? 'Usuario',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black)),
                                  const SizedBox(height: 4),
                                  Text(
                                      authProvider.userEmail ??
                                          'email@example.com',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600])),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Sección de Calificación
                      Text('Calificación',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                              letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.grey[200]!, width: 1),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Column(
                          children: [
                            Text('Calificación Feedback',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700])),
                            const SizedBox(height: 20),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                      text: _feedbackScore.toStringAsFixed(0),
                                      style: const TextStyle(
                                          fontSize: 72,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue)),
                                  TextSpan(
                                      text: '%',
                                      style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue[400])),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                  _getFeedbackDescription(_feedbackScore),
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center),
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _feedbackScore / 100,
                                minHeight: 8,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    _getFeedbackColor(_feedbackScore)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Nota informativa
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber[200]!)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.amber[700], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tu puntuación se calcula basada en los votos de tus compañeros en cada reto completado.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber[900],
                                    height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
      bottomNavigationBar: CustomBottomNavigationBar(
          currentIndex: _currentNavIndex, onTap: _onNavTap),
    );
  }
}
