import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/racha_provider.dart';
import '../widgets/custom_bottom_navigation_bar.dart';
import 'package:intl/intl.dart';

class RachasScreen extends StatefulWidget {
  const RachasScreen({Key? key}) : super(key: key);

  @override
  State<RachasScreen> createState() => _RachasScreenState();
}

class _RachasScreenState extends State<RachasScreen> {
  int _currentNavIndex = 2;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final authProvider = context.read<AuthProvider>();
    final rachaProvider = context.read<RachaProvider>();

    if (authProvider.userId != null) {
      await rachaProvider.cargarEstadisticas(
          authProvider.userId!, authProvider.token!); // ✅
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
        // Ya estamos en rachas
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
        title: const Text('Mis Rachas'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Consumer<RachaProvider>(
        builder: (context, rachaProvider, _) {
          if (rachaProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (rachaProvider.error != null) {
            return Center(
              child: Text('Error: ${rachaProvider.error}'),
            );
          }

          final ahora = DateTime.now();
          final diasLaborales =
              rachaProvider.obtenerDiasLaboralesMes(ahora.month, ahora.year);
          final progresoDiario = rachaProvider.progresoDiario;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título del mes
                Text(
                  '${DateFormat('MMMM', 'es_ES').format(ahora)} ${ahora.year}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 24),

                // Cards de estadísticas
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Día Píldora',
                        value: rachaProvider.diaPildora,
                        color: Colors.blue,
                        icon: Icons.calendar_today,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Racha',
                        value: rachaProvider.diasRacha,
                        color: Colors.orange,
                        icon: Icons.local_fire_department,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Cumplidos',
                        value: rachaProvider.diasCumplidos,
                        color: Colors.green,
                        icon: Icons.check_circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'No Cumplidos',
                        value: rachaProvider.diasNoCumplidos,
                        color: Colors.red,
                        icon: Icons.cancel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Título de círculos
                const Text(
                  'Progreso del Mes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),

                // Grid de círculos
                _buildCirclesGrid(diasLaborales, progresoDiario),

                const SizedBox(height: 32),

                // Leyenda
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Leyenda',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildLegendItem(
                        icon: '⭕',
                        text: 'Día que aún no llega',
                      ),
                      const SizedBox(height: 8),
                      _buildLegendItem(
                        icon: '✅',
                        text: 'Completó píldora',
                      ),
                      const SizedBox(height: 8),
                      _buildLegendItem(
                        icon: '❌',
                        text: 'No completó píldora',
                      ),
                    ],
                  ),
                ),
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

  Widget _buildStatCard({
    required String title,
    required int value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCirclesGrid(
    List<DateTime> diasLaborales,
    List<Map<String, dynamic>> progresoDiario,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(diasLaborales.length, (index) {
        final fechaDelDia = diasLaborales[index];

        // Verificar si ya pasó este día
        if (fechaDelDia.isAfter(DateTime.now())) {
          return _buildCircle(estado: 'vacio');
        }

        // Buscar el progreso de este día
        final fechaStr = DateFormat('yyyy-MM-dd').format(fechaDelDia);
        final diaProgreso = progresoDiario.firstWhere(
          (p) => p['fecha'] == fechaStr,
          orElse: () => {},
        );

        if (diaProgreso.isEmpty) {
          return _buildCircle(estado: 'incumplido');
        }

        final completado = diaProgreso['pildora_completada'] == true;
        return _buildCircle(
          estado: completado ? 'cumplido' : 'incumplido',
        );
      }),
    );
  }

  Widget _buildCircle({required String estado}) {
    Color color;
    String icon;

    switch (estado) {
      case 'cumplido':
        color = Colors.green;
        icon = '✅';
        break;
      case 'incumplido':
        color = Colors.red;
        icon = '❌';
        break;
      case 'vacio':
      default:
        color = Colors.grey[300]!;
        icon = '⭕';
        break;
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          icon,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  Widget _buildLegendItem({required String icon, required String text}) {
    return Row(
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  bool _esDialaboral(DateTime fecha) {
    return fecha.weekday >= 1 && fecha.weekday <= 5;
  }
}
