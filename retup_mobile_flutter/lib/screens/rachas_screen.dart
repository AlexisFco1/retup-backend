// rachas_screen.dart - COMPLETO CON BOTONES DE INCENTIVOS

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/racha_provider.dart';
import '../providers/reto_provider.dart';
import '../widgets/custom_bottom_navigation_bar.dart';

class RachasScreen extends StatefulWidget {
  const RachasScreen({Key? key}) : super(key: key);

  @override
  State<RachasScreen> createState() => _RachasScreenState();
}

class _RachasScreenState extends State<RachasScreen> {
  int _currentNavIndex = 2; // Rachas es el índice 2

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    print('🔍 DEBUG _cargarDatos en rachas_screen (NEW ARCHITECTURE)');

    final authProvider = context.read<AuthProvider>();
    final retoProvider = context.read<RetoProvider>();
    final rachaProvider = context.read<RachaProvider>();

    print('  userId: ${authProvider.userId}');
    print('  token: ${authProvider.token != null ? "✓ existe" : "✗ null"}');

    if (authProvider.userId != null && authProvider.token != null) {
      // Obtener todos los retos
      final retos = retoProvider.retos;
      print('  retos disponibles: ${retos.length}');

      if (retos.isNotEmpty) {
        // Extraer lista de IDs de retos
        final retoIds = retos.map((retoLocal) => retoLocal.reto.id).toList();

        print('✅ Cargando estadísticas para ${retoIds.length} retos...');

        // Cargar estadísticas para todos los retos
        await rachaProvider.cargarEstadisticasMultipleRetos(
          authProvider.userId!,
          retoIds,
          authProvider.token!,
        );

        // Cargar leaderboard
        print('✅ Cargando leaderboard...');
        await rachaProvider.cargarLeaderboard(authProvider.token!);

        // Cargar progreso diario para cada reto
        print('✅ Cargando progreso diario...');
        for (var retoLocal in retos) {
          await rachaProvider.cargarProgresoDiario(
            authProvider.userId!,
            retoLocal.reto.id,
            authProvider.token!,
          );
        }

        // Cargar preferencias de regalo para cada reto
        print('✅ Cargando preferencias de regalo...');
        for (var retoLocal in retos) {
          await rachaProvider.cargarPreferenciaRegalo(
            authProvider.userId!,
            retoLocal.reto.id,
            authProvider.token!,
          );
        }

        print('✅ Datos cargados completamente');
      } else {
        print('❌ No hay retos disponibles');
      }
    } else {
      print('❌ Falta usuario o token');
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
      appBar: AppBar(
        title: const Text('Rachas por Reto'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: Consumer3<RachaProvider, RetoProvider, AuthProvider>(
        builder: (context, rachaProvider, retoProvider, authProvider, _) {
          if (rachaProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (rachaProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${rachaProvider.errorMessage}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _cargarDatos,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final retos = retoProvider.retos;

          if (retos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey[400],
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay retos disponibles',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _cargarDatos,
            child: ListView(
              children: [
                // ===== SECCIÓN DE RETOS Y SUS ESTADÍSTICAS =====
                ...retos.map((retoLocal) {
                  final stats =
                      rachaProvider.obtenerStatsReto(retoLocal.reto.id);

                  return _buildRetoSection(
                    retoLocal: retoLocal,
                    stats: stats,
                    rachaProvider: rachaProvider,
                    authProvider: authProvider,
                  );
                }).toList(),

                const SizedBox(height: 32),

                // ===== SECCIÓN DE LEADERBOARD =====
                _buildLeaderboardSection(rachaProvider),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
      ),
    );
  }

  // ===== WIDGET PARA SECCIÓN DE RETO =====
  Widget _buildRetoSection({
    required RetoLocal retoLocal,
    required Map<String, dynamic>? stats,
    required RachaProvider rachaProvider,
    required AuthProvider authProvider,
  }) {
    // Default values si no hay datos
    final diaPildora = stats?['dia_pildora'] ?? 0; // ✅ correcto
    final cumplidos = stats?['dias_cumplidos'] ?? 0; // ✅ correcto
    final racha =
        stats?['racha_maxima'] ?? 0; // ✅ CAMBIO: racha_maxima, no racha_actual
    final noCumplidos = stats?['dias_no_cumplidos'] ?? 0; // ✅ correcto

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título del reto
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.purple],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  retoLocal.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    retoLocal.reto.title ?? 'Reto sin nombre',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Grid de 4 tarjetas de estadísticas
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard(
                title: 'Dia Pildora Planificada L-V',
                value: '$diaPildora/20',
                icon: Icons.calendar_today,
                color: Colors.blue,
              ),
              _buildStatCard(
                title: 'Pildoras cumplidas L-D',
                value: cumplidos.toString(),
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              _buildStatCard(
                title: 'Racha L-V',
                value: racha.toString(),
                icon: Icons.local_fire_department,
                color: Colors.orange,
              ),
              _buildStatCard(
                title: 'Dias no cumplidos L-V',
                value: noCumplidos.toString(),
                icon: Icons.cancel,
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ===== WIDGET DE BOLITAS DE PROGRESO DIARIO =====
          _buildBolitasProgreso(
            retoLocal: retoLocal,
            rachaProvider: rachaProvider,
          ),
          const SizedBox(height: 24),

          // ===== WIDGET DE BOTONES DE INCENTIVOS =====
          _buildBotonesIncentivos(
            retoLocal: retoLocal,
            rachaProvider: rachaProvider,
            authProvider: authProvider,
          ),

          const SizedBox(height: 16),

          // Separador
          Divider(
            color: Colors.grey[300],
            thickness: 1,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ===== WIDGET PARA TARJETA DE ESTADÍSTICA =====
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ===== WIDGET PARA SECCIÓN DE LEADERBOARD =====
  Widget _buildLeaderboardSection(RachaProvider rachaProvider) {
    final leaderboardRacha = rachaProvider.obtenerLeaderboardRacha();
    final leaderboardDiasCumplidos =
        rachaProvider.obtenerLeaderboardDiasCumplidos();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          const Text(
            'Leaderboard',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),

          const SizedBox(height: 16),

          // ===== LEADERBOARD DE RACHA =====
          _buildLeaderboardCard(
            title: '🔥 Por Mayor Racha',
            leaderboard: leaderboardRacha,
            valueKey: 'mejor_racha',
            subtitleKey: 'full_name',
          ),

          const SizedBox(height: 16),

          // ===== LEADERBOARD DE DÍAS CUMPLIDOS =====
          _buildLeaderboardCard(
            title: '✅ Por Pildoras Cumplidos',
            leaderboard: leaderboardDiasCumplidos,
            valueKey: 'dias_cumplidos_total',
            subtitleKey: 'full_name',
          ),
        ],
      ),
    );
  }

  // ===== WIDGET PARA TARJETA DE LEADERBOARD =====
  Widget _buildLeaderboardCard({
    required String title,
    required List<dynamic> leaderboard,
    required String valueKey,
    required String subtitleKey,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ),

          // Lista de usuarios
          if (leaderboard.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Sin datos',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leaderboard.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.grey[200],
                height: 1,
              ),
              itemBuilder: (context, index) {
                final item = leaderboard[index];
                final position = index + 1;
                final value = item[valueKey] ?? 0;
                final name = item[subtitleKey] ?? 'Usuario';

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      // Posición con medalla
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _getMedalColor(position),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          position.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Nombre del usuario
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Valor
                      Text(
                        value.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
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

  // ===== HELPER: Obtener color de medalla =====
  Color _getMedalColor(int position) {
    switch (position) {
      case 1:
        return Colors.amber; // Oro
      case 2:
        return Colors.grey[400]!; // Plata
      case 3:
        return Colors.orange[700]!; // Bronce
      default:
        return Colors.deepPurple; // Otros
    }
  }

  // ===== WIDGET PARA BOLITAS DE PROGRESO DIARIO =====
  Widget _buildBolitasProgreso({
    required RetoLocal retoLocal,
    required RachaProvider rachaProvider,
  }) {
    final progresoDiario =
        rachaProvider.obtenerProgresoDiario(retoLocal.reto.id);

    if (progresoDiario == null || progresoDiario.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calcular TODOS los dias laborables teoricos del mes (L-V)
    final hoy = DateTime.now();
    final mes = hoy.month;
    final ano = hoy.year;
    final ultimoDiaDelMes = DateTime(ano, mes + 1, 0).day;

    final diasLaborablesTeoricos = <DateTime>[];
    for (int day = 1; day <= ultimoDiaDelMes; day++) {
      final fecha = DateTime(ano, mes, day);
      if (fecha.weekday >= 1 && fecha.weekday <= 5) {
        // L-V
        diasLaborablesTeoricos.add(fecha);
      }
    }

    final totalDiasLaborables = diasLaborablesTeoricos.length;

    if (totalDiasLaborables == 0) {
      return const SizedBox.shrink();
    }

    // Crear mapa de datos del backend por fecha
    final datosMap = <String, Map<String, dynamic>>{};
    for (var registro in progresoDiario) {
      datosMap[registro['fecha']] = registro;
    }

    // Obtener hoy como string
    final hoyString = hoy.toIso8601String().split('T')[0];

    // Contar cuantos dias laborables han pasado hasta hoy (inclusive)
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

    // Crear lista de bolitas
    final bolitas = <Map<String, dynamic>>[];

    for (int i = 0; i < totalDiasLaborables; i++) {
      final numeroDelDia = i + 1; // 1, 2, 3, ..., 22
      final esDiaGracia = numeroDelDia > 20;
      final fechaStr =
          diasLaborablesTeoricos[i].toIso8601String().split('T')[0];
      final diaData = datosMap[fechaStr]; // Buscar en el mapa

      // Determinar color
      Color? color;

      if (esDiaGracia) {
        // Dias de gracia: siempre morado
        color = Colors.purple;
      } else if (numeroDelDia <= diaLaboralActual) {
        // Dia pasado: verde o rojo segun cumplimiento
        if (diaData != null) {
          final cumple = diaData['login_hecho'] == true &&
              diaData['pildora_completada'] == true;
          color = cumple ? Colors.green : Colors.red;
        } else {
          // Sin registro = no cumplio
          color = Colors.red;
        }
      } else {
        // Dia futuro: gris claro
        color = Colors.grey[300];
      }

      bolitas.add({
        'color': color,
        'fecha': fechaStr,
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Etiqueta
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Progreso diario ($totalDiasLaborables dias laborables - dia $diaLaboralActual)',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Grid de bolitas - ocupan todo el ancho disponible
        Row(
          children: bolitas.map((bolita) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: bolita['color'],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ===== WIDGET PARA BOTONES DE INCENTIVOS =====
  Widget _buildBotonesIncentivos({
    required RetoLocal retoLocal,
    required RachaProvider rachaProvider,
    required AuthProvider authProvider,
  }) {
    final regaloSeleccionado =
        rachaProvider.obtenerPreferenciaRegalo(retoLocal.reto.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pregunta
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            '¿Qué regalo prefieres para este reto?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),

        // Grid de 3 botones
        Row(
          children: [
            // Botón 1: Social
            Expanded(
              child: _buildBotoRegalo(
                emoji: '🍹',
                label: 'Social',
                tipoRegalo: 'social',
                estaSeleccionado: regaloSeleccionado == 'social',
                onTap: () => _seleccionarRegalo(
                  retoLocal.reto.id,
                  'social',
                  rachaProvider,
                  authProvider,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Botón 2: Restaurante
            Expanded(
              child: _buildBotoRegalo(
                emoji: '🍽️',
                label: 'Restaurante',
                tipoRegalo: 'restaurante',
                estaSeleccionado: regaloSeleccionado == 'restaurante',
                onTap: () => _seleccionarRegalo(
                  retoLocal.reto.id,
                  'restaurante',
                  rachaProvider,
                  authProvider,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Botón 3: Tarjeta de regalo
            Expanded(
              child: _buildBotoRegalo(
                emoji: '🎁',
                label: 'Tarjeta\nregalo',
                tipoRegalo: 'tarjeta',
                estaSeleccionado: regaloSeleccionado == 'tarjeta',
                onTap: () => _seleccionarRegalo(
                  retoLocal.reto.id,
                  'tarjeta',
                  rachaProvider,
                  authProvider,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===== WIDGET PARA UN BOTÓN DE REGALO =====
  Widget _buildBotoRegalo({
    required String emoji,
    required String label,
    required String tipoRegalo,
    required bool estaSeleccionado,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: estaSeleccionado ? Colors.deepPurple : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: estaSeleccionado ? Colors.deepPurple : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: estaSeleccionado
              ? [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: estaSeleccionado ? Colors.white : Colors.grey[700],
              ),
            ),
            if (estaSeleccionado)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===== MÉTODO PARA SELECCIONAR REGALO =====
  Future<void> _seleccionarRegalo(
    String retoId,
    String tipoRegalo,
    RachaProvider rachaProvider,
    AuthProvider authProvider,
  ) async {
    try {
      if (authProvider.userId != null && authProvider.token != null) {
        await rachaProvider.guardarPreferenciaRegalo(
          authProvider.userId!,
          retoId,
          tipoRegalo,
          authProvider.token!,
        );

        print('✅ Regalo seleccionado: $tipoRegalo para reto: $retoId');
      }
    } catch (e) {
      print('❌ Error al seleccionar regalo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar preferencia: $e')),
        );
      }
    }
  }
}
