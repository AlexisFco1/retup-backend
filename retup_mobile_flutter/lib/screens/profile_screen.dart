// profile_screen.dart - IDENTIDAD DE MARCA RETUP (armonía página web)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/feedback_service.dart';
import '../providers/reto_provider.dart';
import '../providers/racha_provider.dart';
import '../providers/practicalo_provider.dart';
import '../utils/colors.dart';
import '../widgets/custom_bottom_navigation_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late FeedbackService _feedbackService;
  int _currentNavIndex = 4;
  double? _feedbackScore;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, double> _asistenciaScores = {};
  Map<String, double?> _feedbackScoresPerReto = {};
  Set<String> _retosExpandidos = {};

  // ===== Colores de marca RetUp (Paleta "Vínculo") =====
  static const Color _indigo = Color(0xFF2E2A72); // Predomina
  static const Color _turquesa = Color(0xFF12B5A6); // Botones y acentos
  static const Color _turquesaOscuro = Color(0xFF0B8A7E);
  static const Color _morado = Color(0xFF7209B7); // Compromiso
  static const Color _tinta = Color(0xFF0E0F17); // Texto

  static const Color _fondo = Color(0xFFF5F5F2); // Blanco roto como la web
  static const Color _texto = _tinta;
  static const Color _textoSuave = Color(0xFF6B7280);

  // Degradado suave protagonista (mismo que Retos y Practícalo)
  static const List<Color> _degradadoSuave = [
    Color(0xFF4B4699),
    Color(0xFF3A7FA0),
  ];

  // Paleta de acentos por reto (se usa en tonos pastel)
  static const List<List<Color>> _paleta = [
    [Color(0xFF2E2A72), Color(0xFF443E9E)], // Índigo
    [Color(0xFF12B5A6), Color(0xFF0B8A7E)], // Turquesa
    [Color(0xFF7209B7), Color(0xFF5B0893)], // Morado
    [Color(0xFF2E2A72), Color(0xFF7209B7)], // Índigo → Morado
    [Color(0xFF12B5A6), Color(0xFF2E2A72)], // Turquesa → Índigo
    [Color(0xFF7209B7), Color(0xFF2E2A72)], // Morado → Índigo
  ];

  // Colores de la escala de desempeño (se mantienen por ser universales)
  static const Color _verde = Color(0xFF10B981);
  static const Color _ambar = Color(0xFFF59E0B);
  static const Color _rojo = Color(0xFFEF4444);

  // Degradado pastel de marca (turquesa → índigo) para cajitas e iconos
  static final LinearGradient _degradadoPastel = LinearGradient(
    colors: [
      _turquesa.withOpacity(0.18),
      _indigo.withOpacity(0.10),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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

      final score =
          await _feedbackService.calculateUserFeedbackScore(userId, token);

      await retoProvider.cargarRetosDelUsuario(userId);
      final practicaloProvider = context.read<PracticaloProvider>();
      await practicaloProvider.cargarEnviadas(token: token, userId: userId);

      _feedbackScoresPerReto.clear();
      for (var retoLocal in retoProvider.retos) {
        try {
          final feedbackScore =
              await _feedbackService.calculateUserFeedbackScore(
            userId,
            token,
            retoId: retoLocal.reto.id,
          );
          _feedbackScoresPerReto[retoLocal.reto.id] = feedbackScore;
        } catch (e) {
          print('Error loading feedback for reto ${retoLocal.reto.id}: $e');
          _feedbackScoresPerReto[retoLocal.reto.id] = null;
        }
      }

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
    if (score >= 75) return _verde;
    if (score >= 50) return _turquesa;
    if (score >= 25) return _ambar;
    return _rojo;
  }

  double _calcularCalificacionAsistencia({
    required String retoId,
    required RachaProvider rachaProvider,
  }) {
    final progresoDiario = rachaProvider.obtenerProgresoDiario(retoId);

    if (progresoDiario == null || progresoDiario.isEmpty) {
      return 0.0;
    }

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

  double? _calcularNotaPromedio({
    required String retoId,
    required PracticaloProvider practicaloProvider,
  }) {
    final practicasEnviadas = practicaloProvider.practicaloEnviadas;

    final practicasValidas = practicasEnviadas.where((practica) {
      final esDelReto = practica['reto_id'] == retoId;
      final estaCompletada = practica['status'] == 'completed';
      final tieneCalificacion = practica['star_rating'] != null;
      final noFueRechazada = practica['response'] != 'no_thanks';

      return esDelReto && estaCompletada && tieneCalificacion && noFueRechazada;
    }).toList();

    if (practicasValidas.isEmpty) {
      return null; // Sin datos para calcular
    }

    final totalEstrellas = practicasValidas.fold<int>(
      0,
      (suma, practica) => suma + (practica['star_rating'] as int),
    );

    return totalEstrellas / practicasValidas.length;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 64,
        centerTitle: false,
        titleSpacing: 12,
        automaticallyImplyLeading: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Solo la R del logo, fundida con el índigo (igual que en Inicio)
            SizedBox(
              width: 42,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 0.66,
                  child: Image.asset(
                    'assets/images/logo_retup_oscuro.jpg',
                    width: 42,
                    fit: BoxFit.fitWidth,
                    color: _indigo,
                    colorBlendMode: BlendMode.screen,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text(
                        'R',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: _turquesa,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Perfil',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _turquesa))
            : _errorMessage != null
                ? _buildError(_errorMessage!)
                : Consumer3<RetoProvider, RachaProvider, PracticaloProvider>(
                    builder: (context, retoProvider, rachaProvider,
                        practicaloProvider, _) {
                      final retos = retoProvider.retos;

                      // Calcular las 3 calificaciones y quedarnos solo
                      // con los retos que tengan algún dato
                      final retosConDatos = <Map<String, dynamic>>[];
                      for (int i = 0; i < retos.length; i++) {
                        final retoLocal = retos[i];
                        final double? feedbackRaw =
                            _feedbackScoresPerReto[retoLocal.reto.id];
                        final double asistencia =
                            _calcularCalificacionAsistencia(
                          retoId: retoLocal.reto.id,
                          rachaProvider: rachaProvider,
                        );
                        final double? practicaRaw = _calcularNotaPromedio(
                          retoId: retoLocal.reto.id,
                          practicaloProvider: practicaloProvider,
                        );
                        // Convertir práctica a escala 0-100 solo si hay datos
                        final double? practica =
                            practicaRaw != null ? practicaRaw * 20 : null;

                        // Mostrar el reto si tiene al menos un dato en cualquier categoría
                        final bool tieneAlgunDato = feedbackRaw != null ||
                            asistencia > 0 ||
                            practica != null;

                        if (tieneAlgunDato) {
                          // Para el promedio general, solo promediar las categorías que tienen datos
                          double sumaGenerales = 0;
                          int cantidadConDatos = 0;
                          if (feedbackRaw != null) {
                            sumaGenerales += feedbackRaw;
                            cantidadConDatos++;
                          }
                          if (asistencia > 0) {
                            sumaGenerales += asistencia;
                            cantidadConDatos++;
                          }
                          if (practica != null) {
                            sumaGenerales += practica;
                            cantidadConDatos++;
                          }
                          final double general = cantidadConDatos > 0
                              ? sumaGenerales / cantidadConDatos
                              : 0;

                          retosConDatos.add({
                            'index': i,
                            'retoLocal': retoLocal,
                            'feedback':
                                feedbackRaw, // double? — null = sin datos
                            'asistencia':
                                asistencia, // double — 0.0 = sin datos (ya existente)
                            'practica': practica, // double? — null = sin datos
                            'general': general,
                          });
                        }
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ===== TARJETA DE USUARIO =====
                            _buildTarjetaUsuario(
                                authProvider, retosConDatos.length),
                            const SizedBox(height: 28),

                            // ===== CALIFICACIONES POR RETO =====
                            _buildSectionHeader(
                              '📊',
                              'Calificaciones por reto',
                              'Feedback, asistencia y práctica de cada reto',
                            ),
                            const SizedBox(height: 14),

                            if (retosConDatos.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: _buildEstadoVacio(
                                  '🌱',
                                  'Aún no tienes calificaciones',
                                  'Cuando completes píldoras, recibas feedback o practiques con un compañero, verás aquí tu desempeño.',
                                ),
                              )
                            else
                              ...retosConDatos.map((item) {
                                final retoLocal = item['retoLocal'];
                                final int index = item['index'] as int;

                                return _buildRetoCard(
                                  retoId: retoLocal.reto.id,
                                  colores: _paleta[index % _paleta.length],
                                  emoji: retoLocal.emoji,
                                  titulo:
                                      retoLocal.reto.title ?? 'Reto sin nombre',
                                  categoria: retoLocal.reto.category,
                                  general: item['general'] as double,
                                  feedback: item['feedback'] as double?,
                                  asistencia: item['asistencia'] as double,
                                  practica: item['practica'] as double?,
                                );
                              }).toList(),
                            const SizedBox(height: 8),
                          ],
                        ),
                      );
                    },
                  ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
      ),
    );
  }

  // ===================================================================
  // HELPERS GENERALES
  // ===================================================================

  Widget _buildSectionHeader(String emoji, String titulo, String subtitulo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: _degradadoPastel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _indigo,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: const TextStyle(fontSize: 12.5, color: _textoSuave),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String texto, {Color? fondo, Color? colorTexto}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fondo ?? _indigo.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: colorTexto ?? _indigo,
        ),
      ),
    );
  }

  Widget _buildEstadoVacio(String emoji, String titulo, String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_indigo.withOpacity(0.06), _turquesa.withOpacity(0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _indigo.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _indigo,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  texto,
                  style: const TextStyle(
                      fontSize: 13, color: _textoSuave, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _turquesa,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _loadData,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // TARJETA DE USUARIO (bloque protagonista con degradado suave)
  // ===================================================================

  Widget _buildTarjetaUsuario(AuthProvider authProvider, int totalRetos) {
    final nombre = authProvider.userName ?? 'Usuario';
    final inicial =
        nombre.trim().isNotEmpty ? nombre.trim()[0].toUpperCase() : 'U';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: _degradadoSuave,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _indigo.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Arcos decorativos (como el login y la web)
          Positioned(
            right: -60,
            top: -60,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.07),
                  width: 28,
                ),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -60,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _turquesa.withOpacity(0.12),
                  width: 20,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _turquesa.withOpacity(0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      inicial,
                      style: const TextStyle(
                        color: _indigo,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        authProvider.userEmail ?? 'email@example.com',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _chip(
                        '🎯 $totalRetos ${totalRetos == 1 ? 'reto' : 'retos'}',
                        fondo: Colors.white.withOpacity(0.18),
                        colorTexto: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // TARJETA POR RETO (cabecera en tono pastel)
  // ===================================================================
  Widget _buildRetoCard({
    required String retoId,
    required List<Color> colores,
    required String emoji,
    required String titulo,
    String? categoria,
    required double general,
    required double? feedback,
    required double asistencia,
    required double? practica,
  }) {
    final colorGeneral = _getFeedbackColor(general);
    final bool expandido = _retosExpandidos.contains(retoId);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _indigo.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: _indigo.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== CABECERA (siempre visible) =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colores[0].withOpacity(0.14),
                  colores[1].withOpacity(0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _indigo,
                        ),
                      ),
                      if (categoria != null && categoria.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          categoria,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _textoSuave,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Porcentaje general (solo cuando está colapsado)
                if (!expandido) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorGeneral.withOpacity(0.4)),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: general.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: _indigo,
                            ),
                          ),
                          const TextSpan(
                            text: '%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _textoSuave,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ===== BOTÓN VER DETALLES / OCULTAR =====
          InkWell(
            onTap: () {
              setState(() {
                if (expandido) {
                  _retosExpandidos.remove(retoId);
                } else {
                  _retosExpandidos.add(retoId);
                }
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    expandido ? 'Ocultar detalles' : 'Ver detalles',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _turquesaOscuro,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expandido
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: _turquesaOscuro,
                  ),
                ],
              ),
            ),
          ),

          // ===== DASHBOARD DESPLEGABLE =====
          if (expandido) ...[
            // Calificación general con anillo
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: (general / 100).clamp(0.0, 1.0),
                          strokeWidth: 9,
                          backgroundColor: _indigo.withOpacity(0.08),
                          valueColor: AlwaysStoppedAnimation(colorGeneral),
                        ),
                        Center(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: general.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: _indigo,
                                  ),
                                ),
                                const TextSpan(
                                  text: '%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _textoSuave,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Calificación general',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _indigo,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Promedio de feedback, asistencia y práctica',
                          style: TextStyle(
                            fontSize: 12,
                            color: _textoSuave,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _chip(
                          _getFeedbackDescription(general),
                          fondo: colorGeneral.withOpacity(0.12),
                          colorTexto: colorGeneral,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3 indicadores (colores de marca en tono pastel)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildScoreTile(
                      titulo: 'Feedback',
                      valor:
                          feedback != null ? feedback.toStringAsFixed(0) : '—',
                      mostrarPorcentaje: feedback != null,
                      progreso: feedback != null ? feedback / 100 : 0,
                      icono: Icons.forum_rounded,
                      color: _indigo,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildScoreTile(
                      titulo: 'Asistencia',
                      valor:
                          asistencia > 0 ? asistencia.toStringAsFixed(0) : '—',
                      mostrarPorcentaje: asistencia > 0,
                      progreso: asistencia / 100,
                      icono: Icons.event_available_rounded,
                      color: _turquesaOscuro,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildScoreTile(
                      titulo: 'Práctica',
                      valor:
                          practica != null ? practica.toStringAsFixed(0) : '—',
                      mostrarPorcentaje: practica != null,
                      progreso: practica != null ? practica / 100 : 0,
                      icono: Icons.star_rounded,
                      color: _morado,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreTile({
    required String titulo,
    required String valor,
    required bool mostrarPorcentaje,
    required double progreso,
    required IconData icono,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.10), color.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: valor,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                if (mostrarPorcentaje)
                  TextSpan(
                    text: '%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _textoSuave,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progreso.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
