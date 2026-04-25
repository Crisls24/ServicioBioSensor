import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:invernadero/Pages/SeleccionRol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class CrearCuentaPage extends StatefulWidget {
  final String? invernaderoIdToJoin;
  final String appId;

  const CrearCuentaPage({
    super.key,
    this.invernaderoIdToJoin,
    required this.appId,
  });

  @override
  State<CrearCuentaPage> createState() => _CrearCuentaPageState();
}

class _CrearCuentaPageState extends State<CrearCuentaPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  // FocusNodes para rendimiento del teclado
  final _f1 = FocusNode();
  final _f2 = FocusNode();
  final _f3 = FocusNode();
  final _f4 = FocusNode();
  final ValueNotifier<bool> _isFocused = ValueNotifier(false);

  final isLoading = ValueNotifier(false);
  final obscure1 = ValueNotifier(true);
  final obscure2 = ValueNotifier(true);

  late AnimationController _entranceCtrl;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    // Listeners para optimización de blur
    _f1.addListener(_onFocusChange);
    _f2.addListener(_onFocusChange);
    _f3.addListener(_onFocusChange);
    _f4.addListener(_onFocusChange);
    
    _entranceCtrl.forward();
  }

  void _onFocusChange() {
    _isFocused.value = _f1.hasFocus || _f2.hasFocus || _f3.hasFocus || _f4.hasFocus;
  }

  @override
  void dispose() {
    _f1.removeListener(_onFocusChange);
    _f2.removeListener(_onFocusChange);
    _f3.removeListener(_onFocusChange);
    _f4.removeListener(_onFocusChange);
    _f1.dispose(); _f2.dispose(); _f3.dispose(); _f4.dispose();
    _isFocused.dispose();
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    isLoading.dispose();
    obscure1.dispose();
    obscure2.dispose();
    _entranceCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    isLoading.value = true;

    try {
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );

      final userUid = userCred.user!.uid;

      final userDocRef = _firestore
          .collection('artifacts')
          .doc(widget.appId)
          .collection('public')
          .doc('data')
          .collection('usuarios')
          .doc(userUid);

      await Future.wait([
        userCred.user!.sendEmailVerification(),
        userDocRef.set({
          'nombre': nameCtrl.text.trim(),
          'email': emailCtrl.text.trim(),
          'uid': userUid,
          'fechaRegistro': Timestamp.now(),
          'rol': widget.invernaderoIdToJoin != null ? 'empleado' : 'pendiente',
          'invernaderoId': widget.invernaderoIdToJoin ?? '',
        }),
      ]);

      if (widget.invernaderoIdToJoin != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pendingInvernaderoId');
      }
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cuenta creada. Verifica tu email para continuar.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF00C853),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SeleccionRol(
            invernaderoIdFromLink: widget.invernaderoIdToJoin,
            appId: widget.appId,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Error en el registro.';
      if (e.code == 'email-already-in-use') msg = 'Este correo ya está registrado.';
      else if (e.code == 'weak-password') msg = 'La contraseña es muy débil.';
      else if (e.code == 'invalid-email') msg = 'El formato del correo es incorrecto.';
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: GoogleFonts.inter(color: Colors.white)), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFF0A0A0A);
    const Color brandEmerald = Color(0xFF00C853);
    const Color textWhite = Color(0xFFFFFFFF);
    const Color textGrey = Color(0xFFD1D5DB);
    const Color textLabel = Color(0xFFA7F3D0);

    final fadeHeader = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
    final slideHeader = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)));

    final fadeCard = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));
    final slideCard = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)));

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Fondo Animado
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _glowCtrl,
              builder: (context, _) {
                return Stack(
                  children: [
                    Positioned(
                      top: -120,
                      right: -60,
                      child: Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: brandEmerald.withValues(alpha: 0.1 * _glowCtrl.value),
                              blurRadius: 150,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -80,
                      left: -80,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: brandEmerald.withValues(alpha: 0.06 * (1 - _glowCtrl.value)),
                              blurRadius: 130,
                              spreadRadius: 15,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      FadeTransition(
                        opacity: fadeHeader,
                        child: SlideTransition(
                          position: slideHeader,
                          child: Column(
                            children: [
                              Text(
                                "BIOSENSOR",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: brandEmerald,
                                  letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Crear Cuenta",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: textWhite,
                                  letterSpacing: -1.2,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Card
                      FadeTransition(
                        opacity: fadeCard,
                        child: SlideTransition(
                          position: slideCard,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _isFocused,
                              builder: (context, focused, child) {
                                // OPTIMIZACIÓN ZERO-LAG
                                return BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: focused ? 0.0 : 6.0, 
                                    sigmaY: focused ? 0.0 : 6.0
                                  ),
                                  child: child!,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    width: 1.0,
                                  ),
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildLabel("INFORMACIÓN PERSONAL", textLabel),
                                      _buildTextField(
                                        ctrl: nameCtrl,
                                        focus: _f1,
                                        hint: "Nombre completo",
                                        icon: Icons.person_rounded,
                                        autofill: const [AutofillHints.name],
                                        validator: (v) {
                                          if (v == null || v.isEmpty) return 'El nombre es obligatorio';
                                          if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(v.trim())) {
                                            return 'Solo se permiten letras';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      _buildLabel("ACCESO", textLabel),
                                      _buildTextField(
                                        ctrl: emailCtrl,
                                        focus: _f2,
                                        hint: "Correo electrónico",
                                        icon: Icons.email_rounded,
                                        keyboard: TextInputType.emailAddress,
                                        autofill: const [AutofillHints.email],
                                        validator: (v) {
                                          if (v == null || v.isEmpty) return 'El correo es obligatorio';
                                          final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                          if (!emailRegex.hasMatch(v.trim())) return 'Ingresa un correo válido';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      _buildLabel("SEGURIDAD", textLabel),
                                      ValueListenableBuilder(
                                        valueListenable: obscure1,
                                        builder: (_, bool val, __) => _buildTextField(
                                          ctrl: passCtrl,
                                          focus: _f3,
                                          hint: "Contraseña",
                                          icon: Icons.lock_rounded,
                                          isPassword: true,
                                          obscure: val,
                                          autofill: const [AutofillHints.newPassword],
                                          onToggle: () => obscure1.value = !val,
                                          validator: (v) {
                                            if (v == null || v.isEmpty) return 'La contraseña es obligatoria';
                                            if (v.length < 8) return 'Mínimo 8 caracteres';
                                            if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$').hasMatch(v)) {
                                              return 'Debe incluir letras y números';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ValueListenableBuilder(
                                        valueListenable: obscure2,
                                        builder: (_, bool val, __) => _buildTextField(
                                          ctrl: confirmCtrl,
                                          focus: _f4,
                                          hint: "Repetir Contraseña",
                                          icon: Icons.shield_rounded,
                                          isPassword: true,
                                          obscure: val,
                                          onToggle: () => obscure2.value = !val,
                                          validator: (v) => v != passCtrl.text ? 'Las contraseñas no coinciden' : null,
                                        ),
                                      ),
                                      const SizedBox(height: 40),

                                      ValueListenableBuilder(
                                        valueListenable: isLoading,
                                        builder: (_, bool val, __) => Container(
                                          height: 58,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              if (!val)
                                                BoxShadow(
                                                  color: brandEmerald.withValues(alpha: 0.3),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 8),
                                                ),
                                            ],
                                          ),
                                          child: ElevatedButton(
                                            onPressed: val ? null : _register,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: brandEmerald,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              disabledBackgroundColor: brandEmerald.withValues(alpha: 0.4),
                                            ),
                                            child: val
                                                ? const SizedBox(
                                                    height: 24,
                                                    width: 24,
                                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                  )
                                                : Text(
                                                    "CREAR CUENTA",
                                                    style: GoogleFonts.inter(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: 1.2,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      FadeTransition(
                        opacity: fadeCard,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "¿Ya eres miembro? ",
                              style: GoogleFonts.inter(color: textGrey, fontSize: 14),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                              child: Text(
                                "INICIAR SESIÓN",
                                style: GoogleFonts.inter(
                                  color: brandEmerald,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, left: 4.0),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: color.withValues(alpha: 0.85), letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    FocusNode? focus,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    Iterable<String>? autofill,
  }) {
    return TextFormField(
      controller: ctrl,
      focusNode: focus,
      obscureText: obscure,
      keyboardType: keyboard,
      autofillHints: autofill,
      style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.3), fontSize: 15),
        prefixIcon: Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.5)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white.withValues(alpha: 0.5), size: 18),
                onPressed: onToggle,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00C853), width: 1.2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5), width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.2)),
        errorStyle: GoogleFonts.inter(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w500),
      ),
      validator: validator,
    );
  }
}
