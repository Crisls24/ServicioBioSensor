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
import 'package:invernadero/core/theme/app_colors.dart';
import 'package:invernadero/core/theme/theme_notifier.dart';

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
    with TickerProviderStateMixin, WidgetsBindingObserver { 
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
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
    WidgetsBinding.instance.addObserver(this);
    
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _emailFocus.addListener(_onFocusChange);
    _passFocus.addListener(_onFocusChange);
    
    _entranceCtrl.forward();
    _loadPendingInvernadero();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _glowCtrl.stop();
    } else if (state == AppLifecycleState.resumed) {
      _glowCtrl.repeat(reverse: true);
    }
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
    WidgetsBinding.instance.removeObserver(this);
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
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inesperado: $e', style: GoogleFonts.inter(color: Colors.white)), backgroundColor: AppColors.error),
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
          SnackBar(content: Text('Error con Google: $e', style: GoogleFonts.inter(color: Colors.white)), backgroundColor: AppColors.error),
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
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, _) {
        final Color background = AppColors.getBg(isDark);
        final Color cardColor = AppColors.getCardColor(isDark);
        final Color textPrimary = AppColors.getTextMain(isDark);
        final Color textSecondary = AppColors.getTextSecondary(isDark);
        final Color labelColor = AppColors.getLabel(isDark);
        final Color borderColor = AppColors.getBorder(isDark);
        final Color inputBg = AppColors.getInputBg(isDark);
        final double blurIntensity = isDark ? 4.5 : 2.0;

        final fadeHeader = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));
        final slideHeader = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
            CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)));

        final fadeInputs = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));
        final slideInputs = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(
            CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)));

        return Scaffold(
          backgroundColor: background,
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
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
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: (isDark ? 0.08 : 0.04) * _glowCtrl.value),
                                  blurRadius: 100,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -80,
                          left: -80,
                          child: Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: (isDark ? 0.05 : 0.03) * (1 - _glowCtrl.value)),
                                  blurRadius: 80,
                                  spreadRadius: 8,
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

              Positioned(
                top: 50,
                right: 20,
                child: FadeTransition(
                  opacity: fadeHeader,
                  child: IconButton(
                    onPressed: () => themeNotifier.toggleTheme(),
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: isDark ? Colors.white : AppColors.primary,
                      size: 28,
                    ),
                  ),
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
                          if (widget.invernaderoIdToJoin != null || _pendingInvernadero != null)
                            FadeTransition(
                              opacity: fadeHeader,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 24),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.mark_email_read_rounded, color: AppColors.primary, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Has sido invitado. Inicia sesión para unirte.',
                                        style: GoogleFonts.inter(color: labelColor, fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

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
                                      color: AppColors.primary,
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
                                      color: textPrimary,
                                      letterSpacing: -1.2,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          FadeTransition(
                            opacity: fadeInputs,
                            child: SlideTransition(
                              position: slideInputs,
                              child: RepaintBoundary(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: ValueListenableBuilder<bool>(
                                    valueListenable: _isFocused,
                                    builder: (context, focused, child) {
                                      return BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: focused ? 0.0 : blurIntensity, 
                                          sigmaY: focused ? 0.0 : blurIntensity
                                        ),
                                        child: child!,
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(28),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(color: borderColor, width: 1.0),
                                        boxShadow: [
                                          if (!isDark)
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                        ],
                                      ),
                                      child: Form(
                                        key: _formKey,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            _buildLabel("ACCESO", labelColor),
                                            _buildTextField(
                                              ctrl: _emailController,
                                              focus: _emailFocus,
                                              hint: "Correo electrónico",
                                              icon: Icons.email_rounded,
                                              isDark: isDark,
                                              inputBg: inputBg,
                                              textPrimary: textPrimary,
                                              textSecondary: textSecondary,
                                              borderColor: borderColor,
                                              keyboard: TextInputType.emailAddress,
                                              autofill: const [AutofillHints.email],
                                              validator: (v) {
                                                if (v == null || v.trim().isEmpty) return 'El correo es requerido';
                                                final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                                if (!emailRegex.hasMatch(v.trim())) return 'Ingresa un correo válido';
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 20),
                                            _buildLabel("SEGURIDAD", labelColor),
                                            _buildTextField(
                                              ctrl: _passwordController,
                                              focus: _passFocus,
                                              hint: "Contraseña",
                                              icon: Icons.lock_rounded,
                                              isDark: isDark,
                                              inputBg: inputBg,
                                              textPrimary: textPrimary,
                                              textSecondary: textSecondary,
                                              borderColor: borderColor,
                                              isPassword: true,
                                              obscure: _obscure,
                                              autofill: const [AutofillHints.password],
                                              onToggle: () => setState(() => _obscure = !_obscure),
                                              onSubmitted: (_) => _loginUser(),
                                              validator: (v) {
                                                if (v == null || v.isEmpty) return 'La contraseña es requerida';
                                                if (v.length < 8) return 'Mínimo 8 caracteres';
                                                if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$').hasMatch(v)) {
                                                  return 'Debe incluir letras y números';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 40),

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
                                                            color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.15),
                                                            blurRadius: 15,
                                                            offset: const Offset(0, 6),
                                                          ),
                                                      ],
                                                    ),
                                                    child: ElevatedButton(
                                                      onPressed: isLoading ? null : _loginUser,
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: AppColors.primary,
                                                        foregroundColor: Colors.white,
                                                        elevation: 0,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                                                      ),
                                                      child: isLoading
                                                          ? const SizedBox(
                                                              height: 24,
                                                              width: 24,
                                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                            )
                                                          : const Text(
                                                              "CONTINUAR",
                                                              style: TextStyle(
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
                                                      Expanded(child: Divider(color: borderColor)),
                                                      Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                                        child: Text("O", style: GoogleFonts.inter(color: textSecondary.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w800)),
                                                      ),
                                                      Expanded(child: Divider(color: borderColor)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 24),

                                                  SizedBox(
                                                    height: 58,
                                                    child: ElevatedButton(
                                                      onPressed: isLoading ? null : _loginWithGoogle,
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                                                        foregroundColor: textPrimary,
                                                        elevation: 0,
                                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(16),
                                                          side: BorderSide(color: borderColor),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Image.asset('assets/Google_Logo.png', height: 24, width: 24),
                                                          RichText(
                                                            text: TextSpan(
                                                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
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
                          ),
                          const SizedBox(height: 32),

                          FadeTransition(
                            opacity: fadeInputs,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "¿No tienes cuenta? ",
                                  style: GoogleFonts.inter(color: textSecondary, fontSize: 14),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(context, '/registrarupage', arguments: widget.invernaderoIdToJoin ?? _pendingInvernadero);
                                  },
                                  child: Text(
                                    "CREAR CUENTA",
                                    style: GoogleFonts.inter(
                                      color: AppColors.primary,
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
      },
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
    required bool isDark,
    required Color inputBg,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
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
      style: GoogleFonts.inter(fontSize: 16, color: textPrimary, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: textSecondary.withValues(alpha: 0.4), fontSize: 15),
        prefixIcon: Icon(icon, size: 20, color: textSecondary.withValues(alpha: 0.6)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: textSecondary.withValues(alpha: 0.6), size: 18),
                onPressed: onToggle,
              )
            : null,
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borderColor, width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borderColor, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5), width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.2)),
        errorStyle: GoogleFonts.inter(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w500),
      ),
      validator: validator,
    );
  }
}
