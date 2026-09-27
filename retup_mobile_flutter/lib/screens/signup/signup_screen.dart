// signup_screen.dart - REDISEÑO VISUAL (misma armonía que el resto de la app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/colors.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastName1Controller;
  late TextEditingController _lastName2Controller;
  late TextEditingController _ageController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  bool _isLoading = false;
  bool _ocultarPassword = true;
  bool _ocultarConfirmar = true;

  String? _selectedGender;
  String? _selectedDepartment;

  // ===== Colores (mismos que el resto de la app) =====
  static const Color _fondo = Color(0xFFF6F7FB);
  static const Color _texto = Color(0xFF1F2937);
  static const Color _textoSuave = Color(0xFF6B7280);
  static const Color _morado = Color(0xFF6366F1);
  static const List<Color> _gradientePrincipal = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
  ];

  final List<String> _genderOptions = [
    'Masculino',
    'Femenino',
    'Prefiero no responder',
  ];

  final List<String> _departmentOptions = [
    'Finanzas',
    'Comercial',
    'Producción',
    'Logística',
    'Tecnología',
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastName1Controller = TextEditingController();
    _lastName2Controller = TextEditingController();
    _ageController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastName1Controller.dispose();
    _lastName2Controller.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  Future<void> _handleSignup() async {
    if (_firstNameController.text.trim().isEmpty ||
        _lastName1Controller.text.trim().isEmpty ||
        _lastName2Controller.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty ||
        _ageController.text.trim().isEmpty ||
        _selectedGender == null ||
        _selectedDepartment == null) {
      _mostrarError('Por favor completa todos los campos obligatorios');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _mostrarError('Las contraseñas no coinciden');
      return;
    }

    if (!_emailController.text.contains('@')) {
      _mostrarError('Email inválido');
      return;
    }

    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 16 || age > 100) {
      _mostrarError('Ingresa una edad válida (16-100)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().signup(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            firstName: _firstNameController.text.trim(),
            lastName1: _lastName1Controller.text.trim(),
            lastName2: _lastName2Controller.text.trim(),
            age: age,
            gender: _selectedGender,
            department: _selectedDepartment,
          );

      if (mounted && context.read<AuthProvider>().isAuthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Registro exitoso! Iniciando sesión...'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('Error: $e');
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
            // ===== CABECERA CON DEGRADADO =====
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
        gradient: LinearGradient(
          colors: _gradientePrincipal,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Círculos decorativos
          Positioned(
            right: -60,
            top: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -50,
            bottom: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Botón volver
          Positioned(
            left: 12,
            top: topPadding + 8,
            child: Material(
              color: Colors.white.withOpacity(0.2),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Contenido
          Padding(
            padding: EdgeInsets.fromLTRB(24, topPadding + 40, 24, 96),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 1.5,
                      ),
                    ),
                    child: const Text('🚀', style: TextStyle(fontSize: 38)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'RetUp',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Únete y empieza tus retos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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

  Widget _buildFormulario(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Crea tu cuenta ✨',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _texto,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Todos los campos son obligatorios',
            style: TextStyle(fontSize: 13.5, color: _textoSuave),
          ),
          const SizedBox(height: 22),

          // ========== SECCIÓN: DATOS PERSONALES ==========
          _tituloSeccion(Icons.person_rounded, 'Datos personales'),
          const SizedBox(height: 14),

          // Nombres
          _etiqueta('Nombres'),
          const SizedBox(height: 6),
          TextField(
            controller: _firstNameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: _decoracionCampo(
              hint: 'Ej: Juan Carlos',
              icono: Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 16),

          // Primer y Segundo Apellido (lado a lado)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _etiqueta('Primer apellido'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _lastName1Controller,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: _decoracionCampo(
                        hint: 'Ej: Pérez',
                        icono: Icons.badge_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _etiqueta('Segundo apellido'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _lastName2Controller,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: _decoracionCampo(
                        hint: 'Ej: García',
                        icono: Icons.badge_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Edad
          _etiqueta('Edad'),
          const SizedBox(height: 6),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            textInputAction: TextInputAction.next,
            decoration: _decoracionCampo(
              hint: 'Ej: 30',
              icono: Icons.cake_outlined,
            ),
          ),
          const SizedBox(height: 16),

          // Género
          _etiqueta('Género'),
          const SizedBox(height: 6),
          _buildDropdown(
            valor: _selectedGender,
            opciones: _genderOptions,
            hint: 'Selecciona tu género',
            icono: Icons.wc_rounded,
            onChanged: (v) => setState(() => _selectedGender = v),
          ),

          const SizedBox(height: 26),

          // ========== SECCIÓN: INFORMACIÓN LABORAL ==========
          _tituloSeccion(Icons.work_rounded, 'Información laboral'),
          const SizedBox(height: 14),

          _etiqueta('Departamento'),
          const SizedBox(height: 6),
          _buildDropdown(
            valor: _selectedDepartment,
            opciones: _departmentOptions,
            hint: 'Selecciona tu departamento',
            icono: Icons.business_outlined,
            onChanged: (v) => setState(() => _selectedDepartment = v),
          ),

          const SizedBox(height: 26),

          // ========== SECCIÓN: DATOS DE ACCESO ==========
          _tituloSeccion(Icons.lock_rounded, 'Datos de acceso'),
          const SizedBox(height: 14),

          // Email
          _etiqueta('Email'),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
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
            textInputAction: TextInputAction.next,
            decoration: _decoracionCampo(
              hint: '••••••••',
              icono: Icons.lock_outline_rounded,
              sufijo: _botonOjo(
                oculto: _ocultarPassword,
                onTap: () =>
                    setState(() => _ocultarPassword = !_ocultarPassword),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Confirmar contraseña
          _etiqueta('Confirmar contraseña'),
          const SizedBox(height: 6),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _ocultarConfirmar,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_isLoading) _handleSignup();
            },
            decoration: _decoracionCampo(
              hint: '••••••••',
              icono: Icons.lock_outline_rounded,
              sufijo: _botonOjo(
                oculto: _ocultarConfirmar,
                onTap: () =>
                    setState(() => _ocultarConfirmar = !_ocultarConfirmar),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Botón Registrarse
          _buildBotonRegistro(),
          const SizedBox(height: 20),

          // Enlace a login
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '¿Ya tienes cuenta?',
                style: TextStyle(fontSize: 13.5, color: _textoSuave),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Inicia sesión',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _morado,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // WIDGETS AUXILIARES
  // ===================================================================

  Widget _tituloSeccion(IconData icono, String texto) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _morado.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icono, color: _morado, size: 17),
        ),
        const SizedBox(width: 10),
        Text(
          texto,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _texto,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
        ),
      ],
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

  Widget _botonOjo({required bool oculto, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(
        oculto ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: _textoSuave,
        size: 20,
      ),
      onPressed: onTap,
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
      prefixIcon: Icon(icono, color: _morado, size: 20),
      suffixIcon: sufijo,
      filled: true,
      fillColor: _fondo,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _morado, width: 1.6),
      ),
    );
  }

  Widget _buildDropdown({
    required String? valor,
    required List<String> opciones,
    required String hint,
    required IconData icono,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: valor,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _textoSuave),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(14),
      style: const TextStyle(fontSize: 15, color: _texto),
      hint: Text(
        hint,
        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      ),
      decoration: _decoracionCampo(hint: '', icono: icono).copyWith(
        hintText: null,
      ),
      items: opciones
          .map((op) => DropdownMenuItem<String>(
                value: op,
                child: Text(op),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildBotonRegistro() {
    return Opacity(
      opacity: _isLoading ? 0.7 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: _gradientePrincipal),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _morado.withOpacity(0.4),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isLoading ? null : _handleSignup,
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
                          'Crear cuenta',
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
