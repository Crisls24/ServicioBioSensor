import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Paleta Startup Premium (Minimalista & Elegante) ─────────────────────────
const _bg = Color(0xFF0A0A0A); // Negro mate profundo
const _surface = Color(0xFF141414);
const _accent = Color(0xFFE2E2E2); // Blanco roto/plata para acentos sobrios
const _textPrim = Color(0xFFF9F9F9);
const _textSub = Color(0xFF888888);
const _glowColor =
    Color(0xFF00C853); // Verde esmeralda suave para el brillo de fondo

// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  final Future<Widget> initializationTask;

  const SplashScreen({super.key, required this.initializationTask});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Animaciones de entrada y loop continuo
  late AnimationController _glowCtrl;
  late Animation<double> _glowScale;
  late Animation<double> _glowOpacity;

  late AnimationController _logoCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  late AnimationController _textCtrl;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  // Animación Success Pulse
  late AnimationController _successCtrl;
  late Animation<double> _successScale;

  // Animación de salida (Exit)
  late AnimationController _exitCtrl;
  late Animation<double> _exitScale;
  late Animation<double> _exitOpacity;

  // Textos dinámicos
  String _statusText = "Iniciando sistema...";
  bool _isSuccess = false;
  Timer? _statusTimer;

  final List<String> _loadingMessages = [
    "Verificando entorno...",
    "Estableciendo conexión segura...",
    "Sincronizando datos...",
    "Validando sesión..."
  ];
  int _msgIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: _bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    _buildAnimations();
    _startSequence();
  }

  void _buildAnimations() {
    // 1. Resplandor (Glow) de fondo que respira suavemente
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _glowScale = Tween<double>(begin: 0.85, end: 1.1).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOutSine));
    _glowOpacity = Tween<double>(begin: 0.1, end: 0.25).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOutSine));

    // 2. Logo Entrada (Rápida y elástica)
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _logoScale = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));

    // 3. Texto
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    // 4. Success Pulse (Se lanza cuando se resuelve la inicialización)
    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _successScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.05)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 1.05, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInCubic)),
          weight: 70),
    ]).animate(_successCtrl);

    // 5. Exit Transition (Zoom lento + Desvanecimiento a fondo oscuro)
    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _exitScale = Tween<double>(begin: 1.0, end: 1.25)
        .animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInCubic));
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _exitCtrl, curve: Curves.easeOutQuart));
  }

  Future<void> _startSequence() async {
    // Evitar parpadeos: arrancar animaciones casi de inmediato
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    _logoCtrl.forward();

    // Iniciar el ciclo de textos de carga
    _statusTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted && !_isSuccess) {
        setState(() {
          _statusText = _loadingMessages[_msgIndex % _loadingMessages.length];
          _msgIndex++;
        });
      }
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) _textCtrl.forward();

    // Sincronización crucial:
    // Aseguramos un mínimo de tiempo para apreciar el splash
    final minimumWait = Future.delayed(const Duration(milliseconds: 5400));

    try {
      final results = await Future.wait([
        widget.initializationTask,
        minimumWait,
      ]);

      final Widget nextPage = results[0] as Widget;
      if (!mounted) return;
      _triggerSuccessAndNavigate(nextPage);
    } catch (e) {
      debugPrint("Error en inicialización: $e");
    }
  }

  void _triggerSuccessAndNavigate(Widget nextPage) async {
    _statusTimer?.cancel();
    setState(() {
      _isSuccess = true;
      _statusText = "Listo";
    });

    // 1. Success Pulse
    await _successCtrl.forward();

    // 2. Exit Transition (Zoom + Fade out paulatino)
    _glowCtrl.stop();
    _exitCtrl.forward();

    // Esperamos a que la imagen se haya desvanecido casi por completo (esconde los tirones de Flutter)
    await Future.delayed(const Duration(milliseconds: 1000));

    // 3. Empujar la siguiente página cuando la pantalla ya está oscura y tranquila
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration:
              const Duration(milliseconds: 600), // Fade in de la nueva app
          pageBuilder: (_, __, ___) => nextPage,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity:
                  CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _glowCtrl.dispose();
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _successCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    const logoR = 75.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _bg,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: AnimatedBuilder(
          animation: _exitCtrl,
          builder: (context, child) {
            // Capa maestra de salida (Zoom + FadeOut a color base)
            return Transform.scale(
              scale: _exitScale.value,
              child: Opacity(
                opacity: _exitOpacity.value,
                child: child,
              ),
            );
          },
          child: Stack(
            children: [
              // Brillo de fondo (Glow) detrás del logo
              Positioned(
                left: 0,
                right: 0,
                top: sh * 0.38 - 150,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _glowCtrl,
                    builder: (_, __) {
                      return Transform.scale(
                        scale: _glowScale.value,
                        child: Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    _glowColor.withOpacity(_glowOpacity.value),
                                blurRadius: 100,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Logo Central
              Positioned(
                left: 0,
                right: 0,
                top: sh * 0.38 - logoR,
                child: Center(
                  child: SizedBox(
                    width: logoR * 2,
                    height: logoR * 2,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Logo Principal + Success Pulse
                        AnimatedBuilder(
                          animation: _successCtrl,
                          builder: (_, child) {
                            return Transform.scale(
                              scale: _successScale.value,
                              child: child,
                            );
                          },
                          child: FadeTransition(
                            opacity: _logoOpacity,
                            child: ScaleTransition(
                              scale: _logoScale,
                              child: Container(
                                width: logoR * 2,
                                height: logoR * 2,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _surface,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(24),
                                child: Image.asset(
                                  'assets/Invernadero.png',
                                  fit: BoxFit.contain,
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

              // Texto y subtítulo
              Positioned(
                left: 32,
                right: 32,
                top: sh * 0.38 + logoR + 24,
                child: SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'BioSensor',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            color: _textPrim,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Monitoreo Inteligente',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: _textSub,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Indicador dinámico en la base (Startup Style)
              Positioned(
                left: 40,
                right: 40,
                bottom: sh * 0.08,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Loading indicator elegante
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _isSuccess ? 0.0 : 1.0,
                        child: const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(_accent),
                          ),
                        ),
                      ),
                      SizedBox(height: _isSuccess ? 0 : 12),

                      // Texto de status que se actualiza suavemente
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: child,
                        ),
                        child: Text(
                          _statusText,
                          key: ValueKey(_statusText),
                          style: GoogleFonts.inter(
                            color: _isSuccess ? _accent : _textSub,
                            fontSize: 12,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
