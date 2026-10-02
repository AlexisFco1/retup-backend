import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reto_provider.dart';
import '../providers/racha_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/planificacion_provider.dart';
import '../models/reto_model.dart';
import '../services/home_service.dart';
import '../services/pildoras_service.dart';
import '../services/progress_service.dart';
import '../widgets/custom_bottom_navigation_bar.dart';
import 'pildora_detail_screen.dart';
import 'pildoras_list_screen.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({Key? key}) : super(key: key);

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  int _currentNavIndex = 0; // Inicio es el índice 0

  // ===== Colores de marca RetUp (Paleta "Vínculo") =====
  static const Color _indigo = Color(0xFF2E2A72);
  static const Color _turquesa = Color(0xFF12B5A6);
  static const Color _morado = Color(0xFF7209B7);
  static const Color _tinta = Color(0xFF0E0F17);
  static const Color _ambar = Color(0xFFF5B301); // Estrellas
  static const Color _fondo = Color(0xFFF5F5F2);
  static const Color _textoSuave = Color(0xFF6B7280);

  static const List<List<Color>> _paleta = [
    [Color(0xFF2E2A72), Color(0xFF443E9E)], // Índigo
    [Color(0xFF12B5A6), Color(0xFF0B8A7E)], // Turquesa
    [Color(0xFF7209B7), Color(0xFF5B0893)], // Morado
    [Color(0xFF2E2A72), Color(0xFF7209B7)], // Índigo → Morado
    [Color(0xFF12B5A6), Color(0xFF2E2A72)], // Turquesa → Índigo
    [Color(0xFF7209B7), Color(0xFF2E2A72)], // Morado → Índigo
  ];

  static final LinearGradient _degradadoPastel = LinearGradient(
    colors: [_turquesa.withOpacity(0.18), _indigo.withOpacity(0.10)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final HomeService _homeService = HomeService();
  final PillorasService _pildorasService = PillorasService();

  // Secciones 2, 3 y 4
  HomeDestacados? _destacados;
  bool _cargandoDestacados = true;
  String? _errorDestacados;

  // Sección 1: píldoras completadas por reto inscrito (retoId -> cantidad)
  final Map<String, int> _completadasPorReto = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarTodo());
  }

  // ===================================================================
  // CARGA DE DATOS
  // ===================================================================

  Future<void> _cargarTodo() async {
    _registrarLoginEnRachas();
    _cargarNotificaciones();
    await _refrescar();
  }

  Future<void> _refrescar() async {
    await Future.wait([
      _cargarPlanificacionYProgreso(),
      _cargarDestacados(),
    ]);
  }

  /// Igual que en Retos: el login del día cuenta para la racha de cada reto
  Future<void> _registrarLoginEnRachas() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final retoProvider = context.read<RetoProvider>();
      final rachaProvider = context.read<RachaProvider>();

      await retoProvider.cargarRetos();

      final userId = authProvider.userId;
      final token = authProvider.token;
      if (userId == null || token == null) return;

      for (var retoLocal in retoProvider.retos) {
        try {
          await rachaProvider.registrarLogin(userId, retoLocal.reto.id, token);
        } catch (e) {
          print('⚠️ Error registrando login para ${retoLocal.reto.title}: $e');
        }
      }
    } catch (e) {
      print('❌ Error en _registrarLoginEnRachas (Inicio): $e');
    }
  }

  Future<void> _cargarNotificaciones() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final notificationProvider = context.read<NotificationProvider>();
      if (authProvider.userId != null && authProvider.token != null) {
        await notificationProvider.loadUnreadCount(
          userId: authProvider.userId!,
          token: authProvider.token!,
        );
      }
    } catch (e) {
      print('❌ Error cargando contador de notificaciones: $e');
    }
  }

  Future<void> _cargarPlanificacionYProgreso() async {
    final authProvider = context.read<AuthProvider>();
    final planProvider = context.read<PlanificacionProvider>();

    await planProvider.cargar();

    final userId = authProvider.userId;
    final data = planProvider.data;
    if (userId == null || data == null) return;

    try {
      final progresos =
          await ProgressService().getAllPillProgressForUser(userId);
      final completadas = progresos
          .where((p) => p.isCompleted)
          .map((p) => p.pillId.toString())
          .toSet();

      final Map<String, int> porReto = {};
      for (final reto in data.retosDelMes) {
        final pildoras = await _pildorasService.getByRetoId(reto.id);
        porReto[reto.id] =
            pildoras.where((p) => completadas.contains(p.id)).length;
      }

      if (mounted) {
        setState(() {
          _completadasPorReto
            ..clear()
            ..addAll(porReto);
        });
      }
    } catch (e) {
      print('❌ Error cargando progreso (Inicio): $e');
    }
  }

  Future<void> _cargarDestacados() async {
    if (mounted) {
      setState(() {
        _cargandoDestacados = true;
        _errorDestacados = null;
      });
    }
    try {
      final destacados = await _homeService.obtenerDestacados();
      if (mounted) {
        setState(() {
          _destacados = destacados;
          _cargandoDestacados = false;
        });
      }
    } catch (e) {
      print('❌ Error cargando destacados: $e');
      if (mounted) {
        setState(() {
          _errorDestacados = e.toString().replaceFirst('Exception: ', '');
          _cargandoDestacados = false;
        });
      }
    }
  }

  // ===================================================================
  // NAVEGACIÓN
  // ===================================================================

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        break; // Ya estamos en Inicio
      case 1:
        Navigator.pushReplacementNamed(context, '/retos');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/social');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/rachas');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/practicalo');
        break;
      case 5:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  /// Sección 1: abre la lista de píldoras del reto inscrito (flujo normal)
  void _abrirReto(Reto reto) {
    final retoProvider = context.read<RetoProvider>();
    final locales = retoProvider.retos.where((r) => r.reto.id == reto.id);
    if (locales.isNotEmpty) {
      retoProvider.seleccionarReto(locales.first);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PillorasListScreen(reto: reto)),
    ).then((_) => _refrescar());
  }

  /// Sección 2: abre la píldora como SUELTA (no cuenta en Rachas ni rankings)
  void _abrirPildoraSuelta(PildoraDestacada d) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PildoraDetailScreen(
          pildora: d.pildora,
          retoTitle: d.retoTitle,
          retoId: d.pildora.retoId,
          esSuelta: true,
        ),
      ),
    ).then((_) => _refrescar());
  }

  // ===================================================================
  // BUILD
  // ===================================================================

  @override
  Widget build(BuildContext context) {
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
              'Inicio',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: _turquesa,
          onRefresh: _refrescar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [
              // 1) RETO INSCRITO
              _buildSectionHeader(
                  '🎯', 'Reto inscrito', 'Continúa donde lo dejaste'),
              const SizedBox(height: 12),
              _buildRetoInscrito(),

              _separador(),

              // 2) PÍLDORAS MEJOR CALIFICADAS
              _buildSectionHeader(
                '💊',
                'Píldoras mejor calificadas',
                'Top 20 · hazlas cuando quieras',
                deslizable: true,
              ),
              const SizedBox(height: 12),
              _buildTopPildoras(),

              _separador(vertical: 12),

              // 3) TOP 10 RETOS MÁS INSCRITOS
              _buildSectionHeader(
                '🔥',
                'Top 10 retos más inscritos',
                'Los retos favoritos de tu empresa',
                deslizable: true,
              ),
              const SizedBox(height: 12),
              _buildTopInscritos(),

              _separador(),

              // 4) RETOS MEJOR CALIFICADOS
              _buildSectionHeader(
                '⭐',
                'Retos mejor calificados',
                'Promedio de las estrellas de sus píldoras',
                deslizable: true,
              ),
              const SizedBox(height: 12),
              _buildTopCalificados(),
              const SizedBox(height: 24),
            ],
          ),
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

  /// Permite arrastrar las listas horizontales también con el ratón (web)
  Widget _horizontal(Widget child) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      child: child,
    );
  }

  List<Color> _coloresReto(String retoId) {
    return _paleta[retoId.hashCode.abs() % _paleta.length];
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

  /// 5 estrellas con medias estrellas
  Widget _estrellas(double valor, {double size = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icono;
        if (valor >= i + 1) {
          icono = Icons.star_rounded;
        } else if (valor >= i + 0.5) {
          icono = Icons.star_half_rounded;
        } else {
          icono = Icons.star_border_rounded;
        }
        return Icon(icono, size: size, color: _ambar);
      }),
    );
  }

  Widget _separador({double vertical = 24}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: vertical),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              _indigo.withOpacity(0.2),
              _turquesa.withOpacity(0.35),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String emoji, String titulo, String subtitulo,
      {bool deslizable = false}) {
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
          if (deslizable)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Desliza',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _turquesa,
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: _turquesa),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEstadoVacio(String emoji, String titulo, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
      ),
    );
  }

  Widget _cargando() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: _turquesa),
        ),
      ),
    );
  }

  /// Devuelve un widget si las secciones 2-4 están cargando o con error
  Widget? _estadoDestacados() {
    if (_cargandoDestacados && _destacados == null) return _cargando();
    if (_errorDestacados != null && _destacados == null) {
      return _buildEstadoVacio(
        '⚠️',
        'No se pudo cargar',
        '$_errorDestacados\nDesliza hacia abajo para reintentar.',
      );
    }
    return null;
  }

  // ===================================================================
  // 1) RETO INSCRITO
  // ===================================================================

  Widget _buildRetoInscrito() {
    return Consumer<PlanificacionProvider>(
      builder: (context, plan, _) {
        final data = plan.data;

        if (data == null) {
          if (plan.errorMessage != null && !plan.isLoading) {
            return _buildEstadoVacio(
                '⚠️', 'No se pudo cargar tu reto', plan.errorMessage!);
          }
          return _cargando();
        }

        if (data.retosDelMes.isEmpty) {
          return _buildEstadoVacio(
            '🌱',
            'Aún no tienes un reto este mes',
            'Ve a la pestaña Retos para planificar tus próximos meses.',
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final unico = data.retosDelMes.length == 1;
            final ancho =
                unico ? constraints.maxWidth - 32 : constraints.maxWidth * 0.85;

            return SizedBox(
              height: 170,
              child: _horizontal(
                ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  itemCount: data.retosDelMes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => SizedBox(
                    width: ancho,
                    child: _buildRetoInscritoCard(
                      data.retosDelMes[i],
                      data.retosCompletados.contains(data.retosDelMes[i].id),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRetoInscritoCard(Reto reto, bool completado) {
    final total = reto.totalPills ?? 20;
    final completadas = _completadasPorReto[reto.id] ?? 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF4B4699), Color(0xFF3A7FA0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _indigo.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _abrirReto(reto),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Información del reto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        completado ? '✅ COMPLETADO' : 'INSCRITO',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: _turquesa,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reto.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$completadas/$total píldoras',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Bolitas de progreso (turquesa → morado)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: List.generate(total, (i) {
                          final hecha = i < completadas;
                          final t = total > 1 ? i / (total - 1) : 0.0;
                          return Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hecha
                                  ? Color.lerp(_turquesa, _morado, t)
                                  : Colors.white.withOpacity(0.22),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Botón Play
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _turquesa,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _turquesa.withOpacity(0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        completado ? Icons.replay : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      completado ? 'Repasar' : 'Play',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================================================================
  // 2) PÍLDORAS MEJOR CALIFICADAS (píldoras sueltas)
  // ===================================================================

  Widget _buildTopPildoras() {
    final estado = _estadoDestacados();
    if (estado != null) return estado;

    final lista = _destacados?.topPildoras ?? [];
    if (lista.isEmpty) {
      return _buildEstadoVacio(
        '💊',
        'Aún no hay píldoras calificadas',
        'Cuando se califiquen píldoras con estrellas, las mejores aparecerán aquí.',
      );
    }

    return SizedBox(
      height: 180,
      child: _horizontal(
        ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: lista.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final d = lista[i];
            final colores = _coloresReto(d.pildora.retoId);

            return GestureDetector(
              onTap: () => _abrirPildoraSuelta(d),
              child: SizedBox(
                width: 112,
                child: Column(
                  children: [
                    // Círculo con número y nota
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: colores,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colores[0].withOpacity(0.30),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              d.pildora.title,
                              maxLines: 3,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ),
                        // Puesto en el ranking
                        Positioned(
                          left: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: _indigo.withOpacity(0.15)),
                            ),
                            child: Text(
                              '#${i + 1}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: _indigo,
                              ),
                            ),
                          ),
                        ),
                        // Nota promedio
                        Positioned(
                          right: -6,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _ambar,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Text(
                              d.promedio.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _estrellas(d.promedio, size: 13),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Reto: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _indigo,
                            ),
                          ),
                          TextSpan(
                            text: d.retoTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _textoSuave,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, height: 1.25),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===================================================================
  // 3) TOP 10 RETOS MÁS INSCRITOS (estilo Netflix, solo informativo)
  // ===================================================================

  Widget _buildTopInscritos() {
    final estado = _estadoDestacados();
    if (estado != null) return estado;

    final lista = _destacados?.topInscritos ?? [];
    if (lista.isEmpty) {
      return _buildEstadoVacio(
        '🔥',
        'Aún no hay inscritos',
        'Cuando tus compañeros planifiquen retos, verás aquí los más populares.',
      );
    }

    return SizedBox(
      height: 200,
      child: _horizontal(
        ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          itemCount: lista.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final numero = '${i + 1}';
            final color = _colorPuesto(i, lista.length);
            // El "10" tiene dos cifras: necesita más espacio
            final anchoItem = numero.length > 1 ? 228.0 : 176.0;

            return SizedBox(
              width: anchoItem,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Número grande (detrás de la tarjeta)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: _numeroRanking(numero, color),
                  ),
                  // Tarjeta del reto (fondo sólido: tapa el número)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 124,
                    child: _tarjetaInscritos(lista[i], i + 1, color),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Color de cada puesto: empieza en índigo y va cambiando
  /// (índigo → morado → turquesa) hasta el último puesto
  Color _colorPuesto(int indice, int total) {
    if (total <= 1) return _indigo;
    final t = indice / (total - 1);
    if (t <= 0.5) return Color.lerp(_indigo, _morado, t * 2)!;
    return Color.lerp(_morado, _turquesa, (t - 0.5) * 2)!;
  }

  /// Tono pastel SÓLIDO: mezcla el color con blanco (sin transparencia)
  Color _pastel(Color color, double intensidad) {
    return Color.alphaBlend(color.withOpacity(intensidad), Colors.white);
  }

  /// Número del ranking: relleno sólido del color de su tarjeta
  Widget _numeroRanking(String numero, Color color) {
    return Text(
      numero,
      style: TextStyle(
        fontSize: 128,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: -8,
        color: color,
        shadows: [
          Shadow(
            color: color.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );
  }

  /// Tarjeta en tono pastel sólido del color de su puesto
  Widget _tarjetaInscritos(RetoDestacado r, int posicion, Color color) {
    final colorTexto = Color.lerp(color, _tinta, 0.15)!;
    final String? medalla = posicion == 1
        ? '🥇'
        : posicion == 2
            ? '🥈'
            : posicion == 3
                ? '🥉'
                : null;

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Colores SÓLIDOS → el número de detrás no se transparenta
        gradient: LinearGradient(
          colors: [_pastel(color, 0.16), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _pastel(color, 0.28)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // Arco decorativo muy tenue (como en el login y el reto inscrito)
          Positioned(
            right: -46,
            top: -46,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withOpacity(0.07),
                  width: 16,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Cajita pastel del emoji
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_pastel(color, 0.22), _pastel(color, 0.10)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _emojiReto(r.reto.title),
                      style: const TextStyle(fontSize: 21),
                    ),
                  ),
                  const Spacer(),
                  if (medalla != null)
                    Text(medalla, style: const TextStyle(fontSize: 20)),
                ],
              ),
              const Spacer(),
              Text(
                r.reto.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: _indigo,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              // Chip de inscritos (en el tono de la tarjeta)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _pastel(color, 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_alt_rounded,
                      size: 13,
                      color: colorTexto,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      r.inscritos == 1
                          ? '1 inscrito'
                          : '${r.inscritos} inscritos',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: colorTexto,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // 4) RETOS MEJOR CALIFICADOS (solo informativo)
  // ===================================================================

  Widget _buildTopCalificados() {
    final estado = _estadoDestacados();
    if (estado != null) return estado;

    final lista = _destacados?.topCalificados ?? [];
    if (lista.isEmpty) {
      return _buildEstadoVacio(
        '⭐',
        'Aún no hay retos calificados',
        'La nota de cada reto sale del promedio de las estrellas de sus píldoras.',
      );
    }

    return SizedBox(
      height: 168,
      child: _horizontal(
        ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          itemCount: lista.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final r = lista[i];
            final colores = _coloresReto(r.reto.id);

            return Container(
              width: 190,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colores[0].withOpacity(0.16)),
                boxShadow: [
                  BoxShadow(
                    color: _indigo.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estrellas + nota en círculo (como en el dibujo)
                  Row(
                    children: [
                      _estrellas(r.promedio, size: 15),
                      const Spacer(),
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _ambar.withOpacity(0.15),
                          border: Border.all(color: _ambar, width: 2),
                        ),
                        child: Text(
                          r.promedio.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: _tinta,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colores[0].withOpacity(0.18),
                              colores[1].withOpacity(0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _emojiReto(r.reto.title),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.reto.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: _indigo,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    r.totalUsuarios == 1
                        ? '1 persona · ${r.totalPildoras} píldoras'
                        : '${r.totalUsuarios} personas · ${r.totalPildoras} píldoras',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _textoSuave,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
