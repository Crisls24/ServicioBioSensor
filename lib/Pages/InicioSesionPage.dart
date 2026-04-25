import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invernadero/Pages/SeleccionRol.dart';
import 'package:invernadero/Pages/GestionInvernadero.dart';
import 'package:invernadero/Pages/HomePage.dart';

class InicioSesion extends StatefulWidget {
  final String? invernaderoIdToJoin;
  final String appId;

  const InicioSesion({
    super.key,
    this.invernaderoIdToJoin,
    required this.appId,
  });

  @override
  State<InicioSesion> createState() => _InicioSesionState();
}

class _InicioSesionState extends State<InicioSesion>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // FocusNodes para detectar interacción
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final ValueNotifier<bool> _isFocused = ValueNotifier(false);
  
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier(false);
  bool _obscure = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _pendingInvernadero;

  late AnimationController _entranceCtrl;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    // Listener para desactivar blur cuando hay foco (mejora rendimiento teclado)
    _emailFocus.addListener(_onFocusChange);
    _passFocus.addListener(_onFocusChange);
    
    _entranceCtrl.forward();
    _loadPendingInvernadero();
  }

  void _onFocusChange() {
    _isFocused.value = _emailFocus.hasFocus || _passFocus.hasFocus;
  }

  DocumentReference<Map<String, dynamic>> _getUserProfileRef(String uid) {
    return _firestore
        .collection('artifacts')
        .doc(widget.appId)
        .collection('public')
        .doc('data')
        .collection('usuarios')
        .doc(uid);
  }

  Future<void> _loadPendingInvernadero() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('pendingInvernaderoId');
    if (mounted) {
      setState(() {
        _pendingInvernadero = saved;
      });
    }
  }

  @override
  void dispose() {
    _emailFocus.removeListener(_onFocusChange);
    _passFocus.removeListener(_onFocusChange);
    _emailFocus.dispose();
    _passFocus.dispose();
    _isFocused.dispose();
    _entranceCtrl.dispose();
    _glowCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _loadingNotifier.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;
    _loadingNotifier.value = true;
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final user = userCredential.user;
      if (user != null) await _navigateAfterLogin(user);
    } on FirebaseAuthException catch (e) {
      String msg = 'Error de acceso. Por favor verifica tus datos.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Correo o contraseña incorrectos.';
      } else if (e.code == 'user-disabled') {
        msg = 'Cuenta deshabilitada. Contacta soporte.';
      } else if (e.code == 'invalid-email') {
        msg = 'El formato del correo es inválido.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inesperado: $e', style: GoogleFonts.inter(color: Colors.white))),
        );
      }
    } finally {
      if (mounted) _loadingNotifier.value = false;
    }
  }

  Future<void> _loginWithGoogle() async {
    _loadingNotifier.value = true;
    try {
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) _loadingNotifier.value = false;
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final savedInvernadero = widget.invernaderoIdToJoin ?? _pendingInvernadero;
        final userRef = _getUserProfileRef(user.uid);
        final doc = await userRef.get();

        if (!doc.exists) {
          await userRef.set({
            'uid': user.uid,
            'email': user.email,
            'nombre': user.displayName,
            'invernaderoId': savedInvernadero ?? '',
            'fechaRegistro': FieldValue.serverTimestamp(),
            'rol': savedInvernadero != null ? 'empleado' : 'pendiente',
          });
        }
        if (mounted) await _navigateAfterLogin(user);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error con Google: $e', style: GoogleFonts.inter(color: Colors.white))),
        );
      }
    } finally {
      if (mounted) _loadingNotifier.value = false;
    }
  }

  Future<void> _navigateAfterLogin(User user) async {
    final docRef = _getUserProfileRef(user.uid);
    final doc = await docRef.get();
    final data = doc.data() ?? {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pendingInvernaderoId');

    if (!mounted) return;

    final String normalizedRol = (data['rol'] as String?)?.toLowerCase() ?? '';
    final String invernaderoIdExistente = (data['invernaderoId'] as String?) ?? (data['greenhouseId'] as String?) ?? '';
    final String? invernaderoToJoin = widget.invernaderoIdToJoin?.isNotEmpty == true ? widget.invernaderoIdToJoin : _pendingInvernadero;

    if (invernaderoToJoin != null && invernaderoToJoin.isNotEmpty) {
      if (normalizedRol == 'empleado' && invernaderoIdExistente == invernaderoToJoin) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(appId: widget.appId)));
        return;
      }
      if (normalizedRol.isEmpty || normalizedRol == 'pendiente') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SeleccionRol(invernaderoIdFromLink: invernaderoToJoin, appId: widget.appId)));
        return;
      }
      if (normalizedRol == 'dueño') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Gestioninvernadero(appId: widget.appId)));
        return;
      }
    }

    if (normalizedRol.isEmpty || normalizedRol == 'pendiente') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SeleccionRol(appId: widget.appId)));
      return;
    }
    if (normalizedRol == 'dueño') {
      if (invernaderoIdExistente.isNotEmpty) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Gestioninvernadero(appId: widget.appId)));
      } else {
        Navigator.pushReplacementNamed(context, '/registrarinvernadero');
      }
      return;
    }
    if (normalizedRol == 'empleado') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(appId: widget.appId)));
      return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SeleccionRol(appId: widget.appId)));
  }

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFF0A0A0A);
    const Color brandEmerald = Color(0xFF00C853);
    const Color textWhite = Color(0xFFFFFFFF);
    const Color textGrey = Color(0xFFD1D5DB);
    const Color textLabel = Color(0xFFA7F3D0);

    final fadeHeader = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));
    final slideHeader = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)));

    final fadeInputs = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));
    final slideInputs = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)));

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Mesh Glow (Aislado para rendimiento)
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

          // 2. Layout
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      // Header Section
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
                                "Iniciar Sesión",
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

                      // Glass Card
                      FadeTransition(
                        opacity: fadeInputs,
                        child: SlideTransition(
                          position: slideInputs,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _isFocused,
                              builder: (context, focused, child) {
                                // OPTIMIZACIÓN ZERO-LAG: Desactivamos el filtro pesado 
                                // solo cuando el usuario está escribiendo para que el teclado suba a 60fps.
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
                                      _buildLabel("ACCESO", textLabel),
                                      _buildTextField(
                                        ctrl: _emailController,
                                        focus: _emailFocus,
                                        hint: "Correo electrónico",
                                        icon: Icons.email_rounded,
                                        keyboard: TextInputType.emailAddress,
                                        autofill: const [AutofillHints.email],
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) return 'El correo es requerido';
                                          // Regex formal: requiere dominio y extensión reales
                                          final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                          if (!emailRegex.hasMatch(v.trim())) return 'Ingresa un correo válido (ej. usuario@gmail.com)';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      _buildLabel("SEGURIDAD", textLabel),
                                      _buildTextField(
                                        ctrl: _passwordController,
                                        focus: _passFocus,
                                        hint: "Contraseña",
                                        icon: Icons.lock_rounded,
                                        isPassword: true,
                                        obscure: _obscure,
                                        autofill: const [AutofillHints.password],
                                        onToggle: () => setState(() => _obscure = !_obscure),
                                        onSubmitted: (_) => _loginUser(),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) return 'La contraseña es requerida';
                                          if (v.length < 8) return 'Debe tener al menos 8 caracteres';
                                          if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$').hasMatch(v)) {
                                            return 'Debe incluir letras y números';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 40),

                                      // Submit & Google Section
                                      ValueListenableBuilder<bool>(
                                        valueListenable: _loadingNotifier,
                                        builder: (context, isLoading, _) => Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Container(
                                              height: 58,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(16),
                                                boxShadow: [
                                                  if (!isLoading)
                                                    BoxShadow(
                                                      color: brandEmerald.withValues(alpha: 0.3),
                                                      blurRadius: 20,
                                                      offset: const Offset(0, 8),
                                                    ),
                                                ],
                                              ),
                                              child: ElevatedButton(
                                                onPressed: isLoading ? null : _loginUser,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: brandEmerald,
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  disabledBackgroundColor: brandEmerald.withValues(alpha: 0.4),
                                                ),
                                                child: isLoading
                                                    ? const SizedBox(
                                                        height: 24,
                                                        width: 24,
                                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                      )
                                                    : Text(
                                                        "CONTINUAR",
                                                        style: GoogleFonts.inter(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w900,
                                                          letterSpacing: 1.2,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                            const SizedBox(height: 24),

                                            Row(
                                              children: [
                                                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                                  child: Text("O", style: GoogleFonts.inter(color: textGrey.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w800)),
                                                ),
                                                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                                              ],
                                            ),
                                            const SizedBox(height: 24),

                                            SizedBox(
                                              height: 58,
                                              child: ElevatedButton(
                                                onPressed: isLoading ? null : _loginWithGoogle,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Image.asset('assets/Google_Logo.png', height: 24, width: 24),
                                                    RichText(
                                                      text: TextSpan(
                                                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                                                        children: const [
                                                          TextSpan(text: 'Continuar con '),
                                                          TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
                                                          TextSpan(text: 'o', style: TextStyle(color: Color(0xFFEA4335))),
                                                          TextSpan(text: 'o', style: TextStyle(color: Color(0xFFFBBC05))),
                                                          TextSpan(text: 'g', style: TextStyle(color: Color(0xFF4285F4))),
                                                          TextSpan(text: 'l', style: TextStyle(color: Color(0xFF34A853))),
                                                          TextSpan(text: 'e', style: TextStyle(color: Color(0xFFEA4335))),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 24),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
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

                      // Footer Link
                      FadeTransition(
                        opacity: fadeInputs,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "¿No tienes cuenta? ",
                              style: GoogleFonts.inter(color: textGrey, fontSize: 14),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/registrarupage', arguments: widget.invernaderoIdToJoin ?? _pendingInvernadero);
                              },
                              child: Text(
                                "CREAR CUENTA",
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
    void Function(String)? onSubmitted,
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
      onFieldSubmitted: onSubmitted,
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
