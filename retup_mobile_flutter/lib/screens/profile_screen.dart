import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/feedback_service.dart';
import '../providers/reto_provider.dart';
import '../providers/racha_provider.dart';
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
  Map<String, double> _asistenciaScores = {}; // Nueva variable
  Map<String, double> _feedbackScoresPerReto =
      {}; // Nueva variable para feedback por reto

  @override
  void initState() {
    super.initState();
    _feedbackService = FeedbackService();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authProvider = context.read<AuthProvider>();
      final retoProvider = context.read<RetoProvider>();
      final rachaProvider = context.read<RachaProvider>();

      final userId = authProvider.userId;
      final token = authProvider.token ?? '';

      if (userId == null) {
        setState(() {
          _errorMessage = 'No hay usuario autenticado';
          _isLoading = false;
        });
        return;
      }

      // Cargar feedback general
      final score =
          await _feedbackService.calculateUserFeedbackScore(userId, token);

      // Cargar retos del usuario
      await retoProvider.cargarRetosDelUsuario(userId);

      // Cargar feedback score POR RETO (NUEVO)
      _feedbackScoresPerReto.clear();
      for (var retoLocal in retoProvider.retos) {
        try {
          final feedbackScore =
              await _feedbackService.calculateUserFeedbackScore(
            userId,
            token,
            retoId: retoLocal.reto.id, // NUEVO: pasar retoId
          );
          _feedbackScoresPerReto[retoLocal.reto.id] = feedbackScore;
        } catch (e) {
          print('Error loading feedback for reto ${retoLocal.reto.id}: $e');
          _feedbackScoresPerReto[retoLocal.reto.id] = 0.0;
        }
      }

      // Cargar progreso diario para cada reto
      for (var retoLocal in retoProvider.retos) {
        await rachaProvider.cargarProgresoDiario(
          userId,
          retoLocal.reto.id,
          token,
        );
      }

      setState(() {
        _feedbackScore = score;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar datos: ${e.toString()}';
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

  double _calcularCalificacionAsistencia({
    required String retoId,
    required RachaProvider rachaProvider,
  }) {
    final progresoDiario = rachaProvider.obtenerProgresoDiario(retoId);

    if (progresoDiario == null || progresoDiario.isEmpty) {
      return 0.0;
    }

    // Calcular dias laborables teoricos del mes (L-V)
    final hoy = DateTime.now();
    final mes = hoy.month;
    final ano = hoy.year;
    final ultimoDiaDelMes = DateTime(ano, mes + 1, 0).day;

    final diasLaborablesTeoricos = <DateTime>[];
    for (int day = 1; day <= ultimoDiaDelMes; day++) {
      final fecha = DateTime(ano, mes, day);
      if (fecha.weekday >= 1 && fecha.weekday <= 5) {
        diasLaborablesTeoricos.add(fecha);
      }
    }

    final datosMap = <String, Map<String, dynamic>>{};
    for (var registro in progresoDiario) {
      datosMap[registro['fecha']] = registro;
    }

    final hoyString = hoy.toIso8601String().split('T')[0];

    int diaLaboralActual = 0;
    for (int i = 0; i < diasLaborablesTeoricos.length; i++) {
      final fechaStr =
          diasLaborablesTeoricos[i].toIso8601String().split('T')[0];
      if (fechaStr.compareTo(hoyString) <= 0) {
        diaLaboralActual = i + 1;
      } else {
        break;
      }
    }

    int bolitasVerdes = 0;
    for (int i = 0; i < diaLaboralActual; i++) {
      final fechaStr =
          diasLaborablesTeoricos[i].toIso8601String().split('T')[0];
      final diaData = datosMap[fechaStr];

      if (diaData != null) {
        final cumple = diaData['login_hecho'] == true &&
            diaData['pildora_completada'] == true;
        if (cumple) {
          bolitasVerdes++;
        }
      }
    }

    final divisor = diaLaboralActual > 20 ? 20 : diaLaboralActual;
    if (divisor == 0) {
      return 0.0;
    }

    return (bolitasVerdes / divisor) * 100;
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
                          onPressed: _loadData,
                          child: const Text('Reintentar')),
                    ],
                  ),
                )
              : Consumer2<RetoProvider, RachaProvider>(
                  builder: (context, retoProvider, rachaProvider, _) {
                    final retos = retoProvider.retos;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tarjeta de usuario (MANTENER IGUAL)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [Colors.blue[50]!, Colors.blue[100]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.blue[200]!, width: 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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

                          // Calificaciones por Reto - NUEVO
                          if (retos.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Calificaciones por Reto',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                        letterSpacing: 1.2)),
                                const SizedBox(height: 16),
                                ...retos.map((retoLocal) {
                                  final asistencia =
                                      _calcularCalificacionAsistencia(
                                    retoId: retoLocal.reto.id,
                                    rachaProvider: rachaProvider,
                                  );

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Nombre del reto
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12.0),
                                        child: Row(
                                          children: [
                                            Text(retoLocal.emoji,
                                                style: const TextStyle(
                                                    fontSize: 20)),
                                            const SizedBox(width: 8),
                                            Text(
                                              retoLocal.reto.title ??
                                                  'Reto sin nombre',
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Container con dos tarjetas lado a lado
                                      Container(
                                        child: Row(
                                          children: [
                                            // Tarjeta Feedback
                                            Expanded(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(24),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: Colors.blue
                                                          .withOpacity(0.3),
                                                      width: 1),
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.grey
                                                            .withOpacity(0.1),
                                                        spreadRadius: 1,
                                                        blurRadius: 3)
                                                  ],
                                                ),
                                                child: Column(
                                                  children: [
                                                    Text(
                                                        'Calificación Feedback',
                                                        style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .grey[700])),
                                                    const SizedBox(height: 20),
                                                    RichText(
                                                      text: TextSpan(
                                                        children: [
                                                          TextSpan(
                                                              text: (_feedbackScoresPerReto[retoLocal
                                                                          .reto
                                                                          .id] ??
                                                                      0.0)
                                                                  .toStringAsFixed(
                                                                      0),
                                                              style: const TextStyle(
                                                                  fontSize: 72,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .blue)),
                                                          TextSpan(
                                                              text: '%',
                                                              style: TextStyle(
                                                                  fontSize: 32,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Colors
                                                                          .blue[
                                                                      400])),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      child:
                                                          LinearProgressIndicator(
                                                        value: (_feedbackScoresPerReto[
                                                                    retoLocal
                                                                        .reto
                                                                        .id] ??
                                                                0.0) /
                                                            100,
                                                        minHeight: 8,
                                                        backgroundColor:
                                                            Colors.grey[200],
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                Color>(
                                                          _getFeedbackColor(
                                                              _feedbackScoresPerReto[
                                                                      retoLocal
                                                                          .reto
                                                                          .id] ??
                                                                  0.0),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            // Tarjeta Asistencia
                                            Expanded(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(24),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: Colors.green
                                                          .withOpacity(0.3),
                                                      width: 1),
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.grey
                                                            .withOpacity(0.1),
                                                        spreadRadius: 1,
                                                        blurRadius: 3)
                                                  ],
                                                ),
                                                child: Column(
                                                  children: [
                                                    Text(
                                                        'Calificación Asistencia',
                                                        style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors
                                                                .grey[700])),
                                                    const SizedBox(height: 20),
                                                    RichText(
                                                      text: TextSpan(
                                                        children: [
                                                          TextSpan(
                                                              text: asistencia >
                                                                      0
                                                                  ? asistencia
                                                                      .toStringAsFixed(
                                                                          0)
                                                                  : '--',
                                                              style: const TextStyle(
                                                                  fontSize: 72,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .green)),
                                                          if (asistencia > 0)
                                                            TextSpan(
                                                                text: '%',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        32,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color: Colors
                                                                            .green[
                                                                        400])),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 20),
                                                    if (asistencia > 0)
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        child:
                                                            LinearProgressIndicator(
                                                          value:
                                                              asistencia / 100,
                                                          minHeight: 8,
                                                          backgroundColor:
                                                              Colors.grey[200],
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                      Color>(
                                                                  Colors.green),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
      bottomNavigationBar: CustomBottomNavigationBar(
          currentIndex: _currentNavIndex, onTap: _onNavTap),
    );
  }
}
