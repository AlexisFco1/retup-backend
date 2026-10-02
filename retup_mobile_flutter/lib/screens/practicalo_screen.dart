// practicalo_screen.dart - IDENTIDAD DE MARCA RETUP (armonía página web)

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
  int _currentNavIndex = 4; // Practícalo es el índice 4
  final NotificationService _notificationService = NotificationService();

  List<Map<String, dynamic>> _mensajesAgrupados = [];
  // Ids de las tarjetas que están saliendo (animación al responder)
  final Set<String> _saliendo = {};
  bool _isLoading = true;
  String? _errorMessage;

  // ===== Colores de marca RetUp (Paleta "Vínculo") =====
  static const Color _indigo = Color(0xFF2E2A72); // Predomina
  static const Color _indigoClaro = Color(0xFF443E9E);
  static const Color _turquesa = Color(0xFF12B5A6); // Botones y acentos
  static const Color _turquesaOscuro = Color(0xFF0B8A7E);
  static const Color _morado = Color(0xFF7209B7); // Compromiso
  static const Color _tinta = Color(0xFF0E0F17); // Texto

  static const Color _fondo = Color(0xFFF5F5F2); // Blanco roto como la web
  static const Color _texto = _tinta;
  static const Color _textoSuave = Color(0xFF6B7280);

  static const List<Color> _botonPrincipal = [_turquesa, _turquesaOscuro];

  // Colores de estado (se mantienen por ser universales)
  static const Color _dorado = Color(0xFFF59E0B); // Estrellas de calificación
  static const List<Color> _verde = [Color(0xFF10B981), Color(0xFF059669)];
  static const Color _rojo = Color(0xFFEF4444);
  static const Color _gris = Color(0xFF9CA3AF);

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
        Navigator.pushReplacementNamed(context, '/retos');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/social');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/rachas');
        break;
      case 4:
        break; // Ya estamos en Practícalo
      case 5:
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
              'Practícalo',
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
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Consumer<PracticaloProvider>(
                      builder: (context, practicaloProvider, child) {
                        // Orden: 1º acción pendiente, 2º en espera, 3º terminadas/canceladas
                        final recibidas = _ordenarPorPrioridad(
                          practicaloProvider.practicaloRecibidas,
                          _prioridadRecibida,
                        );
                        final enviadas = _ordenarPorPrioridad(
                          practicaloProvider.practicaloEnviadas,
                          _prioridadEnviada,
                        );

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
                              _separador(),
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
                                        _tarjetaAnimada(
                                      id: recibidas[index]['id'].toString(),
                                      index: index,
                                      child: _buildRecibidaCard(
                                        recibidas[index],
                                        practicaloProvider,
                                        token,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // ── Separador 2 ──
                            _separador(),

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
                                        _tarjetaAnimada(
                                      id: enviadas[index]['id'].toString(),
                                      index: index,
                                      child: _buildEnviadaCard(
                                        enviadas[index],
                                        practicaloProvider,
                                        token,
                                      ),
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

  /// Separador fino entre secciones (índigo → turquesa)
  Widget _separador() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _turquesa,
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
              color: _indigo,
            ),
          ),
          const SizedBox(height: 2),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 13, color: _textoSuave),
              children: [
                TextSpan(
                    text: 'Practica tus píldoras con compañeros y recibe '),
                TextSpan(
                  text: 'feedback',
                  style: TextStyle(
                    color: _turquesa,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
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
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: acento.withOpacity(0.18)),
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
              color: colores[0].withOpacity(0.25),
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
          backgroundColor: Colors.white.withOpacity(0.7),
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
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35), width: 1.3),
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
            color: i < n ? _dorado : const Color(0xFFE5E7EB),
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

  // ===================================================================
  // ORDEN DE PRÁCTICAS: 0 = te toca hacer algo, 1 = en espera, 2 = terminada
  // (mismas condiciones que deciden qué muestra cada tarjeta)
  // ===================================================================

  int _prioridadRecibida(Map<String, dynamic> p) {
    final response = p['response'];
    final status = p['status'];
    final calificada = p['star_rating'] != null;

    if (response == null) return 0; // Responder Sí / No
    if (status == 'completed' && !calificada) return 0; // Calificar práctica
    if (status == 'completed' && calificada) return 2; // Completada
    if (response == 'no_thanks') return 2; // Rechazada
    return 1; // Aceptada: esperando que el compañero confirme
  }

  int _prioridadEnviada(Map<String, dynamic> p) {
    final response = p['response'];
    final status = p['status'];
    final calificada = p['star_rating'] != null;

    if (response == 'yes_today' && status != 'completed') return 0; // Confirmar
    if (response == 'no_thanks') return 2; // Anulada
    if (status == 'completed' && calificada) return 2; // Completada
    return 1; // Esperando respuesta o esperando calificación
  }

  /// Ordena por prioridad; si empatan, conserva el orden original
  List<Map<String, dynamic>> _ordenarPorPrioridad(
    List<dynamic> lista,
    int Function(Map<String, dynamic>) prioridad,
  ) {
    final conIndice = lista
        .asMap()
        .entries
        .map((e) => MapEntry(e.key, Map<String, dynamic>.from(e.value as Map)))
        .toList();

    conIndice.sort((a, b) {
      final pa = prioridad(a.value);
      final pb = prioridad(b.value);
      if (pa != pb) return pa - pb;
      return a.key - b.key; // Mismo grupo: orden original
    });

    return conIndice.map((e) => e.value).toList();
  }

  // ===================================================================
  // ANIMACIÓN DE TARJETAS AL CAMBIAR DE LUGAR
  // ===================================================================

  /// 1) La tarjeta sale (baja y se desvanece), 2) se ejecuta la acción,
  /// 3) la lista se reordena y las tarjetas entran en su nuevo lugar
  Future<void> _animarSalida(String id, Future<bool> Function() accion) async {
    if (_saliendo.contains(id)) return; // Evita doble toque
    setState(() => _saliendo.add(id));
    await Future.delayed(const Duration(milliseconds: 350));

    final ok = await accion();
    if (!mounted) return;
    setState(() => _saliendo.remove(id));

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('✅ Respuesta guardada · la tarjeta cambió de lugar'),
          backgroundColor: _turquesaOscuro,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  /// Envuelve una tarjeta: animación de salida y de entrada en su nueva posición
  Widget _tarjetaAnimada({
    required String id,
    required int index,
    required Widget child,
  }) {
    final saliendo = _saliendo.contains(id);

    return KeyedSubtree(
      // Si la tarjeta cambia de posición, cambia la llave → anima la entrada
      key: ValueKey('$id-$index'),
      child: AnimatedSlide(
        offset: saliendo ? const Offset(0, 0.25) : Offset.zero,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInCubic,
        child: AnimatedOpacity(
          opacity: saliendo ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Transform.translate(
              offset: Offset(70 * t, 0), // Entra deslizándose desde la derecha
              child: Opacity(opacity: 1 - t * 0.7, child: child),
            ),
            child: child,
          ),
        ),
      ),
    );
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

  /// Tarjeta base con degradado pastel del color de acento
  Widget _tarjetaBase({required Widget child, required Color acento}) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [acento.withOpacity(0.10), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: acento.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: _indigo.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ===================================================================
  // 1) MENSAJES DEL MEJOR (bloque protagonista en índigo)
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

            return Container(
              width: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                // Degradado suave: índigo claro → azul verdoso (inspirado en el logo)
                gradient: const LinearGradient(
                  colors: [Color(0xFF4B4699), Color(0xFF3A7FA0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _indigo.withOpacity(0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Arcos decorativos (como el login y la web)
                  Positioned(
                    right: -50,
                    top: -50,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                          width: 24,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -40,
                    bottom: -60,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _turquesa.withOpacity(0.10),
                          width: 18,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.format_quote_rounded,
                          color: _turquesa,
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
                          fondo: Colors.white.withOpacity(0.18),
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
            colores: _botonPrincipal,
            icono: Icons.check_rounded,
            onTap: () => _animarSalida(
              practica['id'].toString(),
              () => practicaloProvider.responderInvitacion(
                token: token,
                practicaloId: practica['id'],
                response: 'yes_today',
              ),
            ),
          ),
          const SizedBox(height: 8),
          _botonBorde(
            texto: 'No, gracias',
            color: _rojo,
            onTap: () => _animarSalida(
              practica['id'].toString(),
              () => practicaloProvider.responderInvitacion(
                token: token,
                practicaloId: practica['id'],
                response: 'no_thanks',
              ),
            ),
          ),
        ],
      );
    } else if (practica['status'] == 'completed' &&
        practica['star_rating'] == null) {
      acciones = _botonGradiente(
        texto: 'Calificar práctica',
        colores: _botonPrincipal,
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
          _textoRespuesta(response), _indigo, Icons.event_available_rounded);
    }

    return _tarjetaBase(
      acento: _turquesa,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(senderName, const [_turquesa, _turquesaOscuro]),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DE',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _turquesaOscuro,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _indigo,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _burbuja(mensaje, _turquesa),
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
        colores: _botonPrincipal,
        icono: Icons.task_alt_rounded,
        onTap: () => _animarSalida(
          practica['id'].toString(),
          () => practicaloProvider.confirmarReunion(
            token: token,
            practicaloId: practica['id'],
          ),
        ),
      );
    } else if (response == 'no_thanks') {
      acciones = _estadoBarra('Práctica anulada', _rojo, Icons.block_rounded);
    } else if (status == 'completed' && practica['star_rating'] == null) {
      acciones = _estadoBarra(
          'Esperando calificación', _morado, Icons.hourglass_top_rounded);
    } else if (status == 'completed' && practica['star_rating'] != null) {
      acciones = _estadoBarra(
          'Práctica completada', _verde[1], Icons.verified_rounded);
    } else {
      acciones =
          _estadoBarra('Esperando respuesta', _indigo, Icons.schedule_rounded);
    }

    return _tarjetaBase(
      acento: _indigo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(recipientName, const [_indigo, _indigoClaro]),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PARA',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _turquesaOscuro,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      recipientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _indigo,
                      ),
                    ),
                  ],
                ),
              ),
              _chip(
                _textoStatus(status),
                fondo: Colors.white,
                colorTexto: _indigo,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _burbuja(practica['message'] ?? 'Sin mensaje', _indigo),
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
              backgroundColor: Colors.white,
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
                        gradient: _degradadoPastel,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: _turquesa.withOpacity(0.35)),
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
                        color: _indigo,
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
                                  ? _dorado
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
                        color: estrellas > 0 ? _turquesaOscuro : _textoSuave,
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
                                side: BorderSide(
                                    color: _indigo.withOpacity(0.15)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
                                  color: _turquesa,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
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
