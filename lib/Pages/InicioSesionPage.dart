import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart'; // Añadido
import 'package:invernadero/Pages/SeleccionRol.dart';
import 'package:invernadero/Pages/GestionInvernadero.dart';
import 'package:invernadero/Pages/HomePage.dart';

class InicioSesion extends StatefulWidget {
  final String? invernaderoIdToJoin; // ID recibido desde el link de invitación
  final String appId;

  const InicioSesion({
    super.key,
    this.invernaderoIdToJoin,
    required this.appId,
  });

  @override
  State<InicioSesion> createState() => _InicioSesionState();
}

class _InicioSesionState extends State<InicioSesion> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier(false);
  bool _obscure = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _pendingInvernadero;

  late AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _entranceCtrl.forward();
    _loadPendingInvernadero();
  }

  /// Devuelve la referencia completa al documento de perfil del usuario.
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
    setState(() {
      _pendingInvernadero = saved;
    });
    if (saved != null) {
      debugPrint('Cargado pendingInvernaderoId: $saved');
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _loadingNotifier.dispose();
    super.dispose();
  }

  // Iniciar sesión con email y contraseña
  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint(' Validación fallida: Campos vacíos detectados.');
      return;
    }

    _loadingNotifier.value = true;
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCredential.user;
      if (user != null) {
        debugPrint(' Sesión iniciada localmente para ${user.email}');
        await _navigateAfterLogin(user);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage =
          'Error al iniciar sesión. Verifica tu correo y contraseña.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        errorMessage = 'Credenciales inválidas. Revisa tu correo y contraseña.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Tu cuenta ha sido deshabilitada.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo electrónico es incorrecto.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error desconocido: $e')),
        );
      }
    } finally {
      if (mounted) _loadingNotifier.value = false;
    }
  }

  //  Iniciar sesión con Google
  Future<void> _loginWithGoogle() async {
    _loadingNotifier.value = true;
    try {
      await _googleSignIn.signOut(); // limpia sesión previa
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final savedInvernadero =
            widget.invernaderoIdToJoin ?? _pendingInvernadero;
        final userRef = _getUserProfileRef(user.uid);
        final doc = await userRef.get();

        // Si es nuevo usuario, lo creamos
        if (!doc.exists) {
          await userRef.set({
            'uid': user.uid,
            'email': user.email,
            'nombre': user.displayName,
            // Si hay link, se une como empleado, si no, queda pendiente para SeleccionRol
            'invernaderoId': savedInvernadero ?? '',
            'fechaRegistro': FieldValue.serverTimestamp(),
            'rol': savedInvernadero != null ? 'empleado' : 'pendiente',
          });

          debugPrint('Nuevo usuario creado con Google: ${user.email}');
        }

        debugPrint(' Sesión iniciada con Google para ${user.email}');
        await _navigateAfterLogin(user);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error con Google: $e')),
        );
      }
    } finally {
      if (mounted) _loadingNotifier.value = false;
    }
  }

  // Decide a dónde redirigir después del login
  Future<void> _navigateAfterLogin(User user) async {
    final docRef = _getUserProfileRef(user.uid);
    final doc = await docRef.get();
    final data = doc.data() ?? {};
    // Limpieza de caché de invitación pendiente al iniciar sesión
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pendingInvernaderoId');

    final String normalizedRol = (data['rol'] as String?)?.toLowerCase() ?? '';
    final String invernaderoIdExistente = (data['invernaderoId'] as String?) ??
        (data['greenhouseId'] as String?) ??
        '';
    final String? invernaderoToJoin =
        widget.invernaderoIdToJoin?.isNotEmpty == true
            ? widget.invernaderoIdToJoin
            : _pendingInvernadero;

    debugPrint(
        ' LOGIN_NAV → rol=$normalizedRol, invernaderoExistente=$invernaderoIdExistente');
    debugPrint(' LOGIN_NAV → invernaderoToJoin=$invernaderoToJoin');

    // Si vino desde link de invitación (prioridad alta)
    if (invernaderoToJoin != null && invernaderoToJoin.isNotEmpty) {
      debugPrint('📩 Usuario vino desde link ($invernaderoToJoin)');

      // Si ya tiene el rol y es del mismo invernadero, va a Home
      if (normalizedRol == 'empleado' &&
          invernaderoIdExistente == invernaderoToJoin) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomePage(appId: widget.appId)));
        return;
      }

      // Si no tiene rol (o es pendiente), va a Selección de Rol para procesar la invitación
      if (normalizedRol.isEmpty || normalizedRol == 'pendiente') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SeleccionRol(
              invernaderoIdFromLink: invernaderoToJoin,
              appId: widget.appId,
            ),
          ),
        );
        return;
      }

      // Si es dueño (siempre tiene prioridad), va a Gestión
      if (normalizedRol == 'dueño') {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => Gestioninvernadero(appId: widget.appId)));
        return;
      }
    }

    // Flujo normal (sin link)
    if (normalizedRol.isEmpty || normalizedRol == 'pendiente') {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => SeleccionRol(appId: widget.appId)));
      return;
    }

    if (normalizedRol == 'dueño') {
      if (invernaderoIdExistente.isNotEmpty) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => Gestioninvernadero(appId: widget.appId)));
      } else {
        Navigator.pushReplacementNamed(context, '/registrarinvernadero');
      }
      return;
    }

    if (normalizedRol == 'empleado') {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => HomePage(appId: widget.appId)));
      return;
    }
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => SeleccionRol(appId: widget.appId)));
  }

  @override
  Widget build(BuildContext context) {
    // ─── Paleta Startup Vibrante y Profesional ───
    const Color bg = Color(0xFFF9FAFB);
    const Color textMain = Color(0xFF111827);
    const Color textSub = Color(0xFF6B7280);
    const Color inputBg = Colors.white;
    const Color brandGreen = Color(0xFF00C853); // Verde esmeralda vibrante (el mismo del Splash)
    const Color borderCol = Color(0xFFE5E7EB);

    // Animaciones Staggered (Escalonadas)
    final fadeHeader = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));
    final slideHeader = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)));

    final fadeInputs = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.2, 0.6, curve: Curves.easeOut)));
    final slideInputs = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic)));

    final fadeButtons = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.4, 0.8, curve: Curves.easeOut)));
    final slideButtons = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic)));

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Alerta de Invitación (si aplica)
                        if (widget.invernaderoIdToJoin != null || _pendingInvernadero != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 32),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD1FAE5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.mark_email_read_outlined, color: Color(0xFF059669), size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Has sido invitado a un invernadero. Inicia sesión para unirte.',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF065F46),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Encabezado
                        FadeTransition(
                          opacity: fadeHeader,
                          child: SlideTransition(
                            position: slideHeader,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: brandGreen.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.eco_rounded, color: brandGreen, size: 42),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  "Iniciar Sesión",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: textMain,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Bienvenido de vuelta a BioSensor",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: textSub,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Campos de Texto
                        FadeTransition(
                          opacity: fadeInputs,
                          child: SlideTransition(
                            position: slideInputs,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                        Text(
                          "Correo electrónico",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            style: GoogleFonts.inter(color: textMain, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'ejemplo@correo.com',
                              hintStyle: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 15),
                              filled: true,
                              fillColor: inputBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: borderCol, width: 1.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: borderCol, width: 1.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: brandGreen, width: 2.0),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El correo es obligatorio';
                              }
                              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                              if (!emailRegex.hasMatch(value.trim())) {
                                return 'Usa un formato válido (ej. hola@biosensor.com)';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Campo de Contraseña
                        Text(
                          "Contraseña",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textMain,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _loginUser(), // Enter hace login
                            style: GoogleFonts.inter(color: textMain, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              hintStyle: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 15),
                              filled: true,
                              fillColor: inputBg,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: textSub,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: borderCol, width: 1.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: borderCol, width: 1.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: brandGreen, width: 2.0),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'La contraseña es obligatoria';
                              }
                              if (value.length < 8) {
                                return 'Debe tener al menos 8 caracteres';
                              }
                              if (!value.contains(RegExp(r'[A-Za-z]')) || !value.contains(RegExp(r'[0-9]'))) {
                                return 'Debe contener letras y números';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 36),
                              ],
                            ),
                          ),
                        ),

                        // Botones de Acción
                        FadeTransition(
                          opacity: fadeButtons,
                          child: SlideTransition(
                            position: slideButtons,
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _loadingNotifier,
                              builder: (context, isLoading, _) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                // Botón Principal
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _loginUser,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: brandGreen,
                                      foregroundColor: Colors.white,
                                      elevation: 8,
                                      shadowColor: brandGreen.withOpacity(0.5),
                                      disabledBackgroundColor: brandGreen.withOpacity(0.6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.0,
                                            ),
                                          )
                                        : Text(
                                            'Continuar',
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Separador
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: borderCol)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        "O",
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFD1D5DB),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: borderCol)),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Botón de Google Estilo Startup
                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _loginWithGoogle,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: textMain,
                                      elevation: 1,
                                      shadowColor: Colors.black12,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: const BorderSide(color: borderCol, width: 1.0),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                          children: const [
                                            TextSpan(text: 'Continuar con '),
                                            TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w700, fontSize: 16)),
                                            TextSpan(text: 'o', style: TextStyle(color: Color(0xFFEA4335), fontWeight: FontWeight.w700, fontSize: 16)),
                                            TextSpan(text: 'o', style: TextStyle(color: Color(0xFFFBBC05), fontWeight: FontWeight.w700, fontSize: 16)),
                                            TextSpan(text: 'g', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w700, fontSize: 16)),
                                            TextSpan(text: 'l', style: TextStyle(color: Color(0xFF34A853), fontWeight: FontWeight.w700, fontSize: 16)),
                                            TextSpan(text: 'e', style: TextStyle(color: Color(0xFFEA4335), fontWeight: FontWeight.w700, fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Enlace de Registro
                        FadeTransition(
                          opacity: fadeButtons,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "¿No tienes una cuenta? ",
                                style: GoogleFonts.inter(color: textSub, fontSize: 14),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/registrarupage',
                                    arguments: widget.invernaderoIdToJoin ?? _pendingInvernadero,
                                  );
                                },
                                child: Text(
                                  "Crear cuenta",
                                  style: GoogleFonts.inter(
                                    color: brandGreen,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
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
    );
  }
}
