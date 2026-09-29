// login_screen.dart - IDENTIDAD DE MARCA RETUP (armonía página web)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/colors.dart';
import './signup/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isLoading = false;
  bool _ocultarPassword = true;

  // ===== Colores de marca RetUp (Paleta "Vínculo") =====
  static const Color _indigo =
      Color(0xFF2E2A72); // Predomina: fondos institucionales
  static const Color _turquesa =
      Color(0xFF12B5A6); // Botones y palabras destacadas
  static const Color _morado =
      Color(0xFF7209B7); // Compromiso (acentos puntuales)
  static const Color _tinta = Color(0xFF0E0F17); // Texto

  static const Color _fondo = Color(0xFFF5F5F2); // Blanco roto como la web
  static const Color _texto = _tinta;
  static const Color _textoSuave = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().login(
            _emailController.text,
            _passwordController.text,
          );

      // Si el login fue exitoso, verificar racha
      if (context.read<AuthProvider>().isAuthenticated) {
        await context.read<AuthProvider>().verificarRachaAlLogin();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ===== CABECERA ÍNDIGO =====
            _buildCabecera(context),

            // ===== TARJETA DEL FORMULARIO (sube sobre la cabecera) =====
            Transform.translate(
              offset: const Offset(0, -56),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _buildFormulario(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // CABECERA
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
          // Arcos decorativos sutiles (como en la web)
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
          // Contenido
          Padding(
            padding: EdgeInsets.fromLTRB(24, topPadding + 40, 24, 96),
            child: Column(
              children: [
                // Logo oficial RetUp (versión oscura) directamente sobre el índigo
                SizedBox(
                  width: 120,
                  height: 158,
                  child: Image.asset(
                    'assets/images/logo_retup_oscuro.jpg',
                    fit: BoxFit.contain,
                    // Convierte el fondo negro del logo en el índigo de la cabecera
                    color: _indigo,
                    colorBlendMode: BlendMode.screen,
                    // Aviso visible si el logo no se ha cargado
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text(
                        'RetUp',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                // Frase en turquesa, estilo "DESARROLLO HUMANO · DATOS..." de la web
                const Text(
                  'DESARROLLA TUS HABILIDADES BLANDAS',
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
        ],
      ),
    );
  }

  // ===================================================================
  // FORMULARIO
  // ===================================================================

  Widget _buildFormulario(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '¡Hola de nuevo! 👋',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _indigo,
            ),
          ),
          const SizedBox(height: 4),
          // "retos" destacado en turquesa
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 13.5, color: _textoSuave),
              children: [
                TextSpan(text: 'Inicia sesión para continuar con tus '),
                TextSpan(
                  text: 'retos',
                  style: TextStyle(
                    color: _turquesa,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Email
          _etiqueta('Email'),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            cursorColor: _indigo,
            decoration: _decoracionCampo(
              hint: 'tu@email.com',
              icono: Icons.mail_outline_rounded,
            ),
          ),
          const SizedBox(height: 16),

          // Contraseña
          _etiqueta('Contraseña'),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: _ocultarPassword,
            textInputAction: TextInputAction.done,
            cursorColor: _indigo,
            onSubmitted: (_) {
              if (!_isLoading) _handleLogin();
            },
            decoration: _decoracionCampo(
              hint: '••••••••',
              icono: Icons.lock_outline_rounded,
              sufijo: IconButton(
                icon: Icon(
                  _ocultarPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _textoSuave,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _ocultarPassword = !_ocultarPassword),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Botón Iniciar sesión (turquesa, como "Solicita una demo")
          _buildBotonLogin(),
          const SizedBox(height: 20),

          // Enlace a registro
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '¿No tienes cuenta?',
                style: TextStyle(fontSize: 13.5, color: _textoSuave),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignupScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Regístrate',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _turquesa,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _etiqueta(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _texto,
      ),
    );
  }

  InputDecoration _decoracionCampo({
    required String hint,
    required IconData icono,
    Widget? sufijo,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      prefixIcon: Icon(icono, color: _indigo, size: 20),
      suffixIcon: sufijo,
      filled: true,
      fillColor: _fondo,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
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
    );
  }

  Widget _buildBotonLogin() {
    return Opacity(
      opacity: _isLoading ? 0.7 : 1.0,
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
            onTap: _isLoading ? null : _handleLogin,
            child: Center(
              child: _isLoading
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
                      children: const [
                        Text(
                          'Iniciar sesión',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 20),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
