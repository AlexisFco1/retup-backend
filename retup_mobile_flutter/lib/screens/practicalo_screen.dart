import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_bottom_navigation_bar.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../services/notification_service.dart';

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

      // Agrupar por mensaje
      final Map<String, Map<String, dynamic>> agrupadas = {};

      for (var notif in notificaciones) {
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
        agrupadas[key]!['notificationIds']
            .add(notif['id']); // Guardar IDs para marcar como leído
      }

      setState(() {
        _mensajesAgrupados = agrupadas.values.toList();
        _isLoading = false;
      });

      print('✅ Mensajes agrupados: ${_mensajesAgrupados.length}');

      // 🔔 Marcar automáticamente todas las notificaciones como leído
      // 🔔 Marcar automáticamente todas las notificaciones como leído
      // 🔔 Marcar automáticamente todas las notificaciones como leídas (BATCH)
      try {
        final allNotificationIds = agrupadas.values
            .expand((grupo) => grupo['notificationIds'] as List<String>)
            .toList();

        if (allNotificationIds.isNotEmpty) {
          await _notificationService.markAllAsRead(
            token: token,
            notificationIds: allNotificationIds,
          );
          print(
              '✅ Todas las notificaciones marcadas como leídas en una sola llamada');
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
              : _mensajesAgrupados.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay mensajes aún',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : Column(
                      children: [
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
                          height: 470,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _mensajesAgrupados.length,
                            itemBuilder: (context, index) {
                              final mensaje = _mensajesAgrupados[index];
                              final message = mensaje['message'] as String;
                              final senderCount = mensaje['senderCount'] as int;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
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
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green[100],
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.people,
                                                  size: 16,
                                                  color: Colors.green[700],
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '$senderCount ${senderCount == 1 ? 'compañero' : 'compañeros'}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.green[700],
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
                              );
                            },
                          ),
                        ),
                      ],
                    ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
