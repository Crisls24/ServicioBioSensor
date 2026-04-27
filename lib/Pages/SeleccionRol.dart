import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invernadero/Pages/RegistroInvernadero.dart';
import 'package:invernadero/Pages/HomePage.dart';
import 'package:invernadero/Pages/GestionInvernadero.dart';
import 'package:invernadero/core/theme/app_colors.dart';
import 'package:invernadero/core/theme/theme_notifier.dart';
import 'package:invernadero/Pages/InicioSesionPage.dart';

class SeleccionRol extends StatefulWidget {
  final String? invernaderoIdFromLink;
  final String appId;

  const SeleccionRol({
    super.key,
    this.invernaderoIdFromLink,
    required this.appId,
  });

  @override
  State<SeleccionRol> createState() => _SeleccionRolState();
}

class _SeleccionRolState extends State<SeleccionRol>
    with SingleTickerProviderStateMixin {
  final TextEditingController _invernaderoIdController =
      TextEditingController();
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier(false);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  bool _isJoiningFromLink = false;

  DocumentReference<Map<String, dynamic>> _getUserProfileRef(String uid) {
    return _firestore
        .collection('artifacts')
        .doc(widget.appId)
        .collection('public')
        .doc('data')
        .collection('usuarios')
        .doc(uid);
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
    _checkExistingRole();
  }

  void _checkExistingRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userRef = _getUserProfileRef(user.uid);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final rol = userData['rol'];

        if (rol != null && rol != 'pendiente' && rol.toString().isNotEmpty) {
          if (mounted) {
            if (rol == 'dueño') {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => Gestioninvernadero(appId: widget.appId)));
            } else {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HomePage(appId: widget.appId)));
            }
            return;
          }
        }
      }

      if (widget.invernaderoIdFromLink != null &&
          widget.invernaderoIdFromLink!.isNotEmpty) {
        setState(() {
          _isJoiningFromLink = true;
          _invernaderoIdController.text = widget.invernaderoIdFromLink!;
        });
        Future.delayed(const Duration(milliseconds: 800), () async {
          await _unirseAInvernadero(widget.invernaderoIdFromLink!,
              fromDeepLink: true);
        });
      }
    } catch (e) {
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _invernaderoIdController.dispose();
    _loadingNotifier.dispose();
    super.dispose();
  }

  Future<void> _unirseAInvernadero(String invernaderoId,
      {bool fromDeepLink = false}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userRef = _getUserProfileRef(user.uid);

      await userRef.set({
        'rol': 'empleado',
        'invernaderoId': invernaderoId,
      }, SetOptions(merge: true));

      if (mounted) {
        if (!fromDeepLink) {
          _showSnackBar('Te uniste correctamente al invernadero',
              Icons.check_circle, AppColors.primary);
        }
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomePage(appId: widget.appId)));
      }
    } catch (e) {
      _showSnackBar(
          'Error al unirse al invernadero', Icons.error, AppColors.error);
      if (mounted) setState(() => _isJoiningFromLink = false);
    }
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            themeNotifier.isDark ? AppColors.surfaceDark : Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: themeNotifier.isDark
                    ? AppColors.borderDark
                    : AppColors.borderLight)),
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: themeNotifier.isDark
                            ? AppColors.textMainDark
                            : AppColors.textMainLight,
                        fontWeight: FontWeight.w500))),
          ],
        ),
      ),
    );
  }

  void _showJoinDialog() {
    _invernaderoIdController.clear();
    final isDark = themeNotifier.isDark;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.getSurface(isDark),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.getBorder(isDark))),
          title: Text('Unirse a Invernadero',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: AppColors.getTextMain(isDark))),
          content: TextField(
            controller: _invernaderoIdController,
            style: GoogleFonts.inter(color: AppColors.getTextMain(isDark)),
            decoration: InputDecoration(
              hintText: 'Código de Acceso / ID',
              hintStyle:
                  GoogleFonts.inter(color: AppColors.getTextSecondary(isDark)),
              prefixIcon:
                  const Icon(Icons.vpn_key_rounded, color: AppColors.primary),
              filled: true,
              fillColor: isDark ? AppColors.bgDark : Colors.black12,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar',
                  style: GoogleFonts.inter(
                      color: AppColors.getTextSecondary(isDark))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _unirseAInvernadero(_invernaderoIdController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text('Unirse',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAdminRole() async {
    if (_isJoiningFromLink || currentUser == null) return;
    try {
      await _getUserProfileRef(currentUser!.uid)
          .set({'rol': 'pendiente'}, SetOptions(merge: true));
      if (mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => RegistroInvernaderoPage(appId: widget.appId)));
      }
    } catch (e) {
      _showSnackBar('Error al continuar', Icons.error, AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isJoiningFromLink) {
      return Scaffold(
        backgroundColor:
            themeNotifier.isDark ? AppColors.bgDark : AppColors.bgLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 24),
              Text("Uniéndote al invernadero...",
                  style: GoogleFonts.inter(
                      color: themeNotifier.isDark
                          ? AppColors.textMainDark
                          : AppColors.textMainLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, _) {
        final Color textMain = AppColors.getTextMain(isDark);
        final Color textSecondary = AppColors.getTextSecondary(isDark);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final doc = await _getUserProfileRef(user.uid).get();
              final rol = doc.data()?['rol'];
              if (rol == null || rol == 'pendiente')
                await FirebaseAuth.instance.signOut();
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.getBg(isDark),
            body: SafeArea(
              child: Stack(
                children: [
                  FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 40),
                          child: Column(
                            children: [
                              // Header
                              Column(
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.1),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          )
                                        ]),
                                    child: const Icon(Icons.eco_rounded,
                                        color: AppColors.primary, size: 36),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Selecciona tu Rol',
                                    style: GoogleFonts.inter(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: textMain,
                                        letterSpacing: -1),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Indica cómo deseas participar en el ecosistema BioSensor.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        color: textSecondary,
                                        height: 1.5),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 48),

                              // Role Cards
                              _RoleCard(
                                icon: Icons.admin_panel_settings_rounded,
                                title: 'Administrador',
                                subtitle:
                                    'Crea, configura y gestiona los sensores y cultivos de tu unidad.',
                                onTap: _handleAdminRole,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 16),
                              _RoleCard(
                                icon: Icons.groups_rounded,
                                title: 'Colaborador',
                                subtitle:
                                    'Únete a una unidad existente usando un código de invitación.',
                                onTap: _showJoinDialog,
                                isDark: isDark,
                              ),

                              const SizedBox(height: 60),
                              Text('BioSensor © 2025',
                                  style: GoogleFonts.inter(
                                      color:
                                          textSecondary.withValues(alpha: 0.3),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Botón de Regresar (Movido al final para estar encima de todo)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: IconButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => InicioSesion(appId: widget.appId)),
                          );
                        }
                      },
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: isDark ? Colors.white70 : AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDark;

  const _RoleCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap,
      required this.isDark});

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.getSurface(widget.isDark),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: AppColors.getBorder(widget.isDark), width: 1.2),
            boxShadow: [
              if (!widget.isDark)
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16)),
                child: Icon(widget.icon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: GoogleFonts.inter(
                            color: AppColors.getTextMain(widget.isDark),
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(widget.subtitle,
                        style: GoogleFonts.inter(
                            color: AppColors.getTextSecondary(widget.isDark),
                            fontSize: 13,
                            height: 1.4)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.getTextSecondary(widget.isDark)
                      .withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}
