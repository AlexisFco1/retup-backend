import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reto_provider.dart';
import '../providers/racha_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _loadRetosYRegistrarLogin();
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

        // Registrar login para CADA reto
        for (var retoLocal in retoProvider.retos) {
          try {
            await rachaProvider.registrarLogin(
              userId,
              retoLocal.reto.id, // ✅ Aquí está - retoLocal.reto.id
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
        child: Consumer<RetoProvider>(
          builder: (context, retoProvider, _) {
            // Calcular estadísticas
            int totalPildoras =
                retoProvider.retos.fold(0, (sum, r) => sum + r.totalPildoras);
            int pildorasCompletadas = retoProvider.retos
                .fold(0, (sum, r) => sum + r.pildorasCompletadas);
            double progresoGeneral =
                totalPildoras > 0 ? pildorasCompletadas / totalPildoras : 0;

            // Separar retos en progreso y nuevos
            final retosEnProgreso = retoProvider.retos
                .where((r) =>
                    r.pildorasCompletadas > 0 &&
                    r.pildorasCompletadas < r.totalPildoras)
                .toList();
            final retosNuevos = retoProvider.retos
                .where((r) => r.pildorasCompletadas == 0)
                .toList();
            final retosCompletados = retoProvider.retos
                .where((r) => r.pildorasCompletadas == r.totalPildoras)
                .toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER CON ESTADÍSTICAS
                  _buildProgressHeader(context, pildorasCompletadas,
                      totalPildoras, progresoGeneral),
                  const SizedBox(height: 24),

                  // WELCOME BANNER
                  _buildWelcomeBanner(context),
                  const SizedBox(height: 32),

                  // RETOS EN PROGRESO
                  if (retosEnProgreso.isNotEmpty) ...[
                    _buildSectionTitle(context, '📈 En Progreso'),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: retosEnProgreso.length,
                      itemBuilder: (context, index) {
                        return _buildRetoCard(context, retosEnProgreso[index],
                            isInProgress: true);
                      },
                    ),
                    const SizedBox(height: 32),
                  ],

                  // RETOS DISPONIBLES
                  if (retosNuevos.isNotEmpty) ...[
                    _buildSectionTitle(context, '🎯 Retos Disponibles'),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: retosNuevos.length,
                      itemBuilder: (context, index) {
                        return _buildRetoCard(context, retosNuevos[index]);
                      },
                    ),
                    const SizedBox(height: 32),
                  ],

                  // RETOS COMPLETADOS
                  if (retosCompletados.isNotEmpty) ...[
                    _buildSectionTitle(context, '✅ Completados'),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: retosCompletados.length,
                      itemBuilder: (context, index) {
                        return _buildRetoCard(context, retosCompletados[index],
                            isCompleted: true);
                      },
                    ),
                  ],
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

  // HEADER CON PROGRESO GENERAL
  Widget _buildProgressHeader(
      BuildContext context, int completadas, int total, double progreso) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryColor.withOpacity(0.15),
            AppColors.primaryColor.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // PROGRESS RING
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: progreso,
                  strokeWidth: 6,
                  backgroundColor: AppColors.primaryColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryColor.withOpacity(0.7),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(progreso * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  Text(
                    'Avance',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primaryColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 24),
          // ESTADÍSTICAS
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu progreso',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$completadas de $total píldoras',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primaryColor.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '🔥 Mantén la racha',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryColor.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // WELCOME BANNER
  Widget _buildWelcomeBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryColor.withOpacity(0.08),
            AppColors.primaryColor.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¡Hola! 👋',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Bienvenido a RetUp. Elige un reto para comenzar a desarrollar tus habilidades blandas.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.grey,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  // TÍTULO DE SECCIÓN
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.darkGrey,
          ),
    );
  }

  // TARJETA DE RETO
  Widget _buildRetoCard(BuildContext context, RetoLocal retoLocal,
      {bool isInProgress = false, bool isCompleted = false}) {
    return GestureDetector(
      onTap: () {
        context.read<RetoProvider>().seleccionarReto(retoLocal);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PillorasListScreen(
              reto: retoLocal.reto,
            ),
          ),
        );
      },
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isCompleted
                  ? [
                      AppColors.success.withOpacity(0.9),
                      AppColors.success.withOpacity(0.7),
                    ]
                  : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: isCompleted
                    ? AppColors.success.withOpacity(0.3)
                    : const Color(0xFF6366F1).withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    retoLocal.emoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      retoLocal.reto.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${retoLocal.pildorasCompletadas}/${retoLocal.totalPildoras}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: retoLocal.progreso,
                        minHeight: 6,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              if (isCompleted)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Text(
                      '✅',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
