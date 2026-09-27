// rachas_screen.dart - REDISEÑO VISUAL (misma armonía que home_screen.dart)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/racha_provider.dart';
import '../providers/planificacion_provider.dart';
import '../models/planificacion_model.dart';
import '../models/reto_model.dart';
import '../utils/colors.dart';
import '../widgets/custom_bottom_navigation_bar.dart';

class RachasScreen extends StatefulWidget {
  const RachasScreen({Key? key}) : super(key: key);

  @override
  State<RachasScreen> createState() => _RachasScreenState();
}

class _RachasScreenState extends State<RachasScreen> {
  int _currentNavIndex = 2;

  // ===== Colores (mismos que home_screen) =====
  static const Color _fondo = Color(0xFFF6F7FB);
  static const Color _texto = Color(0xFF1F2937);
  static const Color _textoSuave = Color(0xFF6B7280);

  static const List<Color> _gradientePrincipal = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
  ];

  static const List<List<Color>> _paleta = [
    [Color(0xFF6366F1), Color(0xFF4F46E5)], // Índigo
    [Color(0xFF8B5CF6), Color(0xFF7C3AED)], // Violeta
    [Color(0xFF14B8A6), Color(0xFF0D9488)], // Turquesa
    [Color(0xFFF59E0B), Color(0xFFD97706)], // Ámbar
    [Color(0xFFEC4899), Color(0xFFDB2777)], // Rosa
    [Color(0xFF3B82F6), Color(0xFF2563EB)], // Azul
  ];
  static const List<Color> _verdeCompletado = [
    Color(0xFF10B981),
    Color(0xFF059669),
  ];

  // Colores de estado
  static const Color _azul = Color(0xFF3B82F6);
  static const Color _naranja = Color(0xFFF59E0B);
  static const Color _verde = Color(0xFF10B981);
  static const Color _rojo = Color(0xFFEF4444);
  static const Color _morado = Color(0xFF8B5CF6);
  static const Color _grisBolita = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final authProvider = context.read<AuthProvider>();
    final rachaProvider = context.read<RachaProvider>();
    final planProvider = context.read<PlanificacionProvider>();

    if (authProvider.userId == null || authProvider.token == null) return;

    if (planProvider.data == null) {
      await planProvider.cargar();
    }

    final retosInscritos = planProvider.data?.retosDelMes ?? [];
    if (retosInscritos.isEmpty) return;

    final retoIds = retosInscritos.map((r) => r.id).toList();

    await rachaProvider.cargarEstadisticasMultipleRetos(
      authProvider.userId!,
      retoIds,
      authProvider.token!,
    );

    await rachaProvider.cargarLeaderboard(authProvider.token!);

    for (var reto in retosInscritos) {
      await rachaProvider.cargarProgresoDiario(
        authProvider.userId!,
        reto.id,
        authProvider.token!,
      );
    }

    await rachaProvider.cargarPreferenciaRegaloGlobal(
      authProvider.userId!,
      authProvider.token!,
    );
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
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        title: const Text('Rachas'),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryColor.withOpacity(0.85),
                AppColors.primaryColor.withOpacity(0.75),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Consumer3<RachaProvider, PlanificacionProvider, AuthProvider>(
          builder: (context, rachaProvider, planProvider, authProvider, _) {
            if (rachaProvider.isLoading || planProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (rachaProvider.errorMessage != null) {
              return _buildError(rachaProvider.errorMessage!);
            }

            final data = planProvider.data;
            final List<Reto> retosInscritos = data?.retosDelMes ?? [];

            if (retosInscritos.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 40),
                  _buildEstadoVacio(
                    '🌱',
                    'No tienes retos inscritos este mes',
                    'Inscríbete en un reto desde la pantalla de Retos para empezar a sumar rachas.',
                  ),
                ],
              );
            }

            return RefreshIndicator(
              onRefresh: _cargarDatos,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  // ===== CABECERA =====
                  _buildHeader(data),
                  const SizedBox(height: 24),

                  // ===== 1) REGALO GLOBAL =====
                  _buildSeccionRegaloGlobal(rachaProvider, authProvider),

                  // ── Separador 1 ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 24),
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            const Color(0xFF6366F1).withOpacity(0.2),
                            const Color(0xFF8B5CF6).withOpacity(0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ===== 2) PROGRESO POR RETO =====
                  _buildSectionHeader(
                    '📈',
                    'Tu progreso por reto',
                    'Completa tu píldora diaria de lunes a viernes',
                  ),
                  const SizedBox(height: 14),
                  ...retosInscritos.map((reto) {
                    final stats = rachaProvider.obtenerStatsReto(reto.id);
                    return _buildRetoSection(
                      data: data,
                      reto: reto,
                      stats: stats,
                      rachaProvider: rachaProvider,
                    );
                  }).toList(),

                  // ── Separador 2 ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 24),
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            const Color(0xFF6366F1).withOpacity(0.2),
                            const Color(0xFF8B5CF6).withOpacity(0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ===== 3) RANKING =====
                  _buildSectionHeader(
                    '🏆',
                    'Ranking',
                    'Ordenado por racha · desempate por píldoras',
                  ),
                  const SizedBox(height: 14),
                  _buildLeaderboardUnificado(rachaProvider),
                  const SizedBox(height: 24),
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

  List<Color> _gradienteReto(PlanificacionData? data, String retoId) {
    if (data == null) return _paleta[0];
    if (data.retosCompletados.contains(retoId)) return _verdeCompletado;
    final i = data.retos.indexWhere((r) => r.id == retoId);
    return _paleta[(i < 0 ? 0 : i) % _paleta.length];
  }

  String _emojiReto(String titulo) {
    final t = titulo.toLowerCase();
    if (t.contains('conecta')) return '💞';
    if (t.contains('reloj') || t.contains('tiempo')) return '⏱️';
    if (t.contains('habla') || t.contains('escuch')) return '🗣️';
    if (t.contains('lider') || t.contains('líder')) return '👑';
    if (t.contains('detective')) return '🔍';
    if (t.contains('rompecabezas')) return '🧩';
    return '🎯';
  }

  Map<String, String> _infoRegalo(String tipo) {
    switch (tipo) {
      case 'social':
        return {'emoji': '🍹', 'label': 'Social'};
      case 'restaurante':
        return {'emoji': '🍽️', 'label': 'Restaurante'};
      case 'tarjeta':
        return {'emoji': '🎁', 'label': 'Tarjeta regalo'};
      default:
        return {'emoji': '🎁', 'label': tipo};
    }
  }

  Widget _buildHeader(PlanificacionData? data) {
    final mes = data?.mesVigenteNombre ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: _gradientePrincipal),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '🔥 TU CONSTANCIA CUENTA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mis Rachas',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _texto,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            mes.isNotEmpty
                ? '$mes · Suma días seguidos y escala en el ranking'
                : 'Suma días seguidos y escala en el ranking',
            style: const TextStyle(fontSize: 13, color: _textoSuave),
          ),
        ],
      ),
    );
  }

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
              color: AppColors.primaryColor.withOpacity(0.1),
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
                    color: _texto,
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
        color: fondo ?? AppColors.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: colorTexto ?? AppColors.primaryColor,
        ),
      ),
    );
  }

  Widget _buildEstadoVacio(String emoji, String titulo, String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.12)),
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
                    color: _texto,
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
              onPressed: _cargarDatos,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // 1) REGALO GLOBAL
  // ===================================================================

  Widget _buildSeccionRegaloGlobal(
    RachaProvider rachaProvider,
    AuthProvider authProvider,
  ) {
    final regaloSeleccionado = rachaProvider.preferenciaRegaloGlobal;
    final yaEligio =
        regaloSeleccionado != null && regaloSeleccionado.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          '🎁',
          yaEligio ? 'Ya elegiste tu regalo' : 'Elige tu premio',
          yaEligio
              ? 'Es el que reclamarás si ganas el ranking'
              : 'Lo reclamarás si vences a todos en rachas',
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildBotonRegalo(
                  emoji: '🍹',
                  label: 'Social',
                  tipoRegalo: 'social',
                  estaSeleccionado: regaloSeleccionado == 'social',
                  bloqueado: yaEligio,
                  onTap: yaEligio
                      ? null
                      : () => _seleccionarRegaloGlobal(
                          'social', rachaProvider, authProvider),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBotonRegalo(
                  emoji: '🍽️',
                  label: 'Restaurante',
                  tipoRegalo: 'restaurante',
                  estaSeleccionado: regaloSeleccionado == 'restaurante',
                  bloqueado: yaEligio,
                  onTap: yaEligio
                      ? null
                      : () => _seleccionarRegaloGlobal(
                          'restaurante', rachaProvider, authProvider),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBotonRegalo(
                  emoji: '🎁',
                  label: 'Tarjeta\nregalo',
                  tipoRegalo: 'tarjeta',
                  estaSeleccionado: regaloSeleccionado == 'tarjeta',
                  bloqueado: yaEligio,
                  onTap: yaEligio
                      ? null
                      : () => _seleccionarRegaloGlobal(
                          'tarjeta', rachaProvider, authProvider),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Icon(
                yaEligio ? Icons.lock_outline : Icons.info_outline,
                size: 14,
                color: _textoSuave,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  yaEligio
                      ? 'Tu elección está guardada y no se puede cambiar'
                      : 'Solo puedes elegir una vez',
                  style: const TextStyle(fontSize: 11.5, color: _textoSuave),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBotonRegalo({
    required String emoji,
    required String label,
    required String tipoRegalo,
    required bool estaSeleccionado,
    required bool bloqueado,
    required VoidCallback? onTap,
  }) {
    final bool enGris = bloqueado && !estaSeleccionado;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 120,
        decoration: BoxDecoration(
          gradient: estaSeleccionado
              ? const LinearGradient(
                  colors: _gradientePrincipal,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: estaSeleccionado
              ? null
              : (enGris ? const Color(0xFFF1F2F6) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: estaSeleccionado
                ? Colors.transparent
                : enGris
                    ? const Color(0xFFE5E7EB)
                    : AppColors.primaryColor.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: estaSeleccionado
                  ? const Color(0xFF6366F1).withOpacity(0.4)
                  : Colors.black.withOpacity(enGris ? 0.0 : 0.05),
              blurRadius: estaSeleccionado ? 16 : 10,
              offset: Offset(0, estaSeleccionado ? 6 : 4),
            ),
          ],
        ),
        child: Opacity(
          opacity: enGris ? 0.45 : 1.0,
          child: Stack(
            children: [
              if (estaSeleccionado)
                const Positioned(
                  top: 8,
                  right: 8,
                  child:
                      Icon(Icons.check_circle, color: Colors.white, size: 18),
                ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: estaSeleccionado
                            ? Colors.white.withOpacity(0.2)
                            : AppColors.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: estaSeleccionado ? Colors.white : _texto,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _seleccionarRegaloGlobal(
    String tipoRegalo,
    RachaProvider rachaProvider,
    AuthProvider authProvider,
  ) {
    final info = _infoRegalo(tipoRegalo);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: _gradientePrincipal,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(info['emoji']!,
                      style: const TextStyle(fontSize: 34)),
                ),
                const SizedBox(height: 16),
                const Text(
                  '¿Seguro quieres este regalo si ganas?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _texto,
                  ),
                ),
                const SizedBox(height: 10),
                _chip(info['label']!),
                const SizedBox(height: 12),
                const Text(
                  'Una vez confirmado, ya no lo podrás cambiar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: _textoSuave),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              color: _textoSuave,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: Ink(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: _gradientePrincipal),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              Navigator.of(dialogContext).pop();
                              try {
                                if (authProvider.userId != null &&
                                    authProvider.token != null) {
                                  await rachaProvider
                                      .guardarPreferenciaRegaloGlobal(
                                    authProvider.userId!,
                                    tipoRegalo,
                                    authProvider.token!,
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Error al guardar preferencia: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Center(
                              child: Text(
                                'Confirmar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===================================================================
  // 2) SECCIÓN POR RETO
  // ===================================================================

  Widget _buildRetoSection({
    required PlanificacionData? data,
    required Reto reto,
    required Map<String, dynamic>? stats,
    required RachaProvider rachaProvider,
  }) {
    final diaPildora = stats?['dia_pildora'] ?? 0;
    final racha = stats?['racha_maxima'] ?? 0;
    final cumplidos = stats?['dias_cumplidos'] ?? 0;
    final colores = _gradienteReto(data, reto.id);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera con degradado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colores,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -30,
                  top: -40,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(_emojiReto(reto.title),
                          style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reto.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _chip(
                            'Píldora $diaPildora de 20',
                            fondo: Colors.white.withOpacity(0.22),
                            colorTexto: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3 tarjetas
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Día Píldora\nL-V',
                    value: '$diaPildora/20',
                    icon: Icons.calendar_today_rounded,
                    color: _azul,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    title: 'Racha\nL-V',
                    value: racha.toString(),
                    icon: Icons.local_fire_department_rounded,
                    color: _naranja,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    title: 'Píldoras\ncumplidas',
                    value: cumplidos.toString(),
                    icon: Icons.check_circle_rounded,
                    color: _verde,
                  ),
                ),
              ],
            ),
          ),

          // Bolitas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: _buildBolitasProgreso(
              retoId: reto.id,
              rachaProvider: rachaProvider,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.25,
              color: _textoSuave,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leyenda(Color color, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 10.5, color: _textoSuave)),
      ],
    );
  }

  Widget _buildBolitasProgreso({
    required String retoId,
    required RachaProvider rachaProvider,
  }) {
    final progresoDiario = rachaProvider.obtenerProgresoDiario(retoId);

    if (progresoDiario == null || progresoDiario.isEmpty) {
      return const SizedBox.shrink();
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

    final totalDiasLaborables = diasLaborablesTeoricos.length;
    if (totalDiasLaborables == 0) return const SizedBox.shrink();

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

    final bolitas = <Color>[];
    for (int i = 0; i < totalDiasLaborables; i++) {
      final numeroDelDia = i + 1;
      final esDiaGracia = numeroDelDia > 20;
      final fechaStr =
          diasLaborablesTeoricos[i].toIso8601String().split('T')[0];
      final diaData = datosMap[fechaStr];

      Color color;
      if (esDiaGracia) {
        color = _morado;
      } else if (numeroDelDia <= diaLaboralActual) {
        if (diaData != null) {
          final cumple = diaData['login_hecho'] == true &&
              diaData['pildora_completada'] == true;
          color = cumple ? _verde : _rojo;
        } else {
          color = _rojo;
        }
      } else {
        color = _grisBolita;
      }
      bolitas.add(color);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Progreso diario',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _texto,
              ),
            ),
            const Spacer(),
            _chip('Día $diaLaboralActual de $totalDiasLaborables'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: bolitas.map((color) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _leyenda(_verde, 'Cumplido'),
            _leyenda(_rojo, 'No cumplido'),
            _leyenda(_grisBolita, 'Pendiente'),
            _leyenda(_morado, 'Días de gracia'),
          ],
        ),
      ],
    );
  }

  // ===================================================================
  // 3) RANKING
  // ===================================================================

  Widget _buildLeaderboardUnificado(RachaProvider rachaProvider) {
    final leaderboard = rachaProvider.obtenerLeaderboardUnificado();

    if (leaderboard.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildEstadoVacio(
          '🏁',
          'Aún no hay ranking',
          'Completa tus píldoras para aparecer aquí.',
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Encabezado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: AppColors.primaryColor.withOpacity(0.06),
            child: Row(
              children: const [
                SizedBox(width: 46),
                Expanded(
                  child: Text(
                    'Usuario',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _textoSuave,
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '🔥 Racha',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _textoSuave,
                    ),
                  ),
                ),
                SizedBox(
                  width: 76,
                  child: Text(
                    '✅ Píldoras',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _textoSuave,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filas
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leaderboard.length,
            separatorBuilder: (context, index) => const Divider(
              color: Color(0xFFF1F2F6),
              height: 1,
            ),
            itemBuilder: (context, index) {
              final item = leaderboard[index];
              final position = item['position'] ?? (index + 1);
              final name = item['full_name'] ?? 'Usuario';
              final racha = item['mejor_racha'] ?? 0;
              final pildoras = item['pildoras_cumplidas'] ?? 0;
              final esPodio = position is int && position <= 3;

              return Container(
                color: esPodio
                    ? _coloresMedalla(position)[0].withOpacity(0.06)
                    : Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    _buildMedalla(position),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              esPodio ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 14,
                          color: _texto,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Center(
                        child: _valorPill(racha.toString(), _naranja),
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      child: Center(
                        child: _valorPill(pildoras.toString(), _verde),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _valorPill(String valor, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 36),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        valor,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  List<Color> _coloresMedalla(int position) {
    switch (position) {
      case 1:
        return const [Color(0xFFFBBF24), Color(0xFFF59E0B)]; // Oro
      case 2:
        return const [Color(0xFFCBD5E1), Color(0xFF94A3B8)]; // Plata
      case 3:
        return const [Color(0xFFFB923C), Color(0xFFEA580C)]; // Bronce
      default:
        return _gradientePrincipal;
    }
  }

  Widget _buildMedalla(dynamic position) {
    final int pos = position is int ? position : 0;

    // 🏆 1er lugar: trofeo dorado con el número 1
    if (pos == 1) {
      return SizedBox(
        width: 34,
        height: 34,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: _coloresMedalla(1),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: 34,
                color: Colors.white,
              ),
            ),
            const Align(
              alignment: Alignment(0, -0.35),
              child: Text(
                '1',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  shadows: [
                    Shadow(color: Color(0xFFB45309), blurRadius: 2),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 🎗️ 2º plata, 3º bronce, resto lila claro: listón con el número
    final bool esPodio = pos == 2 || pos == 3;

    Widget liston = Icon(
      Icons.bookmark_rounded,
      size: 34,
      color: esPodio ? Colors.white : AppColors.primaryColor.withOpacity(0.18),
    );

    if (esPodio) {
      liston = ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: _coloresMedalla(pos),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: liston,
      );
    }

    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          liston,
          Align(
            alignment: const Alignment(0, -0.3),
            child: Text(
              position.toString(),
              style: TextStyle(
                color: esPodio ? Colors.white : AppColors.primaryColor,
                fontWeight: FontWeight.w900,
                fontSize: pos >= 10 ? 10.5 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
