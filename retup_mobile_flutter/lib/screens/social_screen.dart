// social_screen.dart - IDENTIDAD DE MARCA RETUP (armonía página web)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/social_provider.dart';
import '../models/social_post_model.dart';
import '../utils/colors.dart';
import '../widgets/custom_bottom_navigation_bar.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({Key? key}) : super(key: key);

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  int _currentNavIndex = 2; // Social es el índice 2

  // ===== Colores de marca RetUp (Paleta "Vínculo") =====
  static const Color _indigo = Color(0xFF2E2A72); // Predomina
  static const Color _turquesa = Color(0xFF12B5A6); // Botones y acentos
  static const Color _turquesaOscuro = Color(0xFF0B8A7E);
  static const Color _morado = Color(0xFF7209B7); // Compromiso / destacados
  static const Color _tinta = Color(0xFF0E0F17); // Texto

  static const Color _fondo = Color(0xFFF5F5F2); // Blanco roto como la web
  static const Color _texto = _tinta;
  static const Color _textoSuave = Color(0xFF6B7280);
  static const Color _linea = Color(0xFFF1F2F6);

  // Degradado de botones principales (turquesa, como "Solicita una demo")
  static const List<Color> _gradientePrincipal = [
    _turquesa,
    _turquesaOscuro,
  ];

  // Paleta de avatares (misma que inicio y píldoras)
  static const List<List<Color>> _paleta = [
    [Color(0xFF2E2A72), Color(0xFF443E9E)], // Índigo
    [Color(0xFF12B5A6), Color(0xFF0B8A7E)], // Turquesa
    [Color(0xFF7209B7), Color(0xFF5B0893)], // Morado
    [Color(0xFF2E2A72), Color(0xFF7209B7)], // Índigo → Morado
    [Color(0xFF12B5A6), Color(0xFF2E2A72)], // Turquesa → Índigo
    [Color(0xFF7209B7), Color(0xFF2E2A72)], // Morado → Índigo
  ];

  // Destacados y publicaciones del sistema: morado de marca (en lugar de dorado)
  static const List<Color> _destacado = [_morado, _indigo];

  // Posts cuya vista ya se registró en esta sesión (evita llamadas repetidas)
  final Set<String> _vistasRegistradas = {};

  @override
  void initState() {
    super.initState();
    _cargarPosts();
  }

  Future<void> _cargarPosts() async {
    final auth = context.read<AuthProvider>();
    if (auth.token != null) {
      await context.read<SocialProvider>().loadPosts(auth.token!);
    }
  }

  void _onNavTap(int index) {
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/retos');
        break;
      case 2:
        break; // Ya estamos en Social
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

  @override
  Widget build(BuildContext context) {
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
              'Social',
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
        child: Consumer2<SocialProvider, AuthProvider>(
          builder: (context, social, auth, _) {
            if (social.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: _turquesa),
              );
            }

            if (social.errorMessage != null && social.posts.isEmpty) {
              return _buildError(social.errorMessage!);
            }

            final anclados = social.posts.where((p) => p.isPinned).toList();
            final recientes = social.posts.where((p) => !p.isPinned).toList();

            // Cada elemento se construye solo cuando aparece en pantalla,
            // así la vista de cada post se registra cuando el usuario la ve.
            final List<Widget Function()> items = [
              () => _buildHeader(),
              () => const SizedBox(height: 20),
              () => _buildCreatePostBox(auth),
              () => _separador(),
              if (anclados.isNotEmpty) ...[
                () => _buildSectionHeader(
                      '📌',
                      'Destacados',
                      'Publicaciones ancladas por el equipo',
                    ),
                () => const SizedBox(height: 14),
                ...anclados.map((p) => () => _buildPostCard(p, auth, social)),
                () => _separador(),
              ],
              () => _buildSectionHeader(
                    '💬',
                    'Lo último del equipo',
                    'Reacciona, comenta y participa',
                  ),
              () => const SizedBox(height: 14),
              if (social.posts.isEmpty)
                () => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildEstadoVacio(
                        '👥',
                        '¡Sé el primero en publicar!',
                        'Comparte una idea, un logro o una pregunta con tu equipo.',
                      ),
                    )
              else if (recientes.isEmpty)
                () => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildEstadoVacio(
                        '✨',
                        'Todo está en Destacados',
                        'No hay más publicaciones por ahora. ¡Anímate a compartir algo!',
                      ),
                    )
              else
                ...recientes.map((p) => () => _buildPostCard(p, auth, social)),
              () => const SizedBox(height: 12),
            ];

            return RefreshIndicator(
              color: _turquesa,
              onRefresh: () => social.refreshPosts(auth.token!),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 20),
                itemCount: items.length,
                itemBuilder: (context, index) => items[index](),
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

  // ===================================================================
  // HELPERS GENERALES
  // ===================================================================

  List<Color> _colorUsuario(String clave) {
    if (clave.isEmpty) return _paleta[0];
    return _paleta[clave.hashCode.abs() % _paleta.length];
  }

  String _tiempoRelativo(String fecha) {
    final f = DateTime.tryParse(fecha);
    if (f == null) return '';
    final diff = DateTime.now().difference(f);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';
    final local = f.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  void _registrarVista(
      SocialPost post, AuthProvider auth, SocialProvider social) {
    if (auth.token == null || _vistasRegistradas.contains(post.id)) return;
    _vistasRegistradas.add(post.id);
    social.registerView(post.id, auth.token!);
  }

  void _mostrarMensaje(String texto, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  BoxDecoration _decoracionTarjeta({Border? borde, Gradient? gradiente}) {
    return BoxDecoration(
      color: gradiente == null ? Colors.white : null,
      gradient: gradiente,
      borderRadius: BorderRadius.circular(20),
      border: borde,
      boxShadow: [
        BoxShadow(
          color: _indigo.withOpacity(0.07),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

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
              '💬 CONECTA CON TU EQUIPO',
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
            'Comunidad',
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
                    text: 'Comparte logros, ideas y aprendizajes con tus '),
                TextSpan(
                  text: 'compañeros',
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

  /// Icono + título + subtítulo (se usa en secciones y en los bottom sheets)
  Widget _tituloConIcono(String emoji, String titulo, String subtitulo) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _indigo.withOpacity(0.08),
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
      ],
    );
  }

  Widget _buildSectionHeader(String emoji, String titulo, String subtitulo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _tituloConIcono(emoji, titulo, subtitulo),
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

  Widget _avatar(String nombre, List<Color> colores, {double size = 42}) {
    final inicial =
        nombre.trim().isNotEmpty ? nombre.trim()[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
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
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.4,
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
        border: Border.all(color: _indigo.withOpacity(0.12)),
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
              onPressed: _cargarPosts,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  /// Botón principal turquesa (como los botones de la web)
  Widget _botonGradiente({
    required String texto,
    required VoidCallback onTap,
    IconData? icono,
    List<Color> colores = _gradientePrincipal,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: Ink(
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
                  const SizedBox(width: 8),
                ],
                Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      filled: true,
      fillColor: _fondo,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _indigo.withOpacity(0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _indigo.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _turquesa, width: 1.8),
      ),
    );
  }

  BoxDecoration _decoracionSheet() {
    return const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    );
  }

  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // ===================================================================
  // CAJA DE CREAR POST
  // ===================================================================

  Widget _buildCreatePostBox(AuthProvider auth) {
    final nombre = (auth.userName ?? '').trim();
    final primerNombre = nombre.isNotEmpty ? nombre.split(' ').first : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _decoracionTarjeta(),
      child: Column(
        children: [
          Row(
            children: [
              _avatar(nombre.isNotEmpty ? nombre : 'Tú', const [
                _indigo,
                Color(0xFF443E9E),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  color: _fondo,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _showCreatePostDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _indigo.withOpacity(0.12)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              primerNombre.isNotEmpty
                                  ? '¿Qué mensaje crees que necesiten tus compañeros hoy, $primerNombre?'
                                  : '¿Qué mensaje crees que necesiten tus compañeros hoy?',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _textoSuave, fontSize: 14),
                            ),
                          ),
                          const Icon(Icons.edit_rounded,
                              size: 18, color: _turquesa),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: _linea),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(Icons.photo_library_rounded, 'Foto',
                    _turquesa, () => _pickImage(ImageSource.gallery)),
              ),
              Expanded(
                child: _buildActionButton(Icons.camera_alt_rounded, 'Cámara',
                    _indigo, () => _pickImage(ImageSource.camera)),
              ),
              Expanded(
                child: _buildActionButton(Icons.poll_rounded, 'Encuesta',
                    _morado, () => _showPollDialog(context)),
              ),
              Expanded(
                child: _buildActionButton(Icons.mic_rounded, 'Audio',
                    _turquesaOscuro, () => _showAudioRecorder(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: _indigo,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // TARJETA DE POST
  // ===================================================================

  Widget _buildPostCard(
      SocialPost post, AuthProvider auth, SocialProvider social) {
    _registrarVista(post, auth, social);

    final isSystem = post.isSystemPost || post.contentType == 'streak_winner';

    Border? borde;
    if (post.isPinned) {
      borde = Border.all(color: _morado.withOpacity(0.4), width: 1.5);
    } else if (isSystem) {
      borde = Border.all(color: _morado.withOpacity(0.2));
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: _decoracionTarjeta(
        borde: borde,
        gradiente: isSystem
            ? const LinearGradient(
                colors: [Color(0xFFF4ECFB), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(post, auth, social, isSystem),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildPostContent(post, auth, social),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(height: 1, color: _linea),
            ),
            const SizedBox(height: 8),
            _buildPostActions(post, auth, social),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader(SocialPost post, AuthProvider auth,
      SocialProvider social, bool isSystem) {
    final name = isSystem
        ? 'RetUp'
        : ((post.userName != null && post.userName!.trim().isNotEmpty)
            ? post.userName!
            : 'Usuario');

    return Row(
      children: [
        isSystem
            ? Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: _destacado,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Text('🏆', style: TextStyle(fontSize: 20)),
              )
            : _avatar(name, _colorUsuario(post.userId)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: _indigo,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _tiempoRelativo(post.createdAt),
                style: const TextStyle(fontSize: 12, color: _textoSuave),
              ),
            ],
          ),
        ),
        if (isSystem)
          _chip('Sistema',
              fondo: _morado.withOpacity(0.12), colorTexto: _morado),
        if (post.isPinned)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _chip('📌 Anclado',
                fondo: _morado.withOpacity(0.12), colorTexto: _morado),
          ),
        if (!isSystem)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded,
                color: _textoSuave, size: 22),
            padding: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (value) async {
              switch (value) {
                case 'edit':
                  _showEditPostDialog(context, post, auth, social);
                  break;
                case 'delete':
                  _showDeletePostDialog(context, post.id, auth, social);
                  break;
                case 'pin':
                  await social.togglePin(post.id, auth.token!);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (post.isOwnPost)
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: const [
                      Icon(Icons.edit_outlined, size: 18, color: _indigo),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
              if (post.isOwnPost)
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: const [
                      Icon(Icons.delete_outline,
                          size: 18, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Borrar', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'pin',
                child: Row(
                  children: [
                    Icon(
                      post.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 18,
                      color: _morado,
                    ),
                    const SizedBox(width: 8),
                    Text(post.isPinned ? 'Desanclar' : 'Anclar'),
                  ],
                ),
              ),
            ],
          )
        else
          const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildPostContent(
      SocialPost post, AuthProvider auth, SocialProvider social) {
    switch (post.contentType) {
      case 'text':
        return Text(
          post.textContent ?? '',
          style: const TextStyle(fontSize: 14.5, color: _texto, height: 1.45),
        );

      case 'streak_winner':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _morado.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _morado.withOpacity(0.18)),
          ),
          child: Text(
            post.textContent ?? '',
            style: const TextStyle(
              fontSize: 15,
              color: _texto,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.textContent != null && post.textContent!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  post.textContent!,
                  style: const TextStyle(
                      fontSize: 14.5, color: _texto, height: 1.45),
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: Image.network(
                  post.mediaUrl ?? '',
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 200,
                      color: _fondo,
                      child: const Center(
                        child: CircularProgressIndicator(color: _turquesa),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: _fondo,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: _textoSuave, size: 40),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

      case 'audio':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.textContent != null && post.textContent!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  post.textContent!,
                  style: const TextStyle(
                      fontSize: 14.5, color: _texto, height: 1.45),
                ),
              ),
            _AudioPlayerWidget(audioUrl: post.mediaUrl ?? ''),
          ],
        );

      case 'poll':
        return _buildPollContent(post, auth, social);

      default:
        return Text(
          post.textContent ?? '',
          style: const TextStyle(fontSize: 14.5, color: _texto, height: 1.45),
        );
    }
  }

  Widget _buildPollContent(
      SocialPost post, AuthProvider auth, SocialProvider social) {
    final options = post.pollOptions ?? [];
    final totalVotes = options.fold<int>(0, (sum, o) => sum + o.voteCount);
    final hasVoted = options.any((o) => o.votedByMe);
    final textoVotos = '$totalVotes voto${totalVotes != 1 ? 's' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chip('📊 Encuesta',
            fondo: _turquesa.withOpacity(0.12), colorTexto: _turquesaOscuro),
        const SizedBox(height: 10),
        Text(
          post.textContent ?? '',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _indigo,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        ...options.map((option) {
          final percentage =
              totalVotes > 0 ? (option.voteCount / totalVotes) : 0.0;

          return GestureDetector(
            onTap: hasVoted
                ? null
                : () => social.votePoll(post.id, option.id, auth.token!),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: option.votedByMe ? _turquesa : const Color(0xFFE5E7EB),
                  width: option.votedByMe ? 1.8 : 1.2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  children: [
                    if (hasVoted)
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: percentage,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _turquesa.withOpacity(0.2),
                                  _morado.withOpacity(0.12),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          if (option.votedByMe) ...[
                            const Icon(Icons.check_circle_rounded,
                                size: 18, color: _turquesa),
                            const SizedBox(width: 8),
                          ] else if (!hasVoted) ...[
                            Icon(Icons.radio_button_unchecked,
                                size: 18, color: _indigo.withOpacity(0.4)),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              option.optionText,
                              style: TextStyle(
                                fontSize: 14,
                                color: _texto,
                                fontWeight: option.votedByMe
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (hasVoted)
                            Text(
                              '${(percentage * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _indigo,
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
        }),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            hasVoted ? textoVotos : '$textoVotos · Toca una opción para votar',
            style: const TextStyle(fontSize: 12, color: _textoSuave),
          ),
        ),
      ],
    );
  }

  Widget _buildPostActions(
      SocialPost post, AuthProvider auth, SocialProvider social) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          // ❤️ Like
          _accionPill(
            icono: post.likedByMe
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            texto: post.likeCount > 0 ? '${post.likeCount}' : 'Me gusta',
            color: _morado,
            activo: post.likedByMe,
            onTap: () => social.toggleLike(post.id, auth.token!),
          ),
          const SizedBox(width: 8),
          // 💬 Comentar
          _accionPill(
            icono: Icons.chat_bubble_outline_rounded,
            texto:
                post.commentsCount > 0 ? '${post.commentsCount}' : 'Comentar',
            color: _turquesa,
            activo: false,
            onTap: () => _showCommentsSheet(context, post.id, auth, social),
          ),
          const Spacer(),
          // 👁️ Vistas
          const Icon(Icons.visibility_outlined,
              size: 16, color: Color(0xFF9CA3AF)),
          const SizedBox(width: 4),
          Text(
            '${post.viewsCount}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _accionPill({
    required IconData icono,
    required String texto,
    required Color color,
    required bool activo,
    required VoidCallback onTap,
  }) {
    return Material(
      color: activo ? color.withOpacity(0.1) : _fondo,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 18, color: activo ? color : _textoSuave),
              const SizedBox(width: 6),
              Text(
                texto,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: activo ? color : _textoSuave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================================================================
  // DIALOGS Y BOTTOM SHEETS
  // ===================================================================

  // Crear post de texto
  void _showCreatePostDialog(BuildContext context) {
    final controller = TextEditingController();
    final auth = context.read<AuthProvider>();
    final social = context.read<SocialProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: _decoracionSheet(),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            const SizedBox(height: 16),
            _tituloConIcono(
                '✍️', 'Nueva publicación', 'Comparte algo con tu equipo'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              autofocus: true,
              cursorColor: _indigo,
              decoration: _inputDecoration(
                '¿Qué mensaje crees que necesiten tus compañeros hoy, ${(auth.userName ?? '').split(' ').first}?',
              ).copyWith(hintMaxLines: 3),
            ),
            const SizedBox(height: 16),
            _botonGradiente(
              texto: 'Publicar',
              icono: Icons.send_rounded,
              onTap: () async {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await social.createTextPost(
                    controller.text.trim(), auth.token!);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Seleccionar imagen
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 80);

      if (picked == null) return;

      final file = File(picked.path);
      _showImagePreviewDialog(file);
    } catch (e) {
      _mostrarMensaje('Error al seleccionar imagen', AppColors.error);
    }
  }

  void _showImagePreviewDialog(File imageFile) {
    final captionController = TextEditingController();
    final auth = context.read<AuthProvider>();
    final social = context.read<SocialProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.8,
        decoration: _decoracionSheet(),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            const SizedBox(height: 16),
            _tituloConIcono(
                '📷', 'Compartir foto', 'Añade un comentario si quieres'),
            const SizedBox(height: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  imageFile,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: captionController,
              cursorColor: _indigo,
              decoration: _inputDecoration('Añade un comentario...'),
            ),
            const SizedBox(height: 12),
            _botonGradiente(
              texto: 'Publicar',
              icono: Icons.send_rounded,
              onTap: () async {
                Navigator.pop(ctx);
                _mostrarMensaje('Subiendo imagen...', AppColors.info);
                final success = await social.createImagePost(
                    imageFile, captionController.text, auth.token!);
                if (success) {
                  _mostrarMensaje('¡Foto publicada! 🎉', AppColors.success);
                } else {
                  _mostrarMensaje('Error al publicar la foto', AppColors.error);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Crear encuesta
  void _showPollDialog(BuildContext context) {
    final questionController = TextEditingController();
    final optionControllers = [
      TextEditingController(),
      TextEditingController(),
    ];
    final auth = context.read<AuthProvider>();
    final social = context.read<SocialProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: _decoracionSheet(),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              const SizedBox(height: 16),
              _tituloConIcono('📊', 'Crear encuesta',
                  'Pregunta a tu equipo (2 a 5 opciones)'),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    TextField(
                      controller: questionController,
                      cursorColor: _indigo,
                      decoration: _inputDecoration('Escribe tu pregunta...'),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(
                      optionControllers.length,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: optionControllers[i],
                          cursorColor: _indigo,
                          decoration:
                              _inputDecoration('Opción ${i + 1}').copyWith(
                            suffixIcon: optionControllers.length > 2
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        color: AppColors.error),
                                    onPressed: () {
                                      setModalState(
                                          () => optionControllers.removeAt(i));
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    if (optionControllers.length < 5)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setModalState(() =>
                                optionControllers.add(TextEditingController()));
                          },
                          icon: const Icon(Icons.add_rounded, color: _turquesa),
                          label: const Text(
                            'Añadir opción',
                            style: TextStyle(
                              color: _turquesa,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _botonGradiente(
                texto: 'Crear encuesta',
                icono: Icons.poll_rounded,
                onTap: () async {
                  final question = questionController.text.trim();
                  final options = optionControllers
                      .map((c) => c.text.trim())
                      .where((t) => t.isNotEmpty)
                      .toList();

                  if (question.isEmpty || options.length < 2) {
                    _mostrarMensaje('Necesitas pregunta y al menos 2 opciones',
                        AppColors.warning);
                    return;
                  }
                  Navigator.pop(ctx);
                  await social.createPollPost(question, options, auth.token!);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Grabar audio
  void _showAudioRecorder(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AudioRecorderSheet(
        onAudioReady: (File audioFile) async {
          Navigator.pop(ctx);
          final auth = context.read<AuthProvider>();
          final social = context.read<SocialProvider>();
          _mostrarMensaje('Subiendo audio...', AppColors.info);
          final success =
              await social.createAudioPost(audioFile, null, auth.token!);
          if (success) {
            _mostrarMensaje('¡Audio publicado! 🎉', AppColors.success);
          } else {
            _mostrarMensaje('Error al publicar el audio', AppColors.error);
          }
        },
      ),
    );
  }

  // Editar post
  void _showEditPostDialog(BuildContext context, SocialPost post,
      AuthProvider auth, SocialProvider social) {
    final controller = TextEditingController(text: post.textContent ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '✏️ Editar publicación',
          style: TextStyle(fontWeight: FontWeight.w800, color: _indigo),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          cursorColor: _indigo,
          decoration: _inputDecoration('Escribe tu publicación...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: _textoSuave)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final success = await social.editPost(
                  post.id, controller.text.trim(), auth.token!);
              _mostrarMensaje(
                success ? 'Publicación editada' : 'Error al editar',
                success ? AppColors.success : AppColors.error,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _turquesa,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Guardar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // Borrar post
  void _showDeletePostDialog(BuildContext context, String postId,
      AuthProvider auth, SocialProvider social) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '🗑️ ¿Borrar publicación?',
          style: TextStyle(fontWeight: FontWeight.w800, color: _indigo),
        ),
        content: const Text(
          'Esta acción no se puede deshacer.',
          style: TextStyle(color: _textoSuave),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: _textoSuave)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await social.deletePost(postId, auth.token!);
              _mostrarMensaje(
                success ? 'Publicación eliminada' : 'Error al eliminar',
                success ? AppColors.success : AppColors.error,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Borrar',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // Comentarios
  void _showCommentsSheet(BuildContext context, String postId,
      AuthProvider auth, SocialProvider social) {
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.65,
        decoration: _decoracionSheet(),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 20,
          right: 20,
          top: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            const SizedBox(height: 16),
            _tituloConIcono('💬', 'Comentarios', 'Lo que opina tu equipo'),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<SocialComment>>(
                future: social.getComments(postId, auth.token!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _turquesa),
                    );
                  }
                  final comments = snapshot.data ?? [];
                  if (comments.isEmpty) {
                    return Center(
                      child: _buildEstadoVacio(
                        '🗨️',
                        'No hay comentarios aún',
                        '¡Sé el primero en comentar!',
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final c = comments[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _avatar(c.userName, _colorUsuario(c.userId),
                                size: 34),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _fondo,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            c.userName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: _indigo,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _tiempoRelativo(c.createdAt),
                                          style: const TextStyle(
                                              fontSize: 11, color: _textoSuave),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      c.commentText,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF374151),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentController,
                    cursorColor: _indigo,
                    decoration: _inputDecoration('Escribe un comentario...'),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    if (commentController.text.trim().isEmpty) return;
                    final comment = await social.addComment(
                      postId,
                      commentController.text.trim(),
                      auth.token!,
                    );
                    if (comment != null) {
                      Navigator.pop(ctx);
                      _mostrarMensaje(
                          'Comentario publicado', AppColors.success);
                    }
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: _gradientePrincipal,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _turquesa.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// WIDGET DE GRABADORA DE AUDIO
// ===================================================================
class _AudioRecorderSheet extends StatefulWidget {
  final Function(File) onAudioReady;
  const _AudioRecorderSheet({required this.onAudioReady});

  @override
  State<_AudioRecorderSheet> createState() => _AudioRecorderSheetState();
}

class _AudioRecorderSheetState extends State<_AudioRecorderSheet> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordedPath;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _recordedPath = path;
      });
    } else {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/retup_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        setState(() => _isRecording = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String titulo = _isRecording
        ? 'Grabando...'
        : (_recordedPath != null ? 'Audio listo' : 'Grabar audio');
    final String ayuda = _isRecording
        ? 'Toca para detener'
        : (_recordedPath != null
            ? 'Toca el micro para grabar de nuevo'
            : 'Toca el micro para empezar');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _SocialScreenState._indigo,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ayuda,
            style: const TextStyle(
                fontSize: 12.5, color: _SocialScreenState._textoSuave),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _toggleRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isRecording
                      ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
                      : _SocialScreenState._gradientePrincipal,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording
                            ? const Color(0xFFEF4444)
                            : _SocialScreenState._turquesa)
                        .withOpacity(0.4),
                    blurRadius: _isRecording ? 22 : 14,
                    spreadRadius: _isRecording ? 4 : 0,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_recordedPath != null && !_isRecording)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => widget.onAudioReady(File(_recordedPath!)),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text(
                  'Publicar audio',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _SocialScreenState._turquesa,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ===================================================================
// WIDGET REPRODUCTOR DE AUDIO
// ===================================================================
class _AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  const _AudioPlayerWidget({required this.audioUrl});

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    // Se registra UNA sola vez (antes se añadía un listener en cada play)
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(UrlSource(widget.audioUrl));
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _SocialScreenState._turquesa.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: _SocialScreenState._turquesa.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: _SocialScreenState._gradientePrincipal,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _SocialScreenState._turquesa.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🎙️ Mensaje de voz',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _SocialScreenState._indigo,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isPlaying ? 'Reproduciendo...' : 'Toca para escuchar',
                  style: const TextStyle(
                      fontSize: 12, color: _SocialScreenState._textoSuave),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
