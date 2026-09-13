import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pildora_model.dart';
import '../models/seccion_model.dart';
import '../providers/pildora_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/racha_provider.dart';
import '../services/secciones_service.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/feedback_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../widgets/custom_bottom_navigation_bar.dart';

class PildoraDetailScreen extends StatefulWidget {
  final Pildora pildora;
  final String retoTitle;

  final String retoId; //

  const PildoraDetailScreen({
    Key? key,
    required this.pildora,
    required this.retoTitle,
    required this.retoId, //
  }) : super(key: key);

  @override
  State<PildoraDetailScreen> createState() => _PildoraDetailScreenState();
}

class _PildoraDetailScreenState extends State<PildoraDetailScreen> {
  final SeccionesService _seccionesService = SeccionesService();
  final FeedbackService _feedbackService = FeedbackService();
  List<Seccion> _secciones = [];
  int _seccionActual = 0;
  bool _isLoading = false;
  bool _isLoadingSecciones = true;
  String? _errorMessage;
  List<User> _usuarios = [];
  bool _isLoadingUsuarios = false;
  User? _usuarioSeleccionado;
  int _currentNavIndex =
      -1; // -1 indica que no estamos en una pantalla principal
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _cargarSecciones();
    _cargarUsuarios();
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

      setState(() {
        _usuarios = usuarios;
        _isLoadingUsuarios = false;
        if (_usuarios.isNotEmpty) {
          _usuarioSeleccionado = _usuarios[0];
        }
      });
    } catch (e) {
      print('❌ ERROR al cargar usuarios: $e');
      setState(() {
        _isLoadingUsuarios = false;
      });
    }
  }

  void _irASiguiente() {
    if (_seccionActual < _secciones.length - 1) {
      setState(() {
        _seccionActual++;
      });
    }
  }

  void _irAlAnterior() {
    if (_seccionActual > 0) {
      setState(() {
        _seccionActual--;
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
        Navigator.pushReplacementNamed(context, '/practicalo');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  Future<void> _completarPildora() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.userId;
      final token = authProvider.token;

      if (userId == null || token == null) {
        _showErrorDialog('Error', 'No hay usuario autenticado');
        return;
      }

      // 1. Completar la píldora normalmente
      final pildoraProvider = context.read<PildoraProvider>();
      final success = await pildoraProvider.completarPildora();

      if (success && mounted) {
        // 2. Registrar la píldora completada en Rachas (CON TOKEN)
        final rachaProvider = context.read<RachaProvider>();
        await rachaProvider.registrarPildoraCompletada(userId, token);

        showDialog(
          context: context,
          barrierDismissible: false, // ← Agregar esta línea
          builder: (context) => AlertDialog(
            title: const Text('¡Felicidades!'),
            content: const Text(
                '¡Has completado la píldora!\nContinúa así para subir en el ranking'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Cierra el diálogo
                  Navigator.pushReplacementNamed(context, '/'); // Va a home
                },
                child: const Text('Aceptar'),
              ),
            ],
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
    if (_usuarioSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un usuario')),
      );
      return;
    }

    try {
      setState(() => _isVoting = true);

      // Obtener el token del AuthProvider
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No hay sesión activa')),
        );
        return;
      }

      // Obtener el user ID actual (respondent)
      final respondentUserId = authProvider.userId;

      if (respondentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No hay usuario activo')),
        );
        return;
      }

      await _feedbackService.registerFeedbackVote(
        token: token,
        respondentUserId: respondentUserId,
        nominatedUserId: _usuarioSeleccionado!.id,
        retoId: widget.retoId,
        pillId: widget.pildora.id,
        sectionNumber: _secciones[_seccionActual].screenNumber,
        voteType: voteType,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ ¡Voto registrado correctamente!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    } finally {
      setState(() => _isVoting = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
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
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.retoTitle),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingSecciones
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? Center(
                  child: Text(_errorMessage!),
                )
              : _secciones.isEmpty
                  ? const Center(
                      child: Text('No hay secciones disponibles'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header con el título de la píldora
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Píldora de Aprendizaje',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[400],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.pildora.titulo ?? 'Sin título',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Indicador de progreso - Sección actual
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Sección ${_seccionActual + 1} de ${_secciones.length}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: (_seccionActual + 1) /
                                          _secciones.length,
                                      minHeight: 6,
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Contenido de la sección actual
                          if (_secciones.isNotEmpty) ...[
                            Text(
                              _secciones[_seccionActual].screenName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ✨ Mostrar dropdown si es pregunta anónima, sino contenido normal
                            if (_secciones[_seccionActual].screenType ==
                                'anonymous_question') ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.purple[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.purple[200]!,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _secciones[_seccionActual].screenContent,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                        height: 1.8,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Selecciona un usuario:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _isLoadingUsuarios
                                        ? const Center(
                                            child: CircularProgressIndicator())
                                        : _usuarios.isEmpty
                                            ? const Text(
                                                'No hay usuarios disponibles',
                                                style: TextStyle(
                                                    color: Colors.red),
                                              )
                                            : DropdownButton<User>(
                                                value: _usuarioSeleccionado,
                                                isExpanded: true,
                                                items: _usuarios.map((user) {
                                                  return DropdownMenuItem<User>(
                                                    value: user,
                                                    child: Text(user.fullName),
                                                  );
                                                }).toList(),
                                                onChanged: (User? newValue) {
                                                  setState(() {
                                                    _usuarioSeleccionado =
                                                        newValue;
                                                  });
                                                },
                                              ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue[200]!,
                                  ),
                                ),
                                child: Text(
                                  _secciones[_seccionActual].screenContent,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.8,
                                  ),
                                ),
                              ),
                            ],

                            if (_secciones[_seccionActual].sourceNote != null &&
                                _secciones[_seccionActual]
                                    .sourceNote!
                                    .isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.amber[200]!,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info,
                                      color: Colors.amber[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _secciones[_seccionActual].sourceNote!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.amber[900],
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                          ],

                          // 🔍 Dropdown con buscador para seleccionar usuario (SOLO en secciones 3, 7 y 8)
                          if (_secciones.isNotEmpty &&
                              (_secciones[_seccionActual].screenNumber == 3 ||
                                  _secciones[_seccionActual].screenNumber ==
                                      7 ||
                                  _secciones[_seccionActual].screenNumber ==
                                      8)) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Selecciona un usuario de la empresa:',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _isLoadingUsuarios
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : _usuarios.isEmpty
                                    ? const Text(
                                        'No hay usuarios disponibles',
                                        style: TextStyle(color: Colors.red),
                                      )
                                    : DropdownSearch<User>(
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
                                            cursorColor: Colors.blue,
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Buscar usuario por nombre...',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                            ),
                                          ),
                                          fit: FlexFit.loose,
                                          constraints: BoxConstraints(
                                            maxHeight: 300,
                                          ),
                                        ),
                                        dropdownDecoratorProps:
                                            DropDownDecoratorProps(
                                          dropdownSearchDecoration:
                                              InputDecoration(
                                            labelText: 'Usuario',
                                            hintText: 'Selecciona un usuario',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                            const SizedBox(height: 24),

                            // 🗳️ Botón "Enviar voto" (SOLO en secciones 3 y 7)
                            if (_secciones[_seccionActual].screenNumber == 3 ||
                                _secciones[_seccionActual].screenNumber ==
                                    7) ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isVoting
                                      ? null
                                      : () {
                                          final voteType =
                                              _secciones[_seccionActual]
                                                          .screenNumber ==
                                                      3
                                                  ? 'positive'
                                                  : 'negative';
                                          _registrarVoto(voteType);
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isVoting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Text(
                                          'Enviar voto',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ],

                          // Botones de navegación
                          if (_secciones.isNotEmpty &&
                              _seccionActual < _secciones.length - 1) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton.icon(
                                  onPressed:
                                      _seccionActual > 0 ? _irAlAnterior : null,
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Anterior'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[300],
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _irASiguiente,
                                  icon: const Icon(Icons.arrow_forward),
                                  label: const Text('Siguiente'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (_secciones.isNotEmpty &&
                              _seccionActual == _secciones.length - 1) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _irAlAnterior,
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Anterior'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[300],
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Botón de completar píldora (solo en la última sección)
                          if (_secciones.isNotEmpty &&
                              _seccionActual == _secciones.length - 1) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                    _isLoading ? null : _completarPildora,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Text(
                                        '✓ Completar píldora',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
