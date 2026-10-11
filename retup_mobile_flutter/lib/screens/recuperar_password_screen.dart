// recuperar_password_screen.dart - "¿Olvidaste tu contraseña?"
// Envía la solicitud al backend. El administrador de la empresa la ve en el
// dashboard ("Requiere atención") y le entrega una contraseña temporal.
// Mismo diseño que el login (identidad de marca RetUp).

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/colors.dart';

class RecuperarPasswordScreen extends StatefulWidget {
  /// Email que la persona ya había escrito en el login (para no repetirlo)
  final String emailInicial;

  const RecuperarPasswordScreen({Key? key, this.emailInicial = ''})
      : super(key: key);

  @override
  State<RecuperarPasswordScreen> createState() =>
      _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends State<RecuperarPasswordScreen> {
  late TextEditingController _emailController;
  bool _isLoading = false;
  bool _enviado = false;
  String _mensajeEnviado = '';

  // ===== Colores de marca RetUp (Paleta "Vínculo") =====
  static const Color _indigo = Color(0xFF2E2A72);
  static const Color _turquesa = Color(0xFF12B5A6);
  static const Color _tinta = Color(0xFF0E0F17);
  static const Color _fondo = Color(0xFFF5F5F2);
  static const Color _textoSuave = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.emailInicial.trim());
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _enviarSolicitud() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _mostrarError('Escribe un email válido');
      return;
    }

    setState(() => _isLoading = true);
    final resultado = await AuthService().solicitarRestablecimiento(email);
    if (!mounted) return;

    if (resultado['success'] == true) {
      setState(() {
        _isLoading = false;
        _enviado = true;
        _mensajeEnviado = (resultado['message'] as String?) ??
            'Tu solicitud se ha enviado al administrador de tu empresa.';
      });
    } else {
      setState(() => _isLoading = false);
      _mostrarError((resultado['message'] as String?) ??
          'No se pudo enviar la solicitud');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildCabecera(context),
            Transform.translate(
              offset: const Offset(0, -56),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _buildTarjeta(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // CABECERA (igual que el login, con botón volver)
  // ===================================================================

  Widget _buildCabecera(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _indigo,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -150,
            top: -110,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                  width: 34,
                ),
              ),
            ),
          ),
          Positioned(
            left: -70,
            bottom: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                  width: 26,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, topPadding + 36, 24, 96),
            child: Center(
              child: Column(
                children: [
                  SizedBox(
                    width: 100,
                    height: 132,
                    child: Image.asset(
                      'assets/images/logo_retup_oscuro.jpg',
                      fit: BoxFit.contain,
                      color: _indigo,
                      colorBlendMode: BlendMode.screen,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                        child: Text(
                          'RetUp',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'RECUPERA EL ACCESO A TUS RETOS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _turquesa,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: topPadding + 8,
            child: Material(
              color: Colors.white.withOpacity(0.12),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                tooltip: 'Volver',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // TARJETA: formulario o confirmación
  // ===================================================================

  Widget _buildTarjeta(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _indigo.withOpacity(0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _enviado ? _buildConfirmacion() : _buildFormulario(),
    );
  }

  Widget _buildFormulario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '¿Olvidaste tu contraseña? 🔑',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: _indigo,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Escribe el email con el que entras en RetUp. El administrador de tu '
          'empresa recibirá tu solicitud y te dará una contraseña temporal.',
          style: TextStyle(fontSize: 13.5, height: 1.45, color: _textoSuave),
        ),
        const SizedBox(height: 24),
        const Text(
          'Email',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _tinta,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          cursorColor: _indigo,
          onSubmitted: (_) {
            if (!_isLoading) _enviarSolicitud();
          },
          decoration: InputDecoration(
            hintText: 'tu@email.com',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            prefixIcon: const Icon(Icons.mail_outline_rounded,
                color: _indigo, size: 20),
            filled: true,
            fillColor: _fondo,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _turquesa, width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _buildBoton(
          texto: 'Enviar solicitud',
          icono: Icons.send_rounded,
          onTap: _isLoading ? null : _enviarSolicitud,
          cargando: _isLoading,
        ),
      ],
    );
  }

  Widget _buildConfirmacion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _turquesa.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: _turquesa, size: 36),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Solicitud enviada',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: _indigo,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _mensajeEnviado,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.45, color: _tinta),
        ),
        const SizedBox(height: 10),
        const Text(
          'Cuando tengas tu contraseña temporal, úsala para iniciar sesión.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.45, color: _textoSuave),
        ),
        const SizedBox(height: 26),
        _buildBoton(
          texto: 'Volver a iniciar sesión',
          icono: Icons.arrow_forward_rounded,
          onTap: () => Navigator.pop(context),
          cargando: false,
        ),
      ],
    );
  }

  Widget _buildBoton({
    required String texto,
    required IconData icono,
    required VoidCallback? onTap,
    required bool cargando,
  }) {
    return Opacity(
      opacity: cargando ? 0.7 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            color: _turquesa,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _turquesa.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Center(
              child: cargando
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          texto,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(icono, color: Colors.white, size: 20),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
