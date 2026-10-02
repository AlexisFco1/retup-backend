import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pildora_model.dart';
import '../models/seccion_model.dart';
import '../providers/pildora_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/racha_provider.dart';
import '../providers/practicalo_provider.dart';
import '../providers/social_provider.dart';
import '../services/secciones_service.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/feedback_service.dart';
import '../services/notification_service.dart';
import '../services/progress_service.dart';
import '../services/home_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../widgets/custom_bottom_navigation_bar.dart';

class PildoraDetailScreen extends StatefulWidget {
  final Pildora pildora;
  final String retoTitle;
  final String retoId;
  final bool isReadOnly;
  // true solo cuando se abre desde Inicio (píldora suelta):
  // se guarda en pildoras_sueltas y NO cuenta en Rachas ni rankings
  final bool esSuelta;

  const PildoraDetailScreen({
    Key? key,
    required this.pildora,
    required this.retoTitle,
    required this.retoId,
    this.isReadOnly = false,
    this.esSuelta = false,
  }) : super(key: key);

  @override
  State<PildoraDetailScreen> createState() => _PildoraDetailScreenState();
}

class _PildoraDetailScreenState extends State<PildoraDetailScreen> {
  // ═══════════════ PALETA (misma que home_screen) ═══════════════
  static const Color _fondo = Color(0xFFF6F7FB);
  static const Color _texto = Color(0xFF1F2937);
  static const Color _textoSuave = Color(0xFF6B7280);
  static const List<Color> _heroColores = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
  ];
  static const List<Color> _verde = [Color(0xFF10B981), Color(0xFF059669)];
  static const List<Color> _ambar = [Color(0xFFF59E0B), Color(0xFFD97706)];
  static const List<List<Color>> _gradientes = [
    [Color(0xFF6366F1), Color(0xFF4F46E5)], // Índigo
    [Color(0xFF8B5CF6), Color(0xFF7C3AED)], // Violeta
    [Color(0xFF14B8A6), Color(0xFF0D9488)], // Turquesa
    [Color(0xFFF59E0B), Color(0xFFD97706)], // Ámbar
    [Color(0xFFEC4899), Color(0xFFDB2777)], // Rosa
    [Color(0xFF3B82F6), Color(0xFF2563EB)], // Azul
  ];

  final SeccionesService _seccionesService = SeccionesService();
  final FeedbackService _feedbackService = FeedbackService();
  final NotificationService _notificationService = NotificationService();
  final ProgressService _progressService = ProgressService();
  final HomeService _homeService = HomeService(); // Píldoras sueltas
  final ScrollController _scrollController = ScrollController();
  List<Seccion> _secciones = [];
  int _seccionActual = 0;
  bool _isLoading = false;
  bool _isLoadingSecciones = true;
  String? _errorMessage;
  List<User> _usuarios = [];
  bool _isLoadingUsuarios = false;
  User? _usuarioSeleccionado;
  // Selección múltiple guardada POR SECCIÓN (3 y 7 no se mezclan)
  final Map<int, List<User>> _seleccionPorSeccion = {};
  // Usuarios ya votados POR SECCIÓN (para no duplicar inserts)
  final Map<int, Set<String>> _votadosPorSeccion = {};

  int get _numeroSeccionActual =>
      _secciones.isEmpty ? 0 : _secciones[_seccionActual].screenNumber;

  List<User> get _usuariosSeleccionados =>
      _seleccionPorSeccion[_numeroSeccionActual] ?? [];

  set _usuariosSeleccionados(List<User> lista) =>
      _seleccionPorSeccion[_numeroSeccionActual] = lista;

  Set<String> get _votadosSeccionActual =>
      _votadosPorSeccion.putIfAbsent(_numeroSeccionActual, () => <String>{});
  static const int _maxVotos = 10;
  int _selectorResetKey = 0; // Fuerza a refrescar el selector múltiple
  int _currentNavIndex =
      -1; // -1 indica que no estamos en una pantalla principal
  bool _isVoting = false;
  bool _votoEnviadoSeccion3 = false;
  bool _votoEnviadoSeccion7 = false;
  bool _retoEnviadoSeccion8 = false;
  // Compañeros a los que YA se envió el reto en la sección 8 (para no duplicar)
  final Set<String> _retadosSeccion8 = {};
  int? _selfAssessmentScore;
  bool _scoreGuardado = false;
  late bool _isReadOnly;
  bool _yaLaHizoSuelta =
      false; // Píldora suelta ya terminada (suelta o en su reto)

  // Sección 9: publicar en Social (opcional)
  final TextEditingController _socialController = TextEditingController();
  bool _publicandoSocial = false;
  bool _publicadoSocial = false;

  @override
  void initState() {
    super.initState();
    _isReadOnly = widget.isReadOnly;
    _cargarSecciones();
    // Primero usuarios y DESPUÉS mis envíos: para pre-seleccionar
    // a los compañeros votados hace falta tener la lista de usuarios
    _cargarUsuarios().then((_) => _cargarMisEnvios());
    _cargarSelfAssessmentScore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _socialController.dispose();
    super.dispose();
  }

  Future<void> _cargarSecciones() async {
    try {
      setState(() {
        _isLoadingSecciones = true;
        _errorMessage = null;
      });

      print('🔍 Iniciando carga de secciones...');
      final secciones =
          await _seccionesService.getByPildoraId(widget.pildora.id);

      print('✅ Secciones recibidas: ${secciones.length}');
      print(
          '🔍 Primera sección: ${secciones.isNotEmpty ? secciones[0].screenName : 'N/A'}');

      setState(() {
        _secciones = secciones;
        _seccionActual = 0;
        _isLoadingSecciones = false;
        print('📝 _secciones después de setState: ${_secciones.length}');
      });

      if (_secciones.isEmpty) {
        setState(() {
          _errorMessage = 'No hay secciones disponibles para esta píldora';
        });
        print('⚠️ Las secciones están vacías');
      } else {
        print('✅ Secciones cargadas correctamente');
      }
    } catch (e) {
      print('❌ ERROR COMPLETO: $e');
      print('📍 Stack trace: ${StackTrace.current}');
      setState(() {
        _errorMessage = 'Error al cargar las secciones: $e';
        _isLoadingSecciones = false;
      });
    }
  }

  Future<void> _cargarUsuarios() async {
    try {
      setState(() {
        _isLoadingUsuarios = true;
      });

      print('🔍 Iniciando carga de usuarios...');
      final usersService = UsersService();
      final usuarios = await usersService.getAll();

      print('✅ Usuarios recibidos: ${usuarios.length}');

      // Excluir al usuario con sesión activa (no puede votar por sí mismo)
      final miUserId = context.read<AuthProvider>().userId;
      final usuariosFiltrados = usuarios
          .where((u) => u.id.toString() != miUserId?.toString())
          .toList();

      print('🙈 Usuarios sin incluirme: ${usuariosFiltrados.length}');

      if (!mounted) return;
      setState(() {
        _usuarios = usuariosFiltrados;
        _isLoadingUsuarios = false;
      });
    } catch (e) {
      print('❌ ERROR al cargar usuarios: $e');
      setState(() {
        _isLoadingUsuarios = false;
      });
    }
  }

  /// Recupera lo que el usuario YA envió en esta píldora (votos 3 y 7, reto 8)
  /// para no volver a pedirlo al regresar a la píldora.
  Future<void> _cargarMisEnvios() async {
    if (_isReadOnly) return; // En modo lectura no se vota, no hace falta

    try {
      final token = context.read<AuthProvider>().token;
      if (token == null) return;

      final envios = await _feedbackService.getMisEnviosPildora(
        token: token,
        pillId: widget.pildora.id,
      );

      if (envios == null || !mounted) return;

      final votos = envios['votos'] ?? [];
      final retos = envios['retos'] ?? [];

      // Agrupar los ids votados por sección: {3: {id1, id2}, 7: {id3}}
      final Map<int, Set<String>> idsPorSeccion = {};
      for (final voto in votos) {
        final seccion = (voto['section_number'] as num?)?.toInt();
        final votadoId = voto['nominated_user_id']?.toString();
        if (seccion == null || votadoId == null) continue;
        idsPorSeccion.putIfAbsent(seccion, () => <String>{}).add(votadoId);
      }

      setState(() {
        idsPorSeccion.forEach((seccion, ids) {
          // Marcar como ya votados (evita reenviarlos)
          _votadosPorSeccion[seccion] = ids;
          // Mostrarlos seleccionados en el selector de esa sección
          _seleccionPorSeccion[seccion] =
              _usuarios.where((u) => ids.contains(u.id.toString())).toList();
        });

        if ((idsPorSeccion[3] ?? {}).isNotEmpty) _votoEnviadoSeccion3 = true;
        if ((idsPorSeccion[7] ?? {}).isNotEmpty) _votoEnviadoSeccion7 = true;
        // Sección 8: recordar a quién ya se retó y mostrarlo en el selector
        for (final reto in retos) {
          final retadoId = reto['recipient_user_id']?.toString();
          if (retadoId != null) _retadosSeccion8.add(retadoId);
        }
        if (_retadosSeccion8.isNotEmpty) {
          _retoEnviadoSeccion8 = true;
          final retados = _usuarios
              .where((u) => _retadosSeccion8.contains(u.id.toString()))
              .toList();
          _usuarioSeleccionado = retados.isNotEmpty ? retados.first : null;
        }

        _selectorResetKey++; // Refresca el selector múltiple con la selección recuperada
      });

      print('✅ Envíos recuperados → S3: ${_votoEnviadoSeccion3}, '
          'S7: ${_votoEnviadoSeccion7}, S8: ${_retoEnviadoSeccion8}');
    } catch (e) {
      print('❌ Error recuperando envíos previos: $e');
    }
  }

  Future<void> _cargarSelfAssessmentScore() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.userId;
      if (userId == null) return;

      // Píldora suelta: estado desde pildoras_sueltas (no toca user_pill_progress)
      if (widget.esSuelta) {
        final estado =
            await _homeService.obtenerEstadoSuelta(widget.pildora.id);
        if (!mounted) return;
        setState(() {
          if (estado.selfAssessmentScore != null) {
            _selfAssessmentScore = estado.selfAssessmentScore;
            _scoreGuardado = true;
          }
          if (estado.yaLaHizo) {
            _isReadOnly = true;
            _yaLaHizoSuelta = true;
          }
        });
        if (estado.yaLaHizo) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  '✅ Ya hiciste esta píldora. Puedes volver a leerla.'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final pillProgress =
          await _progressService.getPillProgress(userId, widget.pildora.id);
      if (pillProgress != null && pillProgress.selfAssessmentScore != null) {
        setState(() {
          _selfAssessmentScore = pillProgress.selfAssessmentScore;
          _scoreGuardado = true;
        });
      }
    } catch (e) {
      print('Error cargando self assessment score: $e');
    }
  }

  Future<void> _guardarSelfAssessmentScore(int score) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.userId;
      if (userId == null) return;

      bool success;
      if (widget.esSuelta) {
        // Píldora suelta → pildoras_sueltas (no cuenta en Rachas)
        await _homeService.guardarAutopercepcionSuelta(
            widget.pildora.id, score);
        success = true;
      } else {
        final pillProgress =
            await _progressService.getPillProgress(userId, widget.pildora.id);
        if (pillProgress == null) return;

        success = await _progressService.updateProgress(
          pillProgress.id,
          {'self_assesment_score': score},
        );
      }

      if (success && mounted) {
        setState(() {
          _scoreGuardado = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Autopercepción guardada'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error guardando self assessment score: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al guardar la autopercepción'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Widget _construirSelectorAutopercepcion(List<Color> colores) {
    final bool soloLectura = _isReadOnly;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.psychology_rounded,
                color: colores[0],
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Tu autopercepción',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colores[0],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '¿Cómo te evalúas en esta habilidad?',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final int valor = index + 1;
              final bool seleccionado = _selfAssessmentScore != null &&
                  _selfAssessmentScore! >= valor;

              return GestureDetector(
                onTap: soloLectura
                    ? null
                    : () {
                        setState(() {
                          _selfAssessmentScore = valor;
                          _scoreGuardado = false;
                        });
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: seleccionado
                        ? LinearGradient(
                            colors: colores,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: seleccionado ? null : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: seleccionado
                          ? colores[0].withOpacity(0.3)
                          : const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                    boxShadow: seleccionado
                        ? [
                            BoxShadow(
                              color: colores[0].withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      '$valor',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: seleccionado
                            ? Colors.white
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_selfAssessmentScore != null) ...[
            const SizedBox(height: 14),
            Text(
              _selfAssessmentScore == 1
                  ? 'Necesito mejorar mucho'
                  : _selfAssessmentScore == 2
                      ? 'Tengo oportunidades de mejora'
                      : _selfAssessmentScore == 3
                          ? 'Estoy en un nivel aceptable'
                          : _selfAssessmentScore == 4
                              ? 'Tengo buen dominio'
                              : 'Dominio excelente',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colores[0],
              ),
            ),
          ],
          if (!soloLectura &&
              _selfAssessmentScore != null &&
              !_scoreGuardado) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _guardarSelfAssessmentScore(_selfAssessmentScore!),
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text(
                  'Guardar autopercepción',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colores[0],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
          if (soloLectura && _selfAssessmentScore != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Guardado',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _subirAlInicio() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _irASiguiente() {
    // Validar que el voto fue enviado en la sección 3 o 7 (solo si NO es modo lectura)
    if (!_isReadOnly &&
        ((_secciones[_seccionActual].screenNumber == 3 &&
                !_votoEnviadoSeccion3) ||
            (_secciones[_seccionActual].screenNumber == 7 &&
                !_votoEnviadoSeccion7) ||
            (_secciones[_seccionActual].screenNumber == 8 &&
                !_retoEnviadoSeccion8) ||
            (_secciones[_seccionActual].screenNumber == 5 &&
                !_scoreGuardado))) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Acción requerida',
            style: TextStyle(fontWeight: FontWeight.w800, color: _texto),
          ),
          content: Text(
            _secciones[_seccionActual].screenNumber == 8
                ? 'Debes enviar el reto antes de continuar.'
                : _secciones[_seccionActual].screenNumber == 5
                    ? 'Debes guardar tu autopercepción antes de continuar.'
                    : 'Debes enviar tu voto antes de continuar.',
            style: const TextStyle(color: _textoSuave),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      return;
    }

    if (_seccionActual < _secciones.length - 1) {
      setState(() {
        _seccionActual++;
      });
      _subirAlInicio();
    }
  }

  void _irAlAnterior() {
    if (_seccionActual > 0) {
      setState(() {
        _seccionActual--;
      });
      _subirAlInicio();
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
        Navigator.pushReplacementNamed(context, '/practicalo');
        break;
      case 5:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  Future<Map<String, dynamic>?> _mostrarDialogoCalificacion() async {
    int _estrellas = 0;
    final TextEditingController _mensajeController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: _heroColores),
                    boxShadow: [
                      BoxShadow(
                        color: _heroColores[0].withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '¿Cómo calificas esta píldora?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _texto,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tu opinión nos ayuda a mejorar',
                  style: TextStyle(fontSize: 14, color: _textoSuave),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          _estrellas = index + 1;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < _estrellas
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: index < _estrellas
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFD1D5DB),
                          size: 40,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _mensajeController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Escribe un comentario (opcional)',
                    hintStyle: const TextStyle(
                      color: _textoSuave,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: _fondo,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: _heroColores[0],
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: _botonGradiente(
                    texto: 'Enviar y completar',
                    icono: Icons.check_circle_rounded,
                    colores: _verde,
                    onPressed: _estrellas == 0
                        ? null
                        : () {
                            Navigator.pop(context, {
                              'estrellas': _estrellas,
                              'mensaje': _mensajeController.text.trim(),
                            });
                          },
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      color: _textoSuave,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarAnimacionXP() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: anim1,
              curve: Curves.elasticOut,
            ),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding:
                      const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C853).withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD600), Color(0xFFFFA000)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD600).withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '+5',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFA000),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '¡Has ganado 5 pts de Asistencia!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF37474F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context); // Cierra la animación
        Navigator.pushReplacementNamed(context, '/'); // Va al Home
      }
    });
  }

  Future<void> _completarPildora() async {
    // Mostrar diálogo de calificación ANTES de completar
    final resultado = await _mostrarDialogoCalificacion();
    if (resultado == null) return; // El usuario canceló

    final int estrellas = resultado['estrellas'];
    final String mensaje = resultado['mensaje'];

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.userId;
      final token = authProvider.token;

      if (userId == null || token == null) {
        _showErrorDialog('Error', 'No hay usuario autenticado');
        return;
      }

      bool success;
      if (widget.esSuelta) {
        // Píldora suelta: se guarda en pildoras_sueltas.
        // NO usa PildoraProvider ni registra en Rachas → no afecta rankings
        await _homeService.completarSuelta(
          widget.pildora.id,
          pillRating: estrellas,
          pillFeedbackMessage: mensaje.isNotEmpty ? mensaje : null,
        );
        success = true;
      } else {
        // 1. Completar la píldora normalmente
        final pildoraProvider = context.read<PildoraProvider>();
        success = await pildoraProvider.completarPildora(
          pillRating: estrellas,
          pillFeedbackMessage: mensaje.isNotEmpty ? mensaje : null,
        );
      }

      if (success && mounted) {
        // 2. Registrar la píldora completada en Rachas (solo si NO es suelta)
        if (!widget.esSuelta) {
          final rachaProvider = context.read<RachaProvider>();
          await rachaProvider.registrarPildoraCompletada(
              userId, widget.retoId, token);
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: _verde),
                      boxShadow: [
                        BoxShadow(
                          color: _verde[0].withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '¡Felicidades!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _texto,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.esSuelta
                        ? '¡Has completado la píldora!\nGracias por tu calificación'
                        : '¡Has completado la píldora!\nContinúa así para subir en el ranking',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: _textoSuave,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: _botonGradiente(
                      texto: 'Aceptar',
                      icono: Icons.check_rounded,
                      colores: _verde,
                      onPressed: () {
                        Navigator.pop(
                            context); // Cierra el diálogo de Felicidades
                        if (widget.esSuelta) {
                          // Suelta: sin XP, vuelve a Inicio (que se recarga sola)
                          Navigator.pop(context);
                          return;
                        }
                        final now = DateTime.now();
                        final esEntresemana = now.weekday >= DateTime.monday &&
                            now.weekday <= DateTime.friday;
                        if (esEntresemana) {
                          _mostrarAnimacionXP();
                        } else {
                          Navigator.pushReplacementNamed(context, '/');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (mounted) {
        _showErrorDialog('Error', 'No se pudo guardar el progreso');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error', 'Ocurrió un error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registrarVoto(String voteType) async {
    if (_usuariosSeleccionados.isEmpty) {
      _mostrarSnack('Por favor selecciona al menos un usuario');
      return;
    }

    final votados = _votadosSeccionActual;

    // Solo votar por los que AÚN no tienen voto en esta sección
    final pendientes =
        _usuariosSeleccionados.where((u) => !votados.contains(u.id)).toList();

    if (pendientes.isEmpty) {
      _mostrarSnack('Ya enviaste tu voto por estos compañeros');
      return;
    }

    if (votados.length + pendientes.length > _maxVotos) {
      _mostrarSnack(
        'Solo puedes votar por $_maxVotos compañeros en esta sección (ya votaste por ${votados.length})',
        esError: true,
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    final respondentUserId = authProvider.userId;

    if (token == null || respondentUserId == null) {
      _mostrarSnack('Error: No hay sesión activa', esError: true);
      return;
    }

    setState(() => _isVoting = true);

    final List<MapEntry<User, String>> exitosos = [];
    final List<User> fallidos = [];

    try {
      // Un insert por cada usuario pendiente
      for (final usuario in pendientes) {
        try {
          final nominationId = await _feedbackService.registerFeedbackVote(
            token: token,
            respondentUserId: respondentUserId,
            nominatedUserId: usuario.id,
            retoId: widget.retoId,
            pillId: widget.pildora.id,
            sectionNumber: _numeroSeccionActual,
            voteType: voteType,
          );
          exitosos.add(MapEntry(usuario, nominationId.toString()));
          votados.add(usuario.id); // marcar como ya votado
        } catch (e) {
          print('❌ Error votando por ${usuario.fullName}: $e');
          fallidos.add(usuario);
        }
      }

      if (!mounted) return;

      if (exitosos.isEmpty) {
        _mostrarSnack('No se pudo registrar ningún voto. Intenta de nuevo.',
            esError: true);
        return;
      }

      if (fallidos.isEmpty) {
        _mostrarSnack(
          exitosos.length == 1
              ? '¡Voto registrado correctamente!'
              : '¡${exitosos.length} votos registrados correctamente!',
          esExito: true,
        );
      } else {
        _mostrarSnack(
          'Se registraron ${exitosos.length} votos. Fallaron ${fallidos.length}, pulsa "Enviar voto" para reintentar.',
          esError: true,
        );
      }

      // La selección NO se borra: se mantiene tal cual
      setState(() {
        if (voteType == 'positive') {
          _votoEnviadoSeccion3 = true;
        } else if (voteType == 'negative') {
          _votoEnviadoSeccion7 = true;
        }
      });

      // Pop-up OPCIONAL de mensaje anónimo (solo sección 3)
      if (mounted && voteType == 'positive') {
        _mostrarDialogoMensajeAnonimo(exitosos, token, respondentUserId);
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  void _mostrarSnack(String mensaje,
      {bool esExito = false, bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              esExito
                  ? Icons.check_circle_rounded
                  : esError
                      ? Icons.error_rounded
                      : Icons.info_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: esExito
            ? _verde[0]
            : esError
                ? const Color(0xFFEF4444)
                : _texto,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, color: _texto),
        ),
        content: Text(message, style: const TextStyle(color: _textoSuave)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, color: _texto),
        ),
        content: Text(message, style: const TextStyle(color: _textoSuave)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoMensajeAnonimo(
    List<MapEntry<User, String>> nominaciones,
    String token,
    String respondentUserId,
  ) {
    final mensaje = 'Valoro tu habilidad de ${widget.pildora.titulo}';

    // Guardamos los nominationId marcados. Si solo votó por uno, viene marcado.
    final Set<String> elegidos =
        nominaciones.length == 1 ? {nominaciones.first.value} : <String>{};

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final todosMarcados = elegidos.length == nominaciones.length;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: _heroColores),
                        boxShadow: [
                          BoxShadow(
                            color: _heroColores[0].withOpacity(0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Mensaje anónimo',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: _texto,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _heroColores[0].withOpacity(0.07),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _heroColores[0].withOpacity(0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TU MENSAJE SERÁ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: _heroColores[0],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '“$mensaje”',
                            style: const TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                              color: _texto,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ===== ¿A quién se lo envías? =====
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '¿A quién de los seleccionados quisieras enviarle este mensaje?',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _texto,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        color: _fondo,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: [
                          // Opción "Seleccionar todos" (solo si hay más de 1)
                          if (nominaciones.length > 1) ...[
                            _filaCheck(
                              texto: 'Seleccionar todos',
                              marcado: todosMarcados,
                              negrita: true,
                              onTap: () {
                                setDialogState(() {
                                  if (todosMarcados) {
                                    elegidos.clear();
                                  } else {
                                    elegidos.addAll(
                                        nominaciones.map((n) => n.value));
                                  }
                                });
                              },
                            ),
                            const Divider(
                              height: 1,
                              color: Color(0xFFE5E7EB),
                            ),
                          ],
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: SingleChildScrollView(
                              child: Column(
                                children: nominaciones.map((n) {
                                  final marcado = elegidos.contains(n.value);
                                  return _filaCheck(
                                    texto: n.key.fullName,
                                    marcado: marcado,
                                    onTap: () {
                                      setDialogState(() {
                                        marcado
                                            ? elegidos.remove(n.value)
                                            : elegidos.add(n.value);
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: _botonGradiente(
                        texto: 'Enviar voto con mensaje anónimo',
                        icono: Icons.send_rounded,
                        colores: _verde,
                        onPressed: elegidos.isEmpty
                            ? null
                            : () async {
                                final seleccion = nominaciones
                                    .where((n) => elegidos.contains(n.value))
                                    .toList();
                                Navigator.pop(dialogContext);
                                await _enviarMensajesAnonimos(
                                  seleccion,
                                  mensaje,
                                  token,
                                  respondentUserId,
                                );
                              },
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text(
                        'Enviar voto sin mensaje anónimo',
                        style: TextStyle(
                          color: _textoSuave,
                          fontWeight: FontWeight.w600,
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
    );
  }

  // Fila con casilla para el pop-up de mensaje anónimo
  Widget _filaCheck({
    required String texto,
    required bool marcado,
    required VoidCallback onTap,
    bool negrita = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: marcado,
              onChanged: (_) => onTap(),
              activeColor: _heroColores[0],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
            ),
            Expanded(
              child: Text(
                texto,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  color: negrita ? _heroColores[0] : _texto,
                  fontWeight: negrita ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enviarMensajeAnonimo(
    String nominationId,
    String mensaje,
    String token,
    String respondentUserId,
    String destinatarioUserId,
  ) async {
    try {
      setState(() => _isVoting = true);

      await _feedbackService.updateNominationWithMessage(
        token: token,
        nominationId: nominationId,
        message: mensaje,
      );
      // Crear notificación para el usuario que recibe el mensaje
      await _notificationService.createNotification(
        recipientUserId: destinatarioUserId,
        senderUserId: respondentUserId,
        type: 'anonymous_message',
        message: mensaje,
        token: token,
        retoId: widget.retoId,
        pillId: widget.pildora.id,
      );

      if (mounted) {
        _mostrarSnack('¡Mensaje anónimo enviado!', esExito: true);
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnack('Error al enviar mensaje: $e', esError: true);
      }
    } finally {
      setState(() => _isVoting = false);
    }
  }

  Future<void> _enviarMensajesAnonimos(
    List<MapEntry<User, String>> nominaciones,
    String mensaje,
    String token,
    String respondentUserId,
  ) async {
    setState(() => _isVoting = true);
    int enviados = 0;

    try {
      for (final nominacion in nominaciones) {
        try {
          // Guarda el mensaje en la nominación de ESE usuario
          await _feedbackService.updateNominationWithMessage(
            token: token,
            nominationId: nominacion.value,
            message: mensaje,
          );
          // Notificación solo para ESE usuario
          await _notificationService.createNotification(
            recipientUserId: nominacion.key.id,
            senderUserId: respondentUserId,
            type: 'anonymous_message',
            message: mensaje,
            token: token,
            retoId: widget.retoId,
            pillId: widget.pildora.id,
          );
          enviados++;
        } catch (e) {
          print('❌ Error enviando mensaje a ${nominacion.key.fullName}: $e');
        }
      }

      if (!mounted) return;

      if (enviados == nominaciones.length) {
        _mostrarSnack(
          enviados == 1
              ? '¡Mensaje anónimo enviado!'
              : '¡$enviados mensajes anónimos enviados!',
          esExito: true,
        );
      } else if (enviados == 0) {
        _mostrarSnack('No se pudo enviar el mensaje', esError: true);
      } else {
        _mostrarSnack(
          'Se enviaron $enviados de ${nominaciones.length} mensajes',
          esError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }
  // ═══════════════════════════════════════════════════════════
  //  HELPERS VISUALES
  // ═══════════════════════════════════════════════════════════

  List<Color> get _coloresSeccion =>
      _gradientes[_seccionActual % _gradientes.length];

  _TemaSeccion _temaSeccion(Seccion s) {
    final nombre = s.screenName.toLowerCase();
    if (s.screenType == 'anonymous_question' ||
        nombre.contains('anónim') ||
        nombre.contains('anonim')) {
      return const _TemaSeccion(Icons.how_to_vote_rounded, 'PREGUNTA ANÓNIMA');
    }
    if (nombre.contains('bienvenid')) {
      return const _TemaSeccion(Icons.waving_hand_rounded, 'BIENVENIDA');
    }
    if (nombre.contains('reto') || nombre.contains('desaf')) {
      return const _TemaSeccion(Icons.emoji_events_rounded, 'RETO');
    }
    if (nombre.contains('pregunta') ||
        nombre.contains('quiz') ||
        nombre.contains('test')) {
      return const _TemaSeccion(Icons.quiz_rounded, 'PONTE A PRUEBA');
    }
    if (nombre.contains('tip') ||
        nombre.contains('consejo') ||
        nombre.contains('clave')) {
      return const _TemaSeccion(Icons.tips_and_updates_rounded, 'TIP CLAVE');
    }
    if (nombre.contains('ejemplo') || nombre.contains('caso')) {
      return const _TemaSeccion(Icons.work_outline_rounded, 'EJEMPLO REAL');
    }
    if (nombre.contains('resumen') || nombre.contains('cierre')) {
      return const _TemaSeccion(Icons.flag_rounded, 'CIERRE');
    }
    return const _TemaSeccion(Icons.auto_stories_rounded, 'APRENDE');
  }

  Widget _circuloDecorativo(double tamano, double opacidad) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacidad),
      ),
    );
  }

  Widget _botonGradiente({
    required String texto,
    required IconData icono,
    required List<Color> colores,
    required VoidCallback? onPressed,
    bool cargando = false,
    bool iconoAlFinal = false,
  }) {
    final activo = onPressed != null && !cargando;
    final iconoWidget = Icon(icono, color: Colors.white, size: 20);
    final textoWidget = Flexible(
      child: Text(
        texto,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return Opacity(
      opacity: (onPressed == null && !cargando) ? 0.5 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colores,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colores[0].withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: activo ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: cargando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: iconoAlFinal
                            ? [
                                textoWidget,
                                const SizedBox(width: 8),
                                iconoWidget
                              ]
                            : [
                                iconoWidget,
                                const SizedBox(width: 8),
                                textoWidget
                              ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── HERO: título de la píldora + progreso por segmentos ──
  Widget _construirHero() {
    final total = _secciones.length;
    final porcentaje = ((_seccionActual + 1) / total * 100).round();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: _heroColores,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _heroColores[0].withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(
                top: -45, right: -35, child: _circuloDecorativo(150, 0.12)),
            Positioned(
                bottom: -55, left: -25, child: _circuloDecorativo(120, 0.08)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'PÍLDORA DE APRENDIZAJE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.lightbulb_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.pildora.titulo ?? 'Sin título',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        'Sección ${_seccionActual + 1} de $total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$porcentaje% completado',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(total, (i) {
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 7,
                          margin:
                              EdgeInsets.only(right: i == total - 1 ? 0 : 4),
                          decoration: BoxDecoration(
                            color: i <= _seccionActual
                                ? Colors.white
                                : Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Contenido: separa líneas y resalta las frases entre comillas ──
  bool _esCita(String linea) =>
      linea.startsWith('"') || linea.startsWith('“') || linea.startsWith('«');

  Widget _construirTextoContenido(String contenido, List<Color> colores) {
    final lineas = contenido
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < lineas.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          if (_esCita(lineas[i]))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colores[0].withOpacity(0.10),
                    colores[1].withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border(
                  left: BorderSide(color: colores[0], width: 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    color: colores[0].withOpacity(0.6),
                    size: 30,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lineas[i],
                    style: const TextStyle(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                      color: _texto,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            )
          else if (i == 0 && lineas.length > 1 && lineas[i].length <= 45)
            Text(
              lineas[i],
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: colores[1],
                height: 1.4,
              ),
            )
          else
            Text(
              lineas[i],
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF374151),
                height: 1.65,
              ),
            ),
        ],
      ],
    );
  }

  // ── Tarjeta principal de la sección ──
  /// Sección 9: tarjeta opcional para publicar un mensaje en Social
  Widget _construirPublicarSocial(List<Color> colores) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colores[0].withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colores[0].withOpacity(0.18),
                      colores[1].withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.forum_rounded, color: colores[0], size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Quieres subir un mensaje a Social?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _texto,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Opcional. Con la información que aprendiste hoy, ¿qué mensaje le darías a tu equipo?',
                      style: TextStyle(fontSize: 12.5, color: _textoSuave),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_publicadoSocial)
            // Estado: ya publicado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _verde[0].withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _verde[0].withOpacity(0.30)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: _verde[1], size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¡Publicado en Social!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _verde[1],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            TextField(
              controller: _socialController,
              maxLines: 4,
              minLines: 3,
              maxLength: 500,
              enabled: !_publicandoSocial,
              cursorColor: colores[0],
              decoration: InputDecoration(
                hintText: 'Escribe aquí tu mensaje para el equipo...',
                hintStyle: const TextStyle(color: _textoSuave, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF6F7FB),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colores[0], width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _botonGradiente(
              texto: 'Publicar en Social',
              icono: Icons.send_rounded,
              colores: colores,
              cargando: _publicandoSocial,
              onPressed: _publicandoSocial ? null : _publicarEnSocial,
            ),
          ],
        ],
      ),
    );
  }

  /// Publica el texto escrito en la sección 9 como post de Social
  Future<void> _publicarEnSocial() async {
    final texto = _socialController.text.trim();
    if (texto.isEmpty) {
      _mostrarSnack('Escribe un mensaje antes de publicar');
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null) {
      _mostrarSnack('No hay usuario autenticado', esError: true);
      return;
    }

    FocusScope.of(context).unfocus(); // Cierra el teclado
    setState(() => _publicandoSocial = true);

    try {
      final ok =
          await context.read<SocialProvider>().createTextPost(texto, token);
      if (!mounted) return;

      if (ok) {
        setState(() {
          _publicadoSocial = true;
          _socialController.clear();
        });
        _mostrarSnack('¡Publicado en Social! 🎉', esExito: true);
      } else {
        _mostrarSnack('No se pudo publicar. Intenta de nuevo', esError: true);
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnack('No se pudo publicar. Intenta de nuevo', esError: true);
      }
    } finally {
      if (mounted) setState(() => _publicandoSocial = false);
    }
  }

  Widget _construirTarjetaSeccion(Seccion seccion, List<Color> colores) {
    final tema = _temaSeccion(seccion);
    final esAnonima = seccion.screenType == 'anonymous_question';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera de la tarjeta
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colores,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: colores[0].withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(tema.icono, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tema.etiqueta,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: colores[0],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        seccion.screenName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: _texto,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: const Color(0xFFF1F2F6),
          ),
          // Cuerpo de la tarjeta
          Padding(
            padding: const EdgeInsets.all(20),
            child: esAnonima
                ? _construirContenidoAnonimo(seccion, colores)
                : _construirTextoContenido(seccion.screenContent, colores),
          ),
        ],
      ),
    );
  }

  Widget _construirContenidoAnonimo(Seccion seccion, List<Color> colores) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _construirTextoContenido(seccion.screenContent, colores),
        const SizedBox(height: 18),
        const Text(
          'Selecciona un usuario:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _texto,
          ),
        ),
        const SizedBox(height: 10),
        _isLoadingUsuarios
            ? Center(
                child: CircularProgressIndicator(
                  color: colores[0],
                  strokeWidth: 2.5,
                ),
              )
            : _usuarios.isEmpty
                ? const Text(
                    'No hay usuarios disponibles',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _fondo,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: DropdownButton<User>(
                      value: _usuarioSeleccionado,
                      isExpanded: true,
                      underline: const SizedBox(),
                      borderRadius: BorderRadius.circular(16),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _textoSuave,
                      ),
                      items: _usuarios.map((user) {
                        return DropdownMenuItem<User>(
                          value: user,
                          child: Text(
                            user.fullName,
                            style: const TextStyle(
                              color: _texto,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (User? newValue) {
                        setState(() {
                          _usuarioSeleccionado = newValue;
                        });
                      },
                    ),
                  ),
      ],
    );
  }

  // ── Nota / fuente ──
  Widget _construirNota(String nota) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: _ambar),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PARA SABER MÁS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nota,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF92400E),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Selector de usuario + botón de voto / reto (secciones 3, 7 y 8) ──
  Widget _construirSelectorUsuario(Seccion seccion, List<Color> colores) {
    final esReto = seccion.screenNumber == 8;
    final colorAcento = esReto ? _ambar : colores;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorAcento[0].withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  esReto ? Icons.sports_score_rounded : Icons.groups_rounded,
                  color: colorAcento[0],
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      esReto
                          ? 'Selecciona un usuario de la empresa'
                          : seccion.screenNumber == 3
                              ? 'Selecciona a los mejores'
                              : 'Selecciona compañeros de la empresa',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _texto,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Busca a tu compañero por su nombre',
                      style: TextStyle(fontSize: 12, color: _textoSuave),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoadingUsuarios
              ? Center(
                  child: CircularProgressIndicator(
                    color: colorAcento[0],
                    strokeWidth: 2.5,
                  ),
                )
              : _usuarios.isEmpty
                  ? const Text(
                      'No hay usuarios disponibles',
                      style: TextStyle(color: Color(0xFFEF4444)),
                    )
                  : esReto
                      // ===== SECCIÓN 8: selección de UN usuario =====
                      ? DropdownSearch<User>(
                          items: _usuarios,
                          itemAsString: (user) => user.fullName,
                          onChanged: (User? value) {
                            setState(() {
                              _usuarioSeleccionado = value;
                            });
                          },
                          selectedItem: _usuarioSeleccionado,
                          popupProps: PopupProps.menu(
                            showSearchBox: true,
                            searchFieldProps: TextFieldProps(
                              cursorColor: colorAcento[0],
                              decoration: _decoracionBuscador(),
                            ),
                            fit: FlexFit.loose,
                            constraints: const BoxConstraints(maxHeight: 300),
                            menuProps: MenuProps(
                              borderRadius: BorderRadius.circular(16),
                              elevation: 6,
                            ),
                          ),
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: _decoracionSelector(
                              colorAcento,
                              'Selecciona un usuario',
                            ),
                          ),
                        )
                      // ===== SECCIONES 3 y 7: selección MÚLTIPLE =====
                      : _construirSelectorMultiple(colorAcento),
          const SizedBox(height: 18),

          // Botón "Enviar voto" (SOLO en secciones 3 y 7, NO en modo lectura)
          if ((seccion.screenNumber == 3 || seccion.screenNumber == 7) &&
              seccion.screenNumber != 8 &&
              !_isReadOnly)
            SizedBox(
              width: double.infinity,
              child: _botonGradiente(
                texto: 'Enviar voto',
                icono: Icons.how_to_vote_rounded,
                colores: _verde,
                cargando: _isVoting,
                onPressed: _isVoting
                    ? null
                    : () {
                        final voteType =
                            _secciones[_seccionActual].screenNumber == 3
                                ? 'positive'
                                : 'negative';
                        _registrarVoto(voteType);
                      },
              ),
            ),

          // Botón "Enviar Reto" (SOLO en sección 8, NO en modo lectura)
          if (esReto && !_isReadOnly)
            SizedBox(
              width: double.infinity,
              child: _botonGradiente(
                texto: 'Enviar Reto',
                icono: Icons.sports_score_rounded,
                colores: _ambar,
                cargando: _isVoting,
                onPressed: _isVoting
                    ? null
                    : () {
                        _enviarReto();
                      },
              ),
            ),
        ],
      ),
    );
  }

  // ── Selector múltiple (secciones 3 y 7) ──
  Widget _construirSelectorMultiple(List<Color> colorAcento) {
    final total = _usuariosSeleccionados.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownSearch<User>.multiSelection(
          key: ValueKey('multi_$_selectorResetKey'),
          items: _usuarios,
          itemAsString: (user) => user.fullName,
          compareFn: (a, b) => a.id == b.id,
          selectedItems: _usuariosSeleccionados,
          onChanged: (List<User> seleccion) {
            if (seleccion.length > _maxVotos) {
              _mostrarSnack(
                'Puedes seleccionar máximo $_maxVotos usuarios. Se tomaron los primeros $_maxVotos.',
                esError: true,
              );
              setState(() {
                _usuariosSeleccionados = seleccion.take(_maxVotos).toList();
                _selectorResetKey++;
              });
              return;
            }
            setState(() => _usuariosSeleccionados = seleccion);
          },
          dropdownBuilder: (context, seleccion) => Text(
            seleccion.isEmpty
                ? (_numeroSeccionActual == 3
                    ? 'Selecciona a los mejores'
                    : 'Selecciona a tus compañeros')
                : '${seleccion.length} usuario(s) seleccionado(s)',
            style: TextStyle(
              fontSize: 15,
              color: seleccion.isEmpty ? _textoSuave : _texto,
              fontWeight: seleccion.isEmpty ? FontWeight.w400 : FontWeight.w700,
            ),
          ),
          popupProps: PopupPropsMultiSelection.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              cursorColor: colorAcento[0],
              decoration: _decoracionBuscador(),
            ),
            fit: FlexFit.loose,
            constraints: const BoxConstraints(maxHeight: 360),
            menuProps: MenuProps(
              borderRadius: BorderRadius.circular(16),
              elevation: 6,
            ),
          ),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: _decoracionSelector(
              colorAcento,
              'Selecciona usuarios',
              icono: Icons.group_add_rounded,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Contador
        Row(
          children: [
            Icon(Icons.how_to_vote_rounded, size: 16, color: colorAcento[0]),
            const SizedBox(width: 6),
            Text(
              total == 1 ? '1 seleccionado' : '$total seleccionados',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _textoSuave,
              ),
            ),
          ],
        ),

        // Chips de los seleccionados (con opción de quitar)
        if (total > 0) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _usuariosSeleccionados.map((user) {
              final yaVotado = _votadosSeccionActual.contains(user.id);
              return Chip(
                avatar: yaVotado
                    ? Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: colorAcento[0],
                      )
                    : null,
                label: Text(
                  user.fullName,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: colorAcento[0],
                  ),
                ),
                backgroundColor: colorAcento[0].withOpacity(0.1),
                side: BorderSide(color: colorAcento[0].withOpacity(0.25)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                deleteIcon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: colorAcento[0],
                ),
                onDeleted: () {
                  setState(() {
                    _usuariosSeleccionados = _usuariosSeleccionados
                        .where((u) => u.id != user.id)
                        .toList();
                    _selectorResetKey++;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  InputDecoration _decoracionBuscador() {
    return InputDecoration(
      hintText: 'Buscar usuario por nombre...',
      hintStyle: const TextStyle(color: _textoSuave, fontSize: 14),
      prefixIcon: const Icon(
        Icons.search_rounded,
        color: _textoSuave,
        size: 20,
      ),
      filled: true,
      fillColor: _fondo,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  InputDecoration _decoracionSelector(
    List<Color> colorAcento,
    String hint, {
    IconData icono = Icons.person_rounded,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icono, color: colorAcento[0]),
      filled: true,
      fillColor: _fondo,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorAcento[0], width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ── Barra fija inferior: Anterior / Siguiente / Completar ──
  Widget _construirBarraNavegacion() {
    final esUltima = _seccionActual == _secciones.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 54,
              child: OutlinedButton(
                onPressed: _seccionActual > 0 ? _irAlAnterior : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _texto,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 20),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Anterior',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: esUltima
                ? (_isReadOnly
                    ? _botonGradiente(
                        texto: _yaLaHizoSuelta
                            ? '✅ Ya la hiciste · Volver'
                            : 'Volver al listado',
                        icono: Icons.arrow_back_rounded,
                        colores: _heroColores,
                        onPressed: () => Navigator.pop(context),
                      )
                    : _botonGradiente(
                        texto: 'Completar píldora',
                        icono: Icons.check_circle_rounded,
                        colores: _verde,
                        cargando: _isLoading,
                        onPressed: _isLoading ? null : _completarPildora,
                      ))
                : _botonGradiente(
                    texto: 'Siguiente',
                    icono: Icons.arrow_forward_rounded,
                    colores: _heroColores,
                    iconoAlFinal: true,
                    onPressed: _irASiguiente,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _estadoMensaje(IconData icono, String mensaje, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 40, color: color),
            ),
            const SizedBox(height: 18),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textoSuave,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final hayContenido =
        !_isLoadingSecciones && _errorMessage == null && _secciones.isNotEmpty;

    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        foregroundColor: _texto,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Text(
          widget.retoTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _texto,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 1,
            shadowColor: Colors.black26,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: _isLoadingSecciones
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF6366F1),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Preparando tu píldora...',
                    style: TextStyle(color: _textoSuave, fontSize: 14),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? _estadoMensaje(
                  Icons.error_outline_rounded,
                  _errorMessage!,
                  const Color(0xFFEF4444),
                )
              : _secciones.isEmpty
                  ? _estadoMensaje(
                      Icons.inbox_rounded,
                      'No hay secciones disponibles',
                      _textoSuave,
                    )
                  : SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _construirHero(),
                          const SizedBox(height: 22),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            layoutBuilder: (actual, anteriores) => Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                ...anteriores,
                                if (actual != null) actual,
                              ],
                            ),
                            transitionBuilder: (child, animacion) =>
                                FadeTransition(
                              opacity: animacion,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.06, 0),
                                  end: Offset.zero,
                                ).animate(animacion),
                                child: child,
                              ),
                            ),
                            child: Column(
                              key: ValueKey<int>(_seccionActual),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _construirTarjetaSeccion(
                                  _secciones[_seccionActual],
                                  _coloresSeccion,
                                ),
                                if (_secciones[_seccionActual].sourceNote !=
                                        null &&
                                    _secciones[_seccionActual]
                                        .sourceNote!
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  _construirNota(
                                    _secciones[_seccionActual].sourceNote!,
                                  ),
                                ],
                                // Selector de autopercepción (SOLO en sección 5)
                                if (_secciones[_seccionActual].screenNumber ==
                                    5) ...[
                                  const SizedBox(height: 18),
                                  _construirSelectorAutopercepcion(
                                      _coloresSeccion),
                                ],
                                // Selector de usuario (SOLO en secciones 3, 7 y 8, NO en modo lectura)
                                if (!_isReadOnly &&
                                    (_secciones[_seccionActual].screenNumber ==
                                            3 ||
                                        _secciones[_seccionActual]
                                                .screenNumber ==
                                            7 ||
                                        _secciones[_seccionActual]
                                                .screenNumber ==
                                            8)) ...[
                                  const SizedBox(height: 18),
                                  _construirSelectorUsuario(
                                    _secciones[_seccionActual],
                                    _coloresSeccion,
                                  ),
                                ],
                                // Publicar en Social (SOLO en sección 9, opcional, NO en modo lectura)
                                if (!_isReadOnly &&
                                    _secciones[_seccionActual].screenNumber ==
                                        9) ...[
                                  const SizedBox(height: 18),
                                  _construirPublicarSocial(_coloresSeccion),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hayContenido) _construirBarraNavegacion(),
          CustomBottomNavigationBar(
            currentIndex: _currentNavIndex,
            onTap: _onNavTap,
          ),
        ],
      ),
    );
  }

  Future<void> _enviarReto() async {
    if (_usuarioSeleccionado == null) {
      _mostrarSnack('Por favor selecciona un usuario');
      return;
    }

    // Si ya se le envió el reto a este compañero, no se vuelve a enviar
    if (_retadosSeccion8.contains(_usuarioSeleccionado!.id.toString())) {
      _mostrarSnack('Ya enviaste el reto a ${_usuarioSeleccionado!.fullName}');
      return;
    }

    try {
      setState(() => _isVoting = true);

      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;
      final userId = authProvider.userId;

      if (token == null || userId == null) {
        _mostrarSnack('Error: No hay sesión activa', esError: true);
        return;
      }

      final practicaloProvider = context.read<PracticaloProvider>();

      // Mensaje automático
      final mensaje = 'Te desafío a hacer la píldora: ${widget.pildora.titulo}';

      final success = await practicaloProvider.crearInvitacion(
        token: token,
        recipientUserId: _usuarioSeleccionado!.id,
        retoId: widget.retoId,
        pillId: widget.pildora.id,
        message: mensaje,
      );

      if (success && mounted) {
        _mostrarSnack('¡Reto enviado correctamente!', esExito: true);
        setState(() {
          _retoEnviadoSeccion8 = true;
          _retadosSeccion8.add(_usuarioSeleccionado!.id.toString());
          // La selección NO se borra: se ve a quién se retó (igual que en 3 y 7)
        });
      } else if (mounted) {
        _mostrarSnack('Error al enviar el reto', esError: true);
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnack('Error: $e', esError: true);
      }
    } finally {
      setState(() => _isVoting = false);
    }
  }
}

// Clase auxiliar para el ícono y la etiqueta de cada sección
class _TemaSeccion {
  final IconData icono;
  final String etiqueta;
  const _TemaSeccion(this.icono, this.etiqueta);
}
