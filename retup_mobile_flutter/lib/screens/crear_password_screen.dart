// crear_password_screen.dart - "Crea tu contraseña"
// Se muestra al entrar con una contraseña temporal (alta nueva o restablecida
// por el administrador). Hasta crear una propia no se puede usar la app.
// Mismo diseño que el login (identidad de marca RetUp).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/colors.dart';

class CrearPasswordScreen extends StatefulWidget {
  const CrearPasswordScreen({Key? key}) : super(key: key);

  @override
  State<CrearPasswordScreen> createState() => _CrearPasswordScreenState();
}

class _CrearPasswordScreenState extends State<CrearPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmarController = TextEditingController();
  bool _ocultarPassword = true;
  bool _ocultarConfirmar = true;
  bool _guardando = false;

  // ===== Colores de marca RetUp (Paleta "Vínculo") =====
  static const Color _indigo = Color(0xFF2E2A72);
  static const Color _turquesa = Color(0xFF12B5A6);
  static const Color _tinta = Color(0xFF0E0F17);
  static const Color _fondo = Color(0xFFF5F5F2);
  static const Color _textoSuave = Color(0xFF6B7280);

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmarController.dispose();
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

  Future<void> _guardar() async {
    final nueva = _passwordController.text;
    if (nueva.isEmpty || _confirmarController.text.isEmpty) {
      _mostrarError('Escribe tu nueva contraseña en los dos campos');
      return;
    }
    if (nueva != _confirmarController.text) {
      _mostrarError('Las contraseñas no coinciden');
      return;
    }

    setState(() => _guardando = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.cambiarPasswordTemporal(nueva);

    // Si fue bien, la app pasa sola al inicio y esta pantalla desaparece
    if (!mounted) return;
    setState(() => _guardando = false);
    if (!ok) {
      _mostrarError(auth.errorMessage ?? 'No se pudo cambiar la contraseña');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombreCompleto = context.read<AuthProvider>().userName ?? '';
    final nombre = nombreCompleto.split(' ').first;

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
                  child: _buildFormulario(nombre),
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
                    'TU CUENTA, TU CONTRASEÑA',
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
        ],
      ),
    );
  }

  // ===================================================================
  // FORMULARIO
  // ===================================================================

  Widget _buildFormulario(String nombre) {
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
          Text(
            nombre.isEmpty ? 'Crea tu contraseña 🔐' : 'Hola, $nombre 🔐',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _indigo,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Has entrado con una contraseña temporal. Crea tu propia '
            'contraseña para continuar.',
            style: TextStyle(fontSize: 13.5, height: 1.45, color: _textoSuave),
          ),
          const SizedBox(height: 24),

          _etiqueta('Nueva contraseña'),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: _ocultarPassword,
            textInputAction: TextInputAction.next,
            cursorColor: _indigo,
            decoration: _decoracionCampo(
              oculto: _ocultarPassword,
              alPulsarOjo: () =>
                  setState(() => _ocultarPassword = !_ocultarPassword),
            ),
          ),
          const SizedBox(height: 16),

          _etiqueta('Repite la contraseña'),
          const SizedBox(height: 6),
          TextField(
            controller: _confirmarController,
            obscureText: _ocultarConfirmar,
            textInputAction: TextInputAction.done,
            cursorColor: _indigo,
            onSubmitted: (_) {
              if (!_guardando) _guardar();
            },
            decoration: _decoracionCampo(
              oculto: _ocultarConfirmar,
              alPulsarOjo: () =>
                  setState(() => _ocultarConfirmar = !_ocultarConfirmar),
            ),
          ),
          const SizedBox(height: 28),

          _buildBotonGuardar(),
          const SizedBox(height: 12),

          // Por si no es buen momento: sale sin cambiarla (se le pedirá al volver)
          TextButton(
            onPressed:
                _guardando ? null : () => context.read<AuthProvider>().logout(),
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: _textoSuave,
              ),
            ),
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
        color: _tinta,
      ),
    );
  }

  InputDecoration _decoracionCampo({
    required bool oculto,
    required VoidCallback alPulsarOjo,
  }) {
    return InputDecoration(
      hintText: '••••••••',
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      prefixIcon:
          const Icon(Icons.lock_outline_rounded, color: _indigo, size: 20),
      suffixIcon: IconButton(
        icon: Icon(
          oculto ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: _textoSuave,
          size: 20,
        ),
        onPressed: alPulsarOjo,
      ),
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

  Widget _buildBotonGuardar() {
    return Opacity(
      opacity: _guardando ? 0.7 : 1.0,
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
            onTap: _guardando ? null : _guardar,
            child: Center(
              child: _guardando
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
                          'Guardar y entrar',
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
