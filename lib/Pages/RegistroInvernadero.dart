import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invernadero/Pages/HomePage.dart';
import 'package:invernadero/core/theme/app_colors.dart';
import 'package:invernadero/core/theme/theme_notifier.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class RegistroInvernaderoPage extends StatefulWidget {
  final String appId;

  const RegistroInvernaderoPage({super.key, required this.appId});

  @override
  State<RegistroInvernaderoPage> createState() =>
      _RegistroInvernaderoPageState();
}

class _RegistroInvernaderoPageState extends State<RegistroInvernaderoPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _ubicacionController = TextEditingController();
  final _superficieController = TextEditingController();

  final ValueNotifier<bool> _loadingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isLocating = ValueNotifier(false);
  final ValueNotifier<bool> _isInputFocused = ValueNotifier(false);

  final FocusNode _fNombre = FocusNode();
  final FocusNode _fUbicacion = FocusNode();
  final FocusNode _fSuperficie = FocusNode();

  final ValueNotifier<String> _namePreview = ValueNotifier('Mi Invernadero');
  final ValueNotifier<String> _locationPreview = ValueNotifier('Ubicación');
  final ValueNotifier<String> _sizePreview = ValueNotifier('0.00');

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOpacity = ValueNotifier(0.0);

  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _nombreController.addListener(() {
      _namePreview.value = _nombreController.text.isEmpty
          ? 'Mi Invernadero'
          : _nombreController.text;
    });
    _ubicacionController.addListener(() {
      _locationPreview.value = _ubicacionController.text.isEmpty
          ? 'Ubicación'
          : _ubicacionController.text;
    });
    _superficieController.addListener(() {
      _sizePreview.value = _superficieController.text.isEmpty
          ? '0.00'
          : _superficieController.text;
    });

    _fNombre.addListener(_handleFocus);
    _fUbicacion.addListener(_handleFocus);
    _fSuperficie.addListener(_handleFocus);

    _scrollController.addListener(() {
      double opacity = (_scrollController.offset / 80).clamp(0.0, 1.0);
      _scrollOpacity.value = opacity;
    });
  }

  void _handleFocus() {
    _isInputFocused.value =
        _fNombre.hasFocus || _fUbicacion.hasFocus || _fSuperficie.hasFocus;
    setState(() {});
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _ubicacionController.dispose();
    _superficieController.dispose();
    _fNombre.dispose();
    _fUbicacion.dispose();
    _fSuperficie.dispose();
    _loadingNotifier.dispose();
    _isLocating.dispose();
    _isInputFocused.dispose();
    _namePreview.dispose();
    _locationPreview.dispose();
    _sizePreview.dispose();
    _scrollController.dispose();
    _scrollOpacity.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    _isLocating.value = true;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar("Por favor activa el GPS", Icons.location_off_rounded,
            Colors.orange);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar(
              "Permiso de ubicación denegado", Icons.error_outline, Colors.red);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar(
          "Permisos bloqueados",
          Icons.settings_rounded,
          Colors.red,
          actionLabel: "AJUSTES",
          onAction: () => Geolocator.openAppSettings(),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String city = place.locality ?? place.subAdministrativeArea ?? '';
        String state = place.administrativeArea ?? '';
        _ubicacionController.text = (city.isNotEmpty && state.isNotEmpty)
            ? "$city, $state"
            : (city.isNotEmpty ? city : state);
        _showSnackBar(
            "Ubicación lista", Icons.check_circle_rounded, AppColors.primary);
      }
    } catch (e) {
      String msg = "Error al obtener ubicación";
      if (e is LocationServiceDisabledException)
        msg = "El GPS está desactivado";
      _showSnackBar(msg, Icons.error_outline, Colors.red,
          actionLabel: "AJUSTES",
          onAction: () => Geolocator.openLocationSettings());
    } finally {
      _isLocating.value = false;
    }
  }

  Future<void> _registrarInvernadero() async {
    if (!_formKey.currentState!.validate()) return;
    if (currentUser == null) return;

    _loadingNotifier.value = true;
    try {
      final nombre = _nombreController.text.trim();
      final ubicacion = _ubicacionController.text.trim();
      final superficieM2 =
          double.tryParse(_superficieController.text.trim()) ?? 0.0;

      final artifactsRef = FirebaseFirestore.instance
          .collection('artifacts')
          .doc(widget.appId)
          .collection('public')
          .doc('data');

      final docRef = await artifactsRef.collection('invernaderos').add({
        'nombre': nombre,
        'ubicacion': ubicacion,
        'superficie_m2': superficieM2,
        'ownerId': currentUser!.uid,
        'fechaCreacion': Timestamp.now(),
        'miembros': [currentUser!.uid],
      });

      await artifactsRef.collection('usuarios').doc(currentUser!.uid).set({
        'rol': 'dueño',
        'invernaderoId': docRef.id,
        'roleStatus': 'complete',
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomePage(appId: widget.appId)),
        );
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Icons.error_outline, Colors.red);
    } finally {
      if (mounted) _loadingNotifier.value = false;
    }
  }

  void _showSnackBar(String message, IconData icon, Color color,
      {String? actionLabel, VoidCallback? onAction}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            themeNotifier.isDark ? AppColors.surfaceDark : Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: AppColors.primary,
                onPressed: onAction!)
            : null,
        content: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: GoogleFonts.inter()))
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, _) {
        final background = AppColors.getBg(isDark);
        final textPrimary = AppColors.getTextMain(isDark);
        final textSecondary = AppColors.getTextSecondary(isDark);

        return Scaffold(
          backgroundColor: background,
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: ValueListenableBuilder2<double, bool>(
                first: _scrollOpacity,
                second: _isInputFocused,
                builder: (context, opacity, isFocused, _) {
                  // Desactivamos el blur si el teclado está abierto para ganar rendimiento
                  final double currentBlur = isFocused ? 0.0 : 10.0 * opacity;
                  return AppBar(
                    backgroundColor:
                        background.withValues(alpha: isFocused ? 1.0 : opacity),
                    elevation: 0,
                    flexibleSpace: (currentBlur > 0 && !isFocused)
                        ? ClipRRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                  sigmaX: currentBlur, sigmaY: currentBlur),
                              child: Container(color: Colors.transparent),
                            ),
                          )
                        : null,
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: textPrimary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: (opacity > 0.6 || isFocused)
                        ? Text("Configuración",
                            style: GoogleFonts.inter(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700))
                        : null,
                    centerTitle: true,
                  );
                }),
          ),
          body: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.paddingOf(context).top + 30, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Crea tu invernadero",
                    style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                        letterSpacing: -1.0)),
                const SizedBox(height: 16),
                RepaintBoundary(child: _buildPreviewCard()),
                const SizedBox(height: 24),
                RepaintBoundary(
                    child: _buildAccessibleFeatures(
                        isDark, textPrimary, textSecondary)),
                const SizedBox(height: 28),
                Text("Información básica",
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textPrimary)),
                const SizedBox(height: 16),
                RepaintBoundary(child: _buildForm(isDark)),
                const SizedBox(height: 32),
                RepaintBoundary(child: _buildSubmitButton(isDark)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, Color(0xFF008F3A)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("VISTA PREVIA",
                  style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
              const Icon(Icons.eco_rounded, color: Colors.white, size: 24),
            ],
          ),
          const SizedBox(height: 24),
          ValueListenableBuilder<String>(
            valueListenable: _namePreview,
            builder: (context, name, _) => Text(name,
                style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ValueListenableBuilder<String>(
                        valueListenable: _locationPreview,
                        builder: (context, loc, _) => Text(loc,
                            style: GoogleFonts.inter(
                                color: Colors.white70, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10)),
                child: ValueListenableBuilder<String>(
                  valueListenable: _sizePreview,
                  builder: (context, size, _) => Text("$size m²",
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibleFeatures(
      bool isDark, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Lo que obtendrás:",
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textPrimary)),
          const SizedBox(height: 12),
          _accessibleBullet("Monitoreo de tus plantas las 24 horas",
              Icons.sensors_rounded, isDark),
          const SizedBox(height: 8),
          _accessibleBullet("Control total desde tu celular",
              Icons.psychology_rounded, isDark),
          const SizedBox(height: 8),
          _accessibleBullet("Historial de lo que sucede en tu cultivo",
              Icons.bar_chart_rounded, isDark),
        ],
      ),
    );
  }

  Widget _accessibleBullet(String text, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextSecondary(isDark)))),
      ],
    );
  }

  Widget _buildForm(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildSaaSTextField(
            controller: _nombreController,
            focusNode: _fNombre,
            label: "Nombre del Invernadero",
            hint: "Ej. Mi Cultivo",
            icon: Icons.store_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: 18),
          _buildSaaSTextField(
            controller: _ubicacionController,
            focusNode: _fUbicacion,
            label: "Ubicación",
            hint: "Ciudad, Estado",
            icon: Icons.map_rounded,
            isDark: isDark,
            helper: "Detección automática de ciudad",
            action: ValueListenableBuilder<bool>(
              valueListenable: _isLocating,
              builder: (context, loading, _) => SizedBox(
                height: 30,
                child: loading
                    ? const Center(
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary)))
                    : TextButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.my_location_rounded,
                            size: 14, color: AppColors.primary),
                        label: Text("Mi ubicación",
                            style: GoogleFonts.inter(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _buildSaaSTextField(
            controller: _superficieController,
            focusNode: _fSuperficie,
            label: "Superficie Estimada",
            hint: "0.00",
            icon: Icons.square_foot_rounded,
            isDark: isDark,
            suffixText: "m²",
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            formatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaaSTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    Widget? action,
    String? suffixText,
    String? helper,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? formatters,
  }) {
    final bool hasFocus = focusNode.hasFocus;
    final Color cardColor = AppColors.getCardColor(isDark);
    final Color textPrimary = AppColors.getTextMain(isDark);
    final Color textSecondary = AppColors.getTextSecondary(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color:
                    hasFocus ? AppColors.primary : AppColors.getBorder(isDark),
                width: hasFocus ? 1.5 : 1),
            boxShadow: [
              if (hasFocus)
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              else
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.01),
                    blurRadius: 2,
                    offset: const Offset(0, 1)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasFocus
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : textSecondary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon,
                    color: hasFocus
                        ? AppColors.primary
                        : textSecondary.withValues(alpha: 0.6),
                    size: hasFocus ? 26 : 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: textSecondary.withValues(alpha: 0.6))),
                    TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      keyboardType: keyboard,
                      inputFormatters: formatters,
                      style: GoogleFonts.inter(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: GoogleFonts.inter(
                            color: textSecondary.withValues(alpha: 0.3),
                            fontSize: 15,
                            fontWeight: FontWeight.w400),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.only(top: 2, bottom: 2),
                        suffixText: suffixText,
                        suffixStyle: GoogleFonts.inter(
                            color: textSecondary, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) action,
            ],
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Text(helper,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: textSecondary.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return ValueListenableBuilder<bool>(
      valueListenable: _loadingNotifier,
      builder: (context, isLoading, _) {
        return Container(
          height: 60,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (!isLoading)
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8))
            ],
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : _registrarInvernadero,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 0),
            child: isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3))
                : Text("Crear invernadero",
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
          ),
        );
      },
    );
  }
}

// Helper para escuchar dos notificadores a la vez
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
    this.child,
  });

  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext context, A a, B b, Widget? child) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<A>(
        valueListenable: first,
        builder: (_, a, __) => ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (context, b, child) => builder(context, a, b, child),
          child: child,
        ),
      );
}
