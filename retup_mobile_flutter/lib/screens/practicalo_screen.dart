// practicalo_screen.dart - REDISEÑO VISUAL (misma armonía que home y rachas)

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_bottom_navigation_bar.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../services/notification_service.dart';
import '../providers/practicalo_provider.dart';
import '../utils/colors.dart';

class PracticaloScreen extends StatefulWidget {
  const PracticaloScreen({Key? key}) : super(key: key);

  @override
  State<PracticaloScreen> createState() => _PracticaloScreenState();
}

class _PracticaloScreenState extends State<PracticaloScreen> {
  int _currentNavIndex = 3;
  final NotificationService _notificationService = NotificationService();

  List<Map<String, dynamic>> _mensajesAgrupados = [];
  bool _isLoading = true;
  String? _errorMessage;

  // ===== Colores (mismos que home y rachas) =====
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
    [Color(0xFFEC4899), Color(0xFFDB2777)], // Rosa
    [Color(0xFF3B82F6), Color(0xFF2563EB)], // Azul
  ];
  static const List<Color> _azul = [Color(0xFF3B82F6), Color(0xFF2563EB)];
  static const List<Color> _violeta = [Color(0xFF8B5CF6), Color(0xFF7C3AED)];
  static const List<Color> _verde = [Color(0xFF10B981), Color(0xFF059669)];
  static const List<Color> _ambar = [Color(0xFFF59E0B), Color(0xFFD97706)];
  static const Color _rojo = Color(0xFFEF4444);
  static const Color _gris = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _cargarMensajes();
    _cargarPracticalo();
  }

  Future<void> _cargarMensajes() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.userId;
      final token = authProvider.token;

      if (userId == null || token == null) {
        setState(() {
          _errorMessage = 'No hay usuario autenticado';
          _isLoading = false;
        });
        return;
      }

      print('🔍 Cargando notificaciones para usuario: $userId');

      final notificaciones = await _notificationService.getAllNotifications(
        token: token,
        userId: userId,
      );

      print('✅ Notificaciones recibidas: ${notificaciones.length}');

      final Map<String, Map<String, dynamic>> agrupadas = {};

      for (var notif in notificaciones) {
        if (notif['reto_id'] != null &&
            notif['pill_id'] != null &&
            !(notif['message'] as String).toLowerCase().contains('califi') &&
            !(notif['message'] as String)
                .toLowerCase()
                .contains('invitación de práctica')) {
          final message = notif['message'] ?? 'Sin mensaje';
          final key = '$message-${notif['reto_id']}-${notif['pill_id']}';

          if (!agrupadas.containsKey(key)) {
            agrupadas[key] = {
              'message': message,
              'reto_id': notif['reto_id'],
              'pill_id': notif['pill_id'],
              'senderCount': 0,
              'notificationIds': <String>[],
            };
          }

          agrupadas[key]!['senderCount'] =
              (agrupadas[key]!['senderCount'] as int) + 1;
          agrupadas[key]!['notificationIds'].add(notif['id']);
        }
      }

      setState(() {
        _mensajesAgrupados = agrupadas.values.toList();
        _isLoading = false;
      });

      print('✅ Mensajes agrupados: ${_mensajesAgrupados.length}');

      // 🔔 Marcar automáticamente TODAS las notificaciones como leídas (BATCH)
      try {
        final allNotificationIds = <String>[];

        allNotificationIds.addAll(
          agrupadas.values
              .expand((grupo) => grupo['notificationIds'] as List<String>)
              .toList(),
        );

        for (var notif in notificaciones) {
          if (notif['reto_id'] != null && notif['pill_id'] != null) {
            allNotificationIds.add(notif['id']);
          }
        }

        final uniqueIds = allNotificationIds.toSet().toList();

        if (uniqueIds.isNotEmpty) {
          await _notificationService.markAllAsRead(
            token: token,
            notificationIds: uniqueIds,
          );
          print('✅ ${uniqueIds.length} notificaciones marcadas como leídas');
        }
      } catch (e) {
        print('⚠️ Error marcando como leído: $e');
      }

      try {
        if (mounted) {
          context.read<NotificationProvider>().resetUnreadCount();
        }
      } catch (e) {
        print('⚠️ Error reseteando contador: $e');
      }
    } catch (e) {
      print('❌ Error al cargar mensajes: $e');
      setState(() {
        _errorMessage = 'Error al cargar los mensajes: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarPracticalo() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.userId;
      final token = authProvider.token;
      final practicaloProvider = context.read<PracticaloProvider>();

      if (userId != null && token != null) {
        print('🔍 Cargando prácticas para usuario: $userId');
        await practicaloProvider.cargarRecibidas(
          token: token,
          userId: userId,
        );
        await practicaloProvider.cargarEnviadas(
          token: token,
          userId: userId,
        );
        print('✅ Prácticas cargadas');
      }
    } catch (e) {
      print('❌ Error cargando prácticas: $e');
    }
  }

  void _onNavTap(int index) {
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
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token ?? '';

    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        title: const Text('Practícalo'),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildError(_errorMessage!)
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Consumer<PracticaloProvider>(
                      builder: (context, practicaloProvider, child) {
                        final recibidas =
                            practicaloProvider.practicaloRecibidas;
                        final enviadas = practicaloProvider.practicaloEnviadas;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ===== CABECERA =====
                            _buildHeader(),
                            const SizedBox(height: 24),

                            // ===== 1) MENSAJES DEL MEJOR =====
                            if (_mensajesAgrupados.isNotEmpty) ...[
                              _buildSectionHeader(
                                '🚀',
                                'Mensajes del mejor',
                                'Lo que tus compañeros valoran de ti',
                                deslizable: _mensajesAgrupados.length > 1,
                              ),
                              const SizedBox(height: 14),
                              _buildMensajes(),

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
                                        const Color(0xFF6366F1)
                                            .withOpacity(0.2),
                                        const Color(0xFF8B5CF6)
                                            .withOpacity(0.2),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            // ===== 2) PRÁCTICA RECIBIDA =====
                            _buildSectionHeader(
                              '📥',
                              'Práctica recibida',
                              'Compañeros que te invitan a practicar',
                              deslizable: recibidas.length > 1,
                            ),
                            const SizedBox(height: 14),
                            if (recibidas.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: _buildEstadoVacio(
                                  '📭',
                                  'Aún no tienes prácticas recibidas',
                                  'Cuando un compañero te invite a practicar una píldora, aparecerá aquí.',
                                ),
                              )
                            else
                              SizedBox(
                                height: 262,
                                child: _horizontal(
                                  ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 4, 16, 16),
                                    itemCount: recibidas.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) =>
                                        _buildRecibidaCard(
                                      recibidas[index],
                                      practicaloProvider,
                                      token,
                                    ),
                                  ),
                                ),
                              ),

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

                            // ===== 3) PRÁCTICA ENVIADA =====
                            _buildSectionHeader(
                              '📤',
                              'Práctica enviada',
                              'Invitaciones que hiciste a tus compañeros',
                              deslizable: enviadas.length > 1,
                            ),
                            const SizedBox(height: 14),
                            if (enviadas.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: _buildEstadoVacio(
                                  '✉️',
                                  'Aún no has enviado prácticas',
                                  'Invita a un compañero a practicar una píldora contigo.',
                                ),
                              )
                            else
                              SizedBox(
                                height: 262,
                                child: _horizontal(
                                  ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 4, 16, 16),
                                    itemCount: enviadas.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) =>
                                        _buildEnviadaCard(
                                      enviadas[index],
                                      practicaloProvider,
                                      token,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
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

  Widget _buildHeader() {
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
              '🤝 APRENDE CON TU EQUIPO',
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
            'Practícalo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _texto,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Practica tus píldoras con compañeros y recibe feedback',
            style: TextStyle(fontSize: 13, color: _textoSuave),
          ),
        ],
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
                Text('Desliza',
                    style: TextStyle(fontSize: 11, color: _textoSuave)),
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
              onPressed: () {
                _cargarMensajes();
                _cargarPracticalo();
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  /// Avatar redondo con la inicial del nombre
  Widget _avatar(String nombre, List<Color> colores) {
    final inicial =
        nombre.trim().isNotEmpty ? nombre.trim()[0].toUpperCase() : '?';
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colores,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Text(
        inicial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }

  /// Burbuja con el mensaje de la práctica
  Widget _burbuja(String mensaje, Color acento) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: acento.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: acento.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded, size: 18, color: acento),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              mensaje,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: _texto,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Botón con degradado
  Widget _botonGradiente({
    required String texto,
    required List<Color> colores,
    required VoidCallback onTap,
    IconData? icono,
  }) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 42,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colores),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colores[0].withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icono != null) ...[
                Icon(icono, size: 18, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  texto,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Botón con borde (acción secundaria)
  Widget _botonBorde({
    required String texto,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 42,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.4), width: 1.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  /// Barra de estado (ocupa todo el ancho, alineada con los botones)
  Widget _estadoBarra(String texto, Color color, IconData icono) {
    return Container(
      height: 42,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fila de estrellas + texto
  Widget _estrellas(dynamic rating, String prefijo) {
    final int n = rating is num ? rating.round() : int.tryParse('$rating') ?? 0;
    return Row(
      children: [
        ...List.generate(
          5,
          (i) => Icon(
            Icons.star_rounded,
            size: 16,
            color: i < n ? _ambar[0] : const Color(0xFFE5E7EB),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$prefijo $n/5',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _textoSuave,
            ),
          ),
        ),
      ],
    );
  }

  String _textoRespuesta(dynamic response) {
    switch (response) {
      case 'yes_today':
        return 'Aceptaste la práctica';
      case 'yes_later':
        return 'Aceptaste para más tarde';
      case 'no_thanks':
        return 'Rechazaste la práctica';
      default:
        return 'Respondida: $response';
    }
  }

  String _textoStatus(dynamic status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'accepted':
        return 'Aceptada';
      case 'completed':
        return 'Completada';
      case 'rejected':
        return 'Rechazada';
      case 'cancelled':
        return 'Anulada';
      default:
        return status == null ? 'Pendiente' : '$status';
    }
  }

  Widget _tarjetaBase({required Widget child}) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ===================================================================
  // 1) MENSAJES DEL MEJOR
  // ===================================================================

  Widget _buildMensajes() {
    return SizedBox(
      height: 196,
      child: _horizontal(
        ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: _mensajesAgrupados.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final mensaje = _mensajesAgrupados[index];
            final message = mensaje['message'] as String;
            final senderCount = mensaje['senderCount'] as int;
            final colores = _paleta[index % _paleta.length];

            return Container(
              width: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: colores,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colores[0].withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          color: Colors.white.withOpacity(0.8),
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ),
                        _chip(
                          '👥 $senderCount ${senderCount == 1 ? 'compañero' : 'compañeros'}',
                          fondo: Colors.white.withOpacity(0.22),
                          colorTexto: Colors.white,
                        ),
                      ],
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

  // ===================================================================
  // 2) PRÁCTICA RECIBIDA
  // ===================================================================

  Widget _buildRecibidaCard(
    Map<String, dynamic> practica,
    PracticaloProvider practicaloProvider,
    String token,
  ) {
    final senderName = practica['sender_user']?['full_name'] ??
        practica['sender_user']?['email'] ??
        'Compañero';
    final mensaje = practica['message'] ?? 'Sin mensaje';
    final response = practica['response'];

    Widget acciones;
    if (response == null) {
      acciones = Column(
        children: [
          _botonGradiente(
            texto: 'Sí, cuando puedas coordinamos',
            colores: _verde,
            icono: Icons.check_rounded,
            onTap: () async {
              await practicaloProvider.responderInvitacion(
                token: token,
                practicaloId: practica['id'],
                response: 'yes_today',
              );
            },
          ),
          const SizedBox(height: 8),
          _botonBorde(
            texto: 'No, gracias',
            color: _rojo,
            onTap: () async {
              await practicaloProvider.responderInvitacion(
                token: token,
                practicaloId: practica['id'],
                response: 'no_thanks',
              );
            },
          ),
        ],
      );
    } else if (practica['status'] == 'completed' &&
        practica['star_rating'] == null) {
      acciones = _botonGradiente(
        texto: 'Calificar práctica',
        colores: _ambar,
        icono: Icons.star_rounded,
        onTap: () {
          _mostrarCalificacion(
            context,
            practica['id'],
            practica['sender_name'] ?? senderName,
            practicaloProvider,
            token,
          );
        },
      );
    } else if (practica['status'] == 'completed' &&
        practica['star_rating'] != null) {
      acciones = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _estrellas(practica['star_rating'], 'Calificaste con'),
          const SizedBox(height: 8),
          _estadoBarra(
              'Práctica completada', _verde[1], Icons.verified_rounded),
        ],
      );
    } else if (response == 'no_thanks') {
      acciones =
          _estadoBarra(_textoRespuesta(response), _rojo, Icons.close_rounded);
    } else {
      acciones = _estadoBarra(
          _textoRespuesta(response), _azul[1], Icons.event_available_rounded);
    }

    return _tarjetaBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(senderName, _azul),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'De',
                      style: TextStyle(fontSize: 11, color: _textoSuave),
                    ),
                    Text(
                      senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _texto,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _burbuja(mensaje, _azul[0]),
          const Spacer(),
          acciones,
        ],
      ),
    );
  }

  // ===================================================================
  // 3) PRÁCTICA ENVIADA
  // ===================================================================

  Widget _buildEnviadaCard(
    Map<String, dynamic> practica,
    PracticaloProvider practicaloProvider,
    String token,
  ) {
    final recipientName = practica['recipient_user']?['full_name'] ??
        practica['recipient_user']?['email'] ??
        'Compañero';
    final response = practica['response'];
    final status = practica['status'];

    Widget acciones;
    if (response == 'yes_today' && status != 'completed') {
      acciones = _botonGradiente(
        texto: 'Confirmar práctica realizada',
        colores: _azul,
        icono: Icons.task_alt_rounded,
        onTap: () async {
          await practicaloProvider.confirmarReunion(
            token: token,
            practicaloId: practica['id'],
          );
        },
      );
    } else if (response == 'no_thanks') {
      acciones = _estadoBarra('Práctica anulada', _rojo, Icons.block_rounded);
    } else if (status == 'completed' && practica['star_rating'] == null) {
      acciones = _estadoBarra(
          'Esperando calificación', _ambar[1], Icons.hourglass_top_rounded);
    } else if (status == 'completed' && practica['star_rating'] != null) {
      acciones = _estadoBarra(
          'Práctica completada', _verde[1], Icons.verified_rounded);
    } else {
      acciones =
          _estadoBarra('Esperando respuesta', _gris, Icons.schedule_rounded);
    }

    return _tarjetaBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(recipientName, _violeta),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Para',
                      style: TextStyle(fontSize: 11, color: _textoSuave),
                    ),
                    Text(
                      recipientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _texto,
                      ),
                    ),
                  ],
                ),
              ),
              _chip(
                _textoStatus(status),
                fondo: _violeta[0].withOpacity(0.1),
                colorTexto: _violeta[1],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _burbuja(practica['message'] ?? 'Sin mensaje', _violeta[0]),
          if (practica['star_rating'] != null) ...[
            const SizedBox(height: 10),
            _estrellas(practica['star_rating'], 'Te calificaron con'),
          ],
          const Spacer(),
          acciones,
        ],
      ),
    );
  }

  // ===================================================================
  // DIÁLOGO DE CALIFICACIÓN
  // ===================================================================

  void _mostrarCalificacion(
    BuildContext context,
    String practicaloId,
    String recipientName,
    PracticaloProvider practicaloProvider,
    String token,
  ) {
    int estrellas = 0;
    const etiquetas = [
      'Toca una estrella',
      'Mejorable',
      'Regular',
      'Bien',
      'Muy bien',
      '¡Excelente!',
    ];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
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
                          colors: _ambar,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: _ambar[0].withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Text('⭐', style: TextStyle(fontSize: 34)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Califica a $recipientName',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _texto,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '¿Cómo fue la práctica?',
                      style: TextStyle(fontSize: 13.5, color: _textoSuave),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              estrellas = index + 1;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Icon(
                              Icons.star_rounded,
                              size: 40,
                              color: index < estrellas
                                  ? _ambar[0]
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      etiquetas[estrellas],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: estrellas > 0 ? _ambar[1] : _textoSuave,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                side:
                                    const BorderSide(color: Color(0xFFE5E7EB)),
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
                          child: Opacity(
                            opacity: estrellas > 0 ? 1.0 : 0.5,
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
                                    if (estrellas > 0) {
                                      await practicaloProvider.calificar(
                                        token: token,
                                        practicaloId: practicaloId,
                                        starRating: estrellas,
                                      );
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext);
                                      }
                                      if (mounted) {
                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content:
                                                Text('Calificación guardada'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: const Center(
                                    child: Text(
                                      'Guardar',
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
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
