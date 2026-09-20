import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_bottom_navigation_bar.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../services/notification_service.dart';
import '../providers/practicalo_provider.dart';

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

      // Obtener notificaciones del usuario
      final notificaciones = await _notificationService.getAllNotifications(
        token: token,
        userId: userId,
      );

      print('✅ Notificaciones recibidas: ${notificaciones.length}');

      // Agrupar por mensaje - SOLO incluir notificaciones de prácticas (que tienen reto_id y pill_id)
      final Map<String, Map<String, dynamic>> agrupadas = {};

      for (var notif in notificaciones) {
        // Solo incluir notificaciones que tengan reto_id y pill_id (mensajes de prácticas enviadas)
        // Y EXCLUIR notificaciones de calificación que contienen la palabra "califi"
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

      // 🔔 Marcar automáticamente todas las notificaciones como leído
      // 🔔 Marcar automáticamente todas las notificaciones como leído
      // 🔔 Marcar automáticamente TODAS las notificaciones como leídas (BATCH)
// Incluyendo las de practicalo que contienen "invitación de práctica"
      try {
        final allNotificationIds = <String>[];

        // Agregar notificaciones de mensajes agrupadas
        allNotificationIds.addAll(
          agrupadas.values
              .expand((grupo) => grupo['notificationIds'] as List<String>)
              .toList(),
        );

        // Agregar TODAS las notificaciones de practicalo (incluyendo "invitación de práctica")
        for (var notif in notificaciones) {
          if (notif['reto_id'] != null && notif['pill_id'] != null) {
            allNotificationIds.add(notif['id']);
          }
        }

        // Eliminar duplicados
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

      // Resetear el contador en el NotificationProvider
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
        // Ya estamos en Practicalo
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
      appBar: AppBar(
        title: const Text('Practicalo'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : SingleChildScrollView(
                  child: Consumer<PracticaloProvider>(
                    builder: (context, practicaloProvider, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ========== SECCIÓN 1: MENSAJES DE EL MEJOR 🚀 ==========
                          if (_mensajesAgrupados.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Mensajes de el mejor 🚀',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 200,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                scrollDirection: Axis.horizontal,
                                itemCount: _mensajesAgrupados.length,
                                itemBuilder: (context, index) {
                                  final mensaje = _mensajesAgrupados[index];
                                  final message = mensaje['message'] as String;
                                  final senderCount =
                                      mensaje['senderCount'] as int;

                                  return Container(
                                    width: 280,
                                    margin: const EdgeInsets.only(right: 12),
                                    child: Card(
                                      margin: EdgeInsets.zero,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue[50]!,
                                              Colors.indigo[50]!,
                                            ],
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Mensaje
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.blue[200]!,
                                                ),
                                              ),
                                              child: Text(
                                                message,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontStyle: FontStyle.italic,
                                                  color: Colors.black87,
                                                  height: 1.6,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),

                                            // Contador de remitentes
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green[100],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.people,
                                                        size: 16,
                                                        color:
                                                            Colors.green[700],
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        '$senderCount ${senderCount == 1 ? 'compañero' : 'compañeros'}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Colors.green[700],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Spacer(),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // ========== SECCIÓN 2: PRÁCTICA RECIBIDA 📥 ==========
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Práctica Recibida 📥',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (practicaloProvider.practicaloRecibidas.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No hay prácticas recibidas aún',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 220,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                scrollDirection: Axis.horizontal,
                                itemCount: practicaloProvider
                                    .practicaloRecibidas.length,
                                itemBuilder: (context, index) {
                                  final practica = practicaloProvider
                                      .practicaloRecibidas[index];
                                  final senderName = practica['sender_user']
                                          ?['full_name'] ??
                                      practica['sender_user']?['email'] ??
                                      'Compañero';
                                  final mensaje =
                                      practica['message'] ?? 'Sin mensaje';
                                  final response = practica['response'];

                                  return Container(
                                    width: 280,
                                    margin: const EdgeInsets.only(right: 12),
                                    child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Nombre del remitente
                                            Text(
                                              'De: $senderName',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue,
                                              ),
                                            ),
                                            const SizedBox(height: 8),

                                            // Mensaje
                                            Text(
                                              mensaje,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontStyle: FontStyle.italic,
                                                color: Colors.black87,
                                                height: 1.4,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const Spacer(),

                                            // Botones de respuesta o calificación
                                            if (response == null)
                                              Column(
                                                children: [
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton(
                                                      onPressed: () async {
                                                        await practicaloProvider
                                                            .responderInvitacion(
                                                          token: token,
                                                          practicaloId:
                                                              practica['id'],
                                                          response: 'yes_today',
                                                        );
                                                      },
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.green,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          vertical: 8,
                                                        ),
                                                      ),
                                                      child: const Text(
                                                        'Sí, cuando puedas coordinamos',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton(
                                                      onPressed: () async {
                                                        await practicaloProvider
                                                            .responderInvitacion(
                                                          token: token,
                                                          practicaloId:
                                                              practica['id'],
                                                          response: 'no_thanks',
                                                        );
                                                      },
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          vertical: 8,
                                                        ),
                                                      ),
                                                      child: const Text(
                                                        'No, gracias',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            else if (practica['status'] ==
                                                    'completed' &&
                                                practica['star_rating'] == null)
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed: () async {
                                                    _mostrarCalificacion(
                                                      context,
                                                      practica['id'],
                                                      practica['sender_name'] ??
                                                          'Compañero',
                                                      practicaloProvider,
                                                      token,
                                                    );
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.orange,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      vertical: 8,
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Calificar',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            else if (practica['status'] ==
                                                    'completed' &&
                                                practica['star_rating'] != null)
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.star,
                                                    size: 16,
                                                    color: Colors.amber,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      'Calificaste con ${practica['star_rating']} ⭐',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.amber,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            else
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[100],
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  'Respondida: $response',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.blue[700],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                          const SizedBox(height: 24),

                          // ========== SECCIÓN 3: PRÁCTICA ENVIADA 📤 ==========
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Práctica Enviada 📤',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (practicaloProvider.practicaloEnviadas.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No hay prácticas enviadas aún',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 220,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                scrollDirection: Axis.horizontal,
                                itemCount: practicaloProvider
                                    .practicaloEnviadas.length,
                                itemBuilder: (context, index) {
                                  final practica = practicaloProvider
                                      .practicaloEnviadas[index];
                                  final recipientName =
                                      practica['recipient_user']
                                              ?['full_name'] ??
                                          practica['recipient_user']
                                              ?['email'] ??
                                          'Compañero';
                                  final response = practica['response'];
                                  final status = practica['status'];

                                  return Container(
                                    width: 280,
                                    margin: const EdgeInsets.only(right: 12),
                                    child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Nombre del destinatario
                                            Text(
                                              'Para: $recipientName',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.purple,
                                              ),
                                            ),
                                            const SizedBox(height: 8),

// Mensaje
                                            Text(
                                              practica['message'] ??
                                                  'Sin mensaje',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontStyle: FontStyle.italic,
                                                color: Colors.black87,
                                                height: 1.4,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),

// Estado
                                            Text(
                                              'Estado: $status',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            // Mostrar calificación recibida si existe
                                            if (practica['star_rating'] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.star,
                                                      size: 16,
                                                      color: Colors.amber,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        'Te calificaron con ${practica['star_rating']} ⭐',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.amber,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            const Spacer(),

                                            // Botones según estado
                                            if (response == 'yes_today' &&
                                                status != 'completed')
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed: () async {
                                                    await practicaloProvider
                                                        .confirmarReunion(
                                                      token: token,
                                                      practicaloId:
                                                          practica['id'],
                                                    );
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.blue,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      vertical: 8,
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Confirmar práctica realizada',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            else if (response == 'no_thanks')
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red[100],
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  'Práctica anulada',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.red[700],
                                                  ),
                                                ),
                                              )
                                            else if (status == 'completed' &&
                                                practica['star_rating'] == null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange[100],
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  'Esperando calificación',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.orange[700],
                                                  ),
                                                ),
                                              )
                                            else if (status == 'completed' &&
                                                practica['star_rating'] != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green[100],
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  'Práctica completada',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.green[700],
                                                  ),
                                                ),
                                              )
                                            else
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  'Esperando respuesta',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                          const SizedBox(height: 32),
                        ],
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

  // Método para mostrar diálogo de calificación
  void _mostrarCalificacion(
    BuildContext context,
    String practicaloId,
    String recipientName,
    PracticaloProvider practicaloProvider,
    String token,
  ) {
    int estrellas = 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Calificar a $recipientName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('¿Cuántas estrellas?'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            estrellas = index + 1;
                          });
                        },
                        child: Icon(
                          Icons.star,
                          size: 32,
                          color: index < estrellas
                              ? Colors.yellow[700]
                              : Colors.grey,
                        ),
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () async {
                    if (estrellas > 0) {
                      await practicaloProvider.calificar(
                        token: token,
                        practicaloId: practicaloId,
                        starRating: estrellas,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Calificación guardada'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
