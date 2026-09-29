// pildoras_list_screen.dart - IDENTIDAD DE MARCA RETUP (armonía página web)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pildora_model.dart';
import '../models/reto_model.dart';
import '../providers/pildora_provider.dart';
import '../providers/auth_provider.dart';
import '../services/favoritos_service.dart';
import '../services/progress_service.dart';
import '../utils/colors.dart';
import 'pildora_detail_screen.dart';

class PillorasListScreen extends StatefulWidget {
  final Reto reto;

  const PillorasListScreen({
    Key? key,
    required this.reto,
  }) : super(key: key);

  @override
  State<PillorasListScreen> createState() => _PillorasListScreenState();
}

class _PillorasListScreenState extends State<PillorasListScreen> {
  final FavoritosService _favoritosService = FavoritosService();
  final ProgressService _progressService = ProgressService();
  Set<String> _favoritosIds = {};
  Set<String> _completadasIds = {};
  bool _isLoadingFavoritos = true;

  // ===== Colores de marca RetUp (Paleta "Vínculo") =====
  static const Color _indigo = Color(0xFF2E2A72); // Predomina
  static const Color _turquesa = Color(0xFF12B5A6); // Botones y acentos
  static const Color _morado = Color(0xFF7209B7); // Compromiso
  static const Color _tinta = Color(0xFF0E0F17); // Texto

  static const Color _fondo = Color(0xFFF5F5F2); // Blanco roto como la web
  static const Color _texto = _tinta;
  static const Color _textoSuave = Color(0xFF6B7280);

