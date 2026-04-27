import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:invernadero/Pages/SeleccionRol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invernadero/core/theme/app_colors.dart';
import 'package:invernadero/core/theme/theme_notifier.dart';

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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

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
    WidgetsBinding.instance.addObserver(this);
    
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _f1.addListener(_onFocusChange);
    _f2.addListener(_onFocusChange);
    _f3.addListener(_onFocusChange);
    _f4.addListener(_onFocusChange);
    
    _entranceCtrl.forward();
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
    _isFocused.value = _f1.hasFocus || _f2.hasFocus || _f3.hasFocus || _f4.hasFocus;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          backgroundColor: AppColors.primary,
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
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: GoogleFonts.inter(color: Colors.white)), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, _) {
        final Color background = AppColors.getBg(isDark);
        final Color textPrimary = AppColors.getTextMain(isDark);
        final Color textSecondary = AppColors.getTextSecondary(isDark);
        final Color cardColor = AppColors.getCardColor(isDark);
        final Color borderColor = AppColors.getBorder(isDark);
        final Color labelColor = AppColors.getLabel(isDark);
        final Color inputBg = AppColors.getInputBg(isDark);
        final double blurIntensity = isDark ? 4.5 : 2.0;

        final fadeHeader = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
        final slideHeader = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
            CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)));

        final fadeCard = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));
        final slideCard = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(
            CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)));

        return Scaffold(
          backgroundColor: background,
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              // Glow Background (Optimizado)
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
                                  color: AppColors.primary.withValues(alpha: (isDark ? 0.08 : 0.05) * _glowCtrl.value),
                                  blurRadius: 120,
                                  spreadRadius: 15,
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
                                  color: AppColors.primary.withValues(alpha: (isDark ? 0.05 : 0.03) * (1 - _glowCtrl.value)),
                                  blurRadius: 100,
                                  spreadRadius: 10,
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

              // Back Button
              Positioned(
                top: 50,
                left: 20,
                child: FadeTransition(
                  opacity: fadeHeader,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: isDark ? Colors.white70 : AppColors.primary,
                      size: 24,
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: Column(
                        children: [
                          FadeTransition(
                            opacity: fadeHeader,
                            child: SlideTransition(
                              position: slideHeader,
                              child: Column(
                                children: [
                                  Text(
                                    "ÚNETE A BIOSENSOR",
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 4),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Crear Cuenta",
                                    style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: -1.2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Glass Card
                          FadeTransition(
                            opacity: fadeCard,
                            child: SlideTransition(
                              position: slideCard,
                              child: RepaintBoundary(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: ValueListenableBuilder<bool>(
                                    valueListenable: _isFocused,
                                    builder: (context, focused, child) {
                                      return BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: focused ? 0 : blurIntensity, sigmaY: focused ? 0 : blurIntensity),
                                        child: child!,
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Form(
                                        key: _formKey,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            _buildLabel("INFORMACIÓN PERSONAL", labelColor),
                                            _buildTextField(
                                              ctrl: nameCtrl,
                                              focus: _f1,
                                              hint: "Nombre completo",
                                              icon: Icons.person_rounded,
                                              isDark: isDark,
                                              inputBg: inputBg,
                                              textPrimary: textPrimary,
                                              textSecondary: textSecondary,
                                              borderColor: borderColor,
                                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                                            ),
                                            const SizedBox(height: 18),
                                            _buildLabel("DATOS DE ACCESO", labelColor),
                                            _buildTextField(
                                              ctrl: emailCtrl,
                                              focus: _f2,
                                              hint: "Correo electrónico",
                                              icon: Icons.email_rounded,
                                              isDark: isDark,
                                              inputBg: inputBg,
                                              textPrimary: textPrimary,
                                              textSecondary: textSecondary,
                                              borderColor: borderColor,
                                              validator: (v) {
                                                if (v == null || v.trim().isEmpty) return 'El correo es requerido';
                                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'Correo no válido';
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 18),
                                            _buildLabel("SEGURIDAD", labelColor),
                                            ValueListenableBuilder<bool>(
                                              valueListenable: obscure1,
                                              builder: (context, obs, _) => _buildTextField(
                                                ctrl: passCtrl,
                                                focus: _f3,
                                                hint: "Contraseña (min. 8 carac.)",
                                                icon: Icons.lock_rounded,
                                                isDark: isDark,
                                                inputBg: inputBg,
                                                textPrimary: textPrimary,
                                                textSecondary: textSecondary,
                                                borderColor: borderColor,
                                                isPass: true,
                                                obscure: obs,
                                                onToggle: () => obscure1.value = !obscure1.value,
                                                validator: (v) {
                                                  if (v == null || v.isEmpty) return 'Contraseña requerida';
                                                  if (v.length < 8) return 'Mínimo 8 caracteres';
                                                  return null;
                                                },
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            ValueListenableBuilder<bool>(
                                              valueListenable: obscure2,
                                              builder: (context, obs, _) => _buildTextField(
                                                ctrl: confirmCtrl,
                                                focus: _f4,
                                                hint: "Confirmar contraseña",
                                                icon: Icons.shield_rounded,
                                                isDark: isDark,
                                                inputBg: inputBg,
                                                textPrimary: textPrimary,
                                                textSecondary: textSecondary,
                                                borderColor: borderColor,
                                                isPass: true,
                                                obscure: obs,
                                                onToggle: () => obscure2.value = !obscure2.value,
                                                validator: (v) => v != passCtrl.text ? 'Las contraseñas no coinciden' : null,
                                              ),
                                            ),
                                            const SizedBox(height: 32),

                                            ValueListenableBuilder<bool>(
                                              valueListenable: isLoading,
                                              builder: (context, loading, _) => Container(
                                                height: 58,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(16),
                                                  boxShadow: [
                                                    if (!loading)
                                                      BoxShadow(
                                                        color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                                                        blurRadius: 15,
                                                        offset: const Offset(0, 8),
                                                      ),
                                                  ],
                                                ),
                                                child: ElevatedButton(
                                                  onPressed: loading ? null : _register,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppColors.primary,
                                                    foregroundColor: Colors.white,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  ),
                                                  child: loading
                                                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                                      : Text("CREAR CUENTA", style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
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
                          ),
                          const SizedBox(height: 30),

                          FadeTransition(
                            opacity: fadeCard,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("¿Ya tienes cuenta? ", style: GoogleFonts.inter(color: textSecondary, fontSize: 14)),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Text("INICIAR SESIÓN", style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 13)),
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
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 1.2)),
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
    bool isPass = false,
    bool obscure = false,
    VoidCallback? onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      focusNode: focus,
      obscureText: obscure,
      style: GoogleFonts.inter(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: textSecondary.withValues(alpha: 0.4), fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: textSecondary.withValues(alpha: 0.6)),
        suffixIcon: isPass ? IconButton(icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: textSecondary.withValues(alpha: 0.5), size: 18), onPressed: onToggle) : null,
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.2)),
        errorStyle: GoogleFonts.inter(color: AppColors.error, fontSize: 11),
      ),
      validator: validator,
    );
  }
}
