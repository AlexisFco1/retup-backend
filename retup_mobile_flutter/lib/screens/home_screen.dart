import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reto_provider.dart';
import '../providers/racha_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/planificacion_provider.dart';
import '../models/planificacion_model.dart';
import '../models/reto_model.dart';
import '../models/pildora_model.dart';
import '../services/pildoras_service.dart';
import '../utils/colors.dart';
import 'package:retup_mobile_flutter/screens/pildoras_list_screen.dart';
import '../widgets/custom_bottom_navigation_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0; // Home es el índice 0

  // Colores de texto y fondo de la pantalla
  static const Color _fondo = Color(0xFFF6F7FB);
  static const Color _texto = Color(0xFF1F2937);
  static const Color _textoSuave = Color(0xFF6B7280);

  // Paleta de colores para los retos (se asigna por orden)
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

  // Sección "Información de los retos"
  final PillorasService _pildorasService = PillorasService();
  final Map<String, List<Pildora>> _pildorasCache = {};
  final Set<String> _cargandoPildoras = {};
  String? _retoInfoId;

  @override
  void initState() {
    super.initState();
    _loadRetosYRegistrarLogin();
    _loadNotificationCount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlanificacionProvider>().cargar();
    });
  }

  Future<void> _loadNotificationCount() async {
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

  Future<void> _loadRetosYRegistrarLogin() async {
    // 1️⃣ Cargar retos
    await context.read<RetoProvider>().cargarRetos();

    // 2️⃣ Registrar login en racha para todos los retos
    await _registrarLoginEnRachas();
  }

  Future<void> _registrarLoginEnRachas() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final retoProvider = context.read<RetoProvider>();
      final rachaProvider = context.read<RachaProvider>();

      final userId = authProvider.userId;
      final token = authProvider.token;

      if (userId != null && token != null && retoProvider.retos.isNotEmpty) {
        print(
            '📍 Registrando login para ${retoProvider.retos.length} retos...');

        for (var retoLocal in retoProvider.retos) {
          try {
            await rachaProvider.registrarLogin(
              userId,
              retoLocal.reto.id,
              token,
            );
            print('✅ Login registrado para reto: ${retoLocal.reto.title}');
          } catch (e) {
            print(
                '⚠️ Error registrando login para ${retoLocal.reto.title}: $e');
          }
        }
      }
    } catch (e) {
      print('❌ Error en _registrarLoginEnRachas: $e');
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
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        title: const Text('RetUp - Mis Retos'),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<PlanificacionProvider>(
          builder: (context, plan, _) {
            final data = plan.data;

            if (data == null) {
              if (plan.errorMessage != null && !plan.isLoading) {
                return _buildError(plan.errorMessage!);
              }
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: () => context.read<PlanificacionProvider>().cargar(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1) RETOS DEL MES INSCRITOS (sección principal)
                    _buildHeaderRetosDelMes(data),
                    const SizedBox(height: 16),
                    _buildRetosDelMes(data),
                    const SizedBox(height: 32),

                    // 2) RETOS PLANIFICADOS
                    _buildSectionHeader(
                      '🗓️',
                      'Retos Planificados',
                      'Hasta 2 retos por mes · se bloquea el primer día laboral',
                      deslizable: true,
                    ),
                    const SizedBox(height: 14),
                    _buildPlanificacion(plan, data),
                    const SizedBox(height: 28),

                    // 3) INFORMACIÓN DE LOS RETOS
                    _buildSectionHeader(
                      '📚',
                      'Información de los Retos',
                      'Elige un reto para conocer sus píldoras',
                    ),
                    const SizedBox(height: 14),
                    _buildInfoRetos(data),
                    const SizedBox(height: 24),
                  ],
                ),
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

  List<Color> _gradienteReto(PlanificacionData data, String retoId) {
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
          if (deslizable)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Desliza',
                  style: TextStyle(fontSize: 11, color: _textoSuave),
                ),
                Icon(Icons.chevron_right, size: 16, color: _textoSuave),
              ],
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
              onPressed: () => context.read<PlanificacionProvider>().cargar(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  /// Hoja que sube desde abajo (bottom sheet) con estilo común
  Widget _hoja(BuildContext ctx, Widget child) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(ctx).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // 1) RETOS DEL MES INSCRITOS
  // ===================================================================

  Widget _buildHeaderRetosDelMes(PlanificacionData data) {
    final n = data.retosDelMes.length;
    final resumen = n == 0
        ? 'Aún no tienes retos inscritos'
        : (n == 1
            ? 'Tienes 1 reto para completar'
            : 'Tienes $n retos para completar');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '⭐ TU FOCO DE ESTE MES',
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
            'Retos del Mes Inscritos',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _texto,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${data.mesVigenteNombre} · $resumen',
            style: const TextStyle(fontSize: 13, color: _textoSuave),
          ),
        ],
      ),
    );
  }

  Widget _buildRetosDelMes(PlanificacionData data) {
    if (data.retosDelMes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildEstadoVacio(
          '🌱',
          'Aún no tienes retos este mes',
          'Planifica tus próximos meses en la sección de abajo.',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final unico = data.retosDelMes.length == 1;
        final ancho =
            (unico ? constraints.maxWidth - 32 : constraints.maxWidth * 0.82)
                .clamp(260.0, 440.0);

        return SizedBox(
          height: 250,
          child: _horizontal(
            ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: data.retosDelMes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => SizedBox(
                width: ancho,
                child: _buildRetoDelMesCard(data, data.retosDelMes[i]),
              ),
            ),
          ),
        );
      },
    );
  }

  void _abrirReto(Reto reto) {
    // Mantener sincronizado el RetoProvider (se usa en otras pantallas)
    final retoProvider = context.read<RetoProvider>();
    final locales = retoProvider.retos.where((r) => r.reto.id == reto.id);
    if (locales.isNotEmpty) {
      retoProvider.seleccionarReto(locales.first);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PillorasListScreen(reto: reto),
      ),
    );
  }

  Widget _buildRetoDelMesCard(PlanificacionData data, Reto reto) {
    final completado = data.retosCompletados.contains(reto.id);
    final colores = _gradienteReto(data, reto.id);
    final mesNombre = data.mesVigenteNombre.split(' ').first.toUpperCase();
    final totalPildoras = reto.totalPills ?? 20;
    final detalle = (reto.category ?? '').isNotEmpty
        ? '${reto.category} · $totalPildoras píldoras'
        : '$totalPildoras píldoras';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colores[0].withOpacity(0.45),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _abrirReto(reto),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colores,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Círculos decorativos
                Positioned(
                  right: -40,
                  top: -40,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  left: -30,
                  bottom: -50,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Contenido
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Etiquetas
                      Row(
                        children: [
                          _chip(
                            'INSCRITO · $mesNombre',
                            fondo: Colors.white.withOpacity(0.22),
                            colorTexto: Colors.white,
                          ),
                          const Spacer(),
                          if (completado)
                            _chip(
                              '✅ Completado',
                              fondo: Colors.white,
                              colorTexto: colores[1],
                            ),
                        ],
                      ),

                      // Emoji + título
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              _emojiReto(reto.title),
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reto.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  detalle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Botón principal
                      Container(
                        height: 52,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: colores),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                completado
                                    ? Icons.replay
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              completado ? 'Repasar reto' : 'Comenzar reto',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: colores[1],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded,
                                size: 18, color: colores[1]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================================================================
  // 2) RETOS PLANIFICADOS
  // ===================================================================

  Widget _buildPlanificacion(
      PlanificacionProvider plan, PlanificacionData data) {
    if (data.meses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildEstadoVacio(
          '🗓️',
          'Nada que planificar',
          'No hay meses disponibles para planificar por ahora.',
        ),
      );
    }

    return SizedBox(
      height: 214,
      child: _horizontal(
        ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: data.meses.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _buildMesCard(plan, data, data.meses[i]),
        ),
      ),
    );
  }

  Widget _buildMesCard(PlanificacionProvider plan, PlanificacionData data,
      MesPlanificacion mes) {
    final bloqueado = mes.bloqueado;
    final coloresCabecera = bloqueado
        ? const [Color(0xFF475569), Color(0xFF334155)]
        : const [Color(0xFF6366F1), Color(0xFF8B5CF6)];
    final fechaCorta = mes.fechaBloqueoTexto.length >= 5
        ? mes.fechaBloqueoTexto.substring(0, 5)
        : mes.fechaBloqueoTexto;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera del mes
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: coloresCabecera,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mes.nombreMes,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${mes.anio} · ${mes.planes.length}/2 retos',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _chip(
                    bloqueado ? '🔒 Inscrito' : 'Cierra $fechaCorta',
                    fondo: Colors.white.withOpacity(0.2),
                    colorTexto: Colors.white,
                  ),
                ],
              ),
            ),
            // Huecos para los retos
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: bloqueado
                      ? [
                          for (final p in mes.planes) ...[
                            _buildSlot(plan, data, mes, p.slot),
                            const SizedBox(height: 8),
                          ],
                        ]
                      : [
                          _buildSlot(plan, data, mes, 1),
                          const SizedBox(height: 8),
                          _buildSlot(plan, data, mes, 2),
                        ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(PlanificacionProvider plan, PlanificacionData data,
      MesPlanificacion mes, int slot) {
    final valor = mes.retoEnSlot(slot);
    final guardando = plan.estaGuardando(mes, slot);
    final opciones = plan.opcionesPara(mes, slot);

    // Guardando...
    if (guardando) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: _fondo,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Hueco vacío
    if (valor == null) {
      final sinOpciones = opciones.isEmpty;
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: sinOpciones ? null : () => _abrirSelector(plan, data, mes, slot),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _fondo,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryColor.withOpacity(0.25),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 20,
                color: sinOpciones ? AppColors.grey : AppColors.primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sinOpciones ? 'No hay retos disponibles' : 'Escoja un reto',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color:
                        sinOpciones ? AppColors.grey : AppColors.primaryColor,
                  ),
                ),
              ),
              if (!sinOpciones)
                const Icon(Icons.keyboard_arrow_down, color: _textoSuave),
            ],
          ),
        ),
      );
    }

    // Hueco con reto elegido
    final colores = _gradienteReto(data, valor);
    final titulo = data.tituloReto(valor);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: mes.bloqueado ? null : () => _abrirSelector(plan, data, mes, slot),
      child: Container(
        height: 52,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: colores[0].withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colores[0].withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colores),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_emojiReto(titulo),
                  style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _texto,
                ),
              ),
            ),
            if (mes.bloqueado)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.lock_outline, size: 16, color: _textoSuave),
              )
            else
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: _textoSuave),
                tooltip: 'Quitar reto',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => _guardarSeleccion(mes, slot, null),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirSelector(PlanificacionProvider plan,
      PlanificacionData data, MesPlanificacion mes, int slot) async {
    final opciones = plan.opcionesPara(mes, slot);
    final actual = mes.retoEnSlot(slot);

    final elegido = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _hoja(
        ctx,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${mes.nombre} · Reto $slot',
              style: const TextStyle(
                fontSize: 13,
                color: _textoSuave,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Escoja un reto',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _texto,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: opciones.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final r = opciones[i];
                  return _buildOpcionReto(ctx, data, r, r.id == actual);
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (elegido != null && elegido != actual) {
      await _guardarSeleccion(mes, slot, elegido);
    }
  }

  Widget _buildOpcionReto(
      BuildContext ctx, PlanificacionData data, Reto r, bool seleccionado) {
    final colores = _gradienteReto(data, r.id);
    final partes = <String>[
      if ((r.category ?? '').isNotEmpty) r.category!,
      if ((r.difficulty ?? '').isNotEmpty) 'Nivel ${r.difficulty}',
      '${r.totalPills ?? 20} píldoras',
    ];

    return Material(
      color: seleccionado ? colores[0].withOpacity(0.1) : _fondo,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(ctx, r.id),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: seleccionado ? colores[0] : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colores),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_emojiReto(r.title),
                    style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _texto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      partes.join(' · '),
                      style: const TextStyle(fontSize: 12, color: _textoSuave),
                    ),
                  ],
                ),
              ),
              if (seleccionado) Icon(Icons.check_circle, color: colores[0]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _guardarSeleccion(
      MesPlanificacion mes, int slot, String? retoId) async {
    final error = await context
        .read<PlanificacionProvider>()
        .asignarReto(mes, slot, retoId);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  // ===================================================================
  // 3) INFORMACIÓN DE LOS RETOS
  // ===================================================================

  void _asegurarPildoras(String retoId) {
    if (_pildorasCache.containsKey(retoId) ||
        _cargandoPildoras.contains(retoId)) {
      return;
    }
    _cargandoPildoras.add(retoId);

    _pildorasService.getByRetoId(retoId).then((lista) {
      lista
          .sort((a, b) => (a.pillNumber ?? 999).compareTo(b.pillNumber ?? 999));
      if (!mounted) return;
      setState(() {
        _pildorasCache[retoId] = lista;
        _cargandoPildoras.remove(retoId);
      });
    });
  }

  Widget _buildInfoRetos(PlanificacionData data) {
    if (data.retos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildEstadoVacio(
          '📚',
          'Todavía no hay retos',
          'Cuando tu empresa active retos, aparecerán aquí.',
        ),
      );
    }

    final reto = data.retos.firstWhere(
      (r) => r.id == _retoInfoId,
      orElse: () => data.retos.first,
    );
    _asegurarPildoras(reto.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector de retos (se desliza hacia los lados)
        SizedBox(
          height: 140,
          child: _horizontal(
            ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: data.retos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final r = data.retos[i];
                return _buildRetoChip(data, r, r.id == reto.id);
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Tarjeta con la información del reto seleccionado
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: ValueKey(reto.id),
            child: _buildInfoCard(data, reto),
          ),
        ),
      ],
    );
  }

  Widget _buildRetoChip(PlanificacionData data, Reto reto, bool activo) {
    final colores = _gradienteReto(data, reto.id);
    final completado = data.retosCompletados.contains(reto.id);
    final subtitulo = (reto.category ?? '').isNotEmpty
        ? reto.category!
        : '${reto.totalPills ?? 20} píldoras';

    return GestureDetector(
      onTap: () => setState(() => _retoInfoId = reto.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: activo
              ? LinearGradient(
                  colors: colores,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: activo ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo ? Colors.transparent : colores[0].withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: activo
                  ? colores[0].withOpacity(0.35)
                  : Colors.black.withOpacity(0.04),
              blurRadius: activo ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activo
                        ? Colors.white.withOpacity(0.2)
                        : colores[0].withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_emojiReto(reto.title),
                      style: const TextStyle(fontSize: 20)),
                ),
                const Spacer(),
                if (completado)
                  const Text('✅', style: TextStyle(fontSize: 13))
                else if (activo)
                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
              ],
            ),
            const Spacer(),
            Text(
              reto.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: activo ? Colors.white : _texto,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: activo ? Colors.white70 : _textoSuave,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(PlanificacionData data, Reto reto) {
    final colores = _gradienteReto(data, reto.id);
    final pildoras = _pildorasCache[reto.id];
    final descripcion = (reto.description ?? '').trim();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera de color
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
            child: Row(
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if ((reto.category ?? '').isNotEmpty)
                            _chip(reto.category!,
                                fondo: Colors.white.withOpacity(0.2),
                                colorTexto: Colors.white),
                          if ((reto.difficulty ?? '').isNotEmpty)
                            _chip('Nivel ${reto.difficulty}',
                                fondo: Colors.white.withOpacity(0.2),
                                colorTexto: Colors.white),
                          _chip(
                              '${pildoras?.length ?? reto.totalPills ?? 0} píldoras',
                              fondo: Colors.white.withOpacity(0.2),
                              colorTexto: Colors.white),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Descripción
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              descripcion.isNotEmpty
                  ? descripcion
                  : 'Este reto aún no tiene descripción.',
              style: const TextStyle(fontSize: 14, color: _texto, height: 1.5),
            ),
          ),

          // Título de píldoras
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: const [
                Text(
                  'Píldoras',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _texto,
                  ),
                ),
                Spacer(),
                Text(
                  'Desliza',
                  style: TextStyle(fontSize: 11, color: _textoSuave),
                ),
                Icon(Icons.chevron_right, size: 16, color: _textoSuave),
              ],
            ),
          ),

          // Carrusel de píldoras
          if (pildoras == null)
            const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (pildoras.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Este reto aún no tiene píldoras.',
                style: TextStyle(color: _textoSuave),
              ),
            )
          else
            SizedBox(
              height: 100,
              child: _horizontal(
                ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: pildoras.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final p = pildoras[i];
                    return _buildPildoraCard(reto, p, p.pillNumber ?? (i + 1),
                        pildoras.length, colores);
                  },
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPildoraCard(
      Reto reto, Pildora p, int numero, int total, List<Color> colores) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colores[0].withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colores[0].withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colores),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$numero',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              if (p.durationMinutes != null)
                Text(
                  '${p.durationMinutes} min',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _textoSuave,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              p.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _texto,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