  // Paleta de las píldoras (misma que la pantalla de inicio)
  static const List<List<Color>> _paleta = [
    [Color(0xFF2E2A72), Color(0xFF443E9E)], // Índigo
    [Color(0xFF12B5A6), Color(0xFF0B8A7E)], // Turquesa
    [Color(0xFF7209B7), Color(0xFF5B0893)], // Morado
    [Color(0xFF2E2A72), Color(0xFF7209B7)], // Índigo → Morado
    [Color(0xFF12B5A6), Color(0xFF2E2A72)], // Turquesa → Índigo
    [Color(0xFF7209B7), Color(0xFF2E2A72)], // Morado → Índigo
  ];
  static const List<Color> _verde = [Color(0xFF10B981), Color(0xFF059669)];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<PildoraProvider>().cargarPildorasDelReto(widget.reto.id);
      _cargarFavoritos();
      _cargarCompletadas();
    });
  }

  Future<void> _cargarFavoritos() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;

    try {
      final favoritos = await _favoritosService.getFavoritos(userId);
      if (mounted) {
        setState(() {
          _favoritosIds = favoritos.toSet();
          _isLoadingFavoritos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFavoritos = false);
      }
    }
  }

  Future<void> _cargarCompletadas() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;

    try {
      final progresiones =
          await _progressService.getAllPillProgressForUser(userId);
      if (mounted) {
        setState(() {
          _completadasIds = progresiones
              .where((p) => p.isCompleted)
              .map((p) => p.pillId)
              .toSet();
        });
      }
    } catch (e) {
      print('Error cargando completadas: $e');
    }
  }

  Future<void> _toggleFavorito(String pillId) async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;

    final esFavorito = _favoritosIds.contains(pillId);

    setState(() {
      if (esFavorito) {
        _favoritosIds.remove(pillId);
      } else {
        _favoritosIds.add(pillId);
      }
    });

    bool success;
    if (esFavorito) {
      success = await _favoritosService.removeFavorito(userId, pillId);
    } else {
      success = await _favoritosService.addFavorito(userId, pillId);
    }

    if (!success && mounted) {
      setState(() {
        if (esFavorito) {
          _favoritosIds.add(pillId);
        } else {
          _favoritosIds.remove(pillId);
        }
      });
    }
  }

  Future<void> _abrirPildora(Pildora pildora, String userId) async {
    final provider = context.read<PildoraProvider>();
    await provider.seleccionarPildora(pildora, userId);
    if (!mounted) return;
    final isCompleted = _completadasIds.contains(pildora.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PildoraDetailScreen(
          pildora: pildora,
          retoTitle: widget.reto.title,
          retoId: widget.reto.id,
          isReadOnly: isCompleted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;

    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 64,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        ),
        title: Text(
          widget.reto.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Consumer<PildoraProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: _turquesa,
                ),
              );
            }

            if (provider.errorMessage != null) {
              return _buildMensajeCentro(
                '😕',
                'No pudimos cargar las píldoras',
                'Error: ${provider.errorMessage}',
              );
            }

            if (provider.pildoras.isEmpty) {
              return _buildMensajeCentro(
                '💊',
                'Aún no hay píldoras',
                'No hay píldoras disponibles para este reto',
              );
            }

            final pildoras = provider.pildoras;
            final completadas =
                pildoras.where((p) => _completadasIds.contains(p.id)).length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                _buildHeader(completadas, pildoras.length),
                const SizedBox(height: 20),
                for (int index = 0; index < pildoras.length; index++)
                  _buildPildoraCard(pildoras[index], index, userId),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===== CABECERA: etiqueta + título + progreso del reto =====
  Widget _buildHeader(int completadas, int total) {
    final double progreso = total > 0 ? completadas / total : 0.0;
    final descripcion = widget.reto.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _turquesa,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '💊 TUS PÍLDORAS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.reto.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _indigo,
          ),
        ),
        if (descripcion != null && descripcion.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            descripcion,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: _textoSuave),
          ),
        ],
        const SizedBox(height: 14),
        // Tarjeta de progreso
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _indigo.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$completadas de $total píldoras completadas',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _indigo,
                      ),
                    ),
                  ),
                  Text(
                    '${(progreso * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _turquesa,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Barra de progreso con degradado turquesa → morado (como la web)
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _indigo.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progreso,
                  heightFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_turquesa, _morado],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===== TARJETA FINA DE CADA PÍLDORA =====
  Widget _buildPildoraCard(Pildora pildora, int index, String? userId) {
    final esFavorito = _favoritosIds.contains(pildora.id);
    final estaCompletada = _completadasIds.contains(pildora.id);
    final colores = _paleta[index % _paleta.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: estaCompletada
                ? _verde[0].withOpacity(0.45)
                : const Color(0xFFE5E7EB),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _indigo.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: userId != null
                ? () {
                    _abrirPildora(pildora, userId);
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Número / check
                  _buildNumero(index, estaCompletada, colores),
                  const SizedBox(width: 12),

                  // Textos
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              'PÍLDORA ${index + 1}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: _turquesa,
                                letterSpacing: 1,
                              ),
                            ),
                            if (estaCompletada) ...[
                              const SizedBox(width: 6),
                              _buildChipCompletada(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          pildora.titulo ?? 'Sin título',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: estaCompletada ? _textoSuave : _indigo,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pildora.descripcion ?? 'Sin descripción',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: _textoSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Acción derecha
                  estaCompletada
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _toggleFavorito(pildora.id),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, animation) =>
                                      ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                                  child: Icon(
                                    esFavorito
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    key: ValueKey<bool>(esFavorito),
                                    color: esFavorito
                                        ? _morado
                                        : Colors.grey.shade400,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.visibility_outlined,
                                    size: 12, color: _textoSuave),
                                SizedBox(width: 3),
                                Text(
                                  'Solo lectura',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _textoSuave,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _turquesa.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: _turquesa,
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Círculo con el número (o check verde si está completada)
  Widget _buildNumero(int index, bool estaCompletada, List<Color> colores) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: estaCompletada ? _verde : colores,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: estaCompletada
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
          : Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
    );
  }

  // Chip verde "Completada"
  Widget _buildChipCompletada() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _verde[0].withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 11, color: _verde[0]),
          const SizedBox(width: 3),
          Text(
            'Completada',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: _verde[0],
            ),
          ),
        ],
      ),
    );
  }

  // Estados de error / vacío con el mismo estilo de tarjeta
  Widget _buildMensajeCentro(String emoji, String titulo, String texto) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _indigo.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                        fontSize: 13,
                        color: _textoSuave,
                        height: 1.4,
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
}
