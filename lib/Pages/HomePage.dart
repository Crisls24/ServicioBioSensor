import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:invernadero/Pages/RegistrarCultivosPage.dart';
import 'package:invernadero/Pages/SideNav.dart';
import 'package:invernadero/Pages/RegistroInvernadero.dart';
import 'dart:developer';
import 'dart:async';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:invernadero/core/theme/app_colors.dart';
import 'package:invernadero/core/theme/theme_notifier.dart';
import 'package:invernadero/core/state/greenhouse_state_notifier.dart';
import 'package:invernadero/core/services/sensor_analysis_service.dart';
import 'package:invernadero/Pages/components/GlobalStatusBanner.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _firestore = FirebaseFirestore.instance;
final FirebaseDatabase _database = FirebaseDatabase.instance;

// FUNCION AUXILIAR DE REFERENCIA (Colección por Niveles)
CollectionReference _getPublicCollectionRef(
    String appId, String collectionName) {
  return _firestore
      .collection('artifacts')
      .doc(appId)
      .collection('public')
      .doc('data')
      .collection(collectionName);
}

// HOME PAGE
class HomePage extends StatefulWidget {
  final String appId;
  const HomePage({super.key, required this.appId});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? currentUser = _auth.currentUser;
  String? _currentInvernaderoId;
  bool _isLoading = true;

  CollectionReference get _invernaderosCollectionRef =>
      _getPublicCollectionRef(widget.appId, 'invernaderos');
  CollectionReference get _cultivosCollectionRef =>
      _getPublicCollectionRef(widget.appId, 'cultivos');
  CollectionReference get _usuariosCollectionRef =>
      _getPublicCollectionRef(widget.appId, 'usuarios');

  // Colores dinámicos ahora se manejan vía AppColors

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _fetchUserInvernaderoId().then((fetchedId) {
        if (mounted) {
          setState(() {
            _currentInvernaderoId = fetchedId;
            _isLoading = false;
          });
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  // Obtener ID de invernadero activo
  Future<String?> _fetchUserInvernaderoId() async {
    if (currentUser == null) return null;

    try {
      final userDoc = await _usuariosCollectionRef.doc(currentUser!.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        final String? userInvernaderoId = data?['invernaderoId'] as String?;
        if (userInvernaderoId != null && userInvernaderoId.isNotEmpty) {
          log("ID de Invernadero ACTIVO encontrado: $userInvernaderoId",
              name: 'InvernaderoID');
          return userInvernaderoId;
        }
      }

      QuerySnapshot snapshot = await _invernaderosCollectionRef
          .where('ownerId', isEqualTo: currentUser!.uid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final ownerInvernaderoId = snapshot.docs.first.id;
        log("ID de Invernadero encontrado (Fallback): $ownerInvernaderoId",
            name: 'InvernaderoID');
        await _usuariosCollectionRef
            .doc(currentUser!.uid)
            .update({'invernaderoId': ownerInvernaderoId});
        return ownerInvernaderoId;
      }
      return null;
    } catch (e) {
      log("Error al obtener ID del invernadero: $e",
          name: 'InvernaderoID Error');
      return null;
    }
  }

  // Navegar para añadir cultivo
  void _handleButtonAction() {
    final String? invernaderoId = _currentInvernaderoId;
    if (invernaderoId != null && invernaderoId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CultivoPage(
                  invernaderoId: invernaderoId,
                  appId: widget.appId,
                )),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => RegistroInvernaderoPage(
                  appId: widget.appId,
                )),
      );
    }
  }

  void _showCriticalAlert(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
                child: Text("ALERTA CRÍTICA: $message",
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Pantalla de Carga
    if (_isLoading) {
      return ValueListenableBuilder<bool>(
        valueListenable: themeNotifier,
        builder: (context, isDark, _) => Scaffold(
          backgroundColor: AppColors.getBg(isDark),
          body: const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      );
    }

    final String? invernaderoId = _currentInvernaderoId;
    final bool isReady = invernaderoId != null && invernaderoId.isNotEmpty;

    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, _) {
        final background = AppColors.getBg(isDark);
        final textPrimary = AppColors.getTextMain(isDark);
        final primaryGreen = AppColors.primary;

        return Scaffold(
          backgroundColor: background,
          appBar: AppBar(
            title: Text('BioSensor',
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                    letterSpacing: -1)),
            backgroundColor: background,
            foregroundColor: primaryGreen,
            elevation: 0,
            actions: const [
              SizedBox(width: 8),
            ],
          ),
          drawer:
              Drawer(child: SideNav(currentRoute: 'home', appId: widget.appId)),
          body: ValueListenableBuilder<GreenhouseData>(
            valueListenable: greenhouseState,
            builder: (context, ghData, _) {
              // Lógica de Alerta Automática
              if (ghData.status == GreenhouseStatus.critical && isReady) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showCriticalAlert(context, ghData.statusMessage);
                });
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // --- NUEVO: BANNER DE ESTADO GLOBAL ---
                    if (isReady) const GlobalStatusBanner(),

                    // --- SECCIÓN 1: MI INVERNADERO ---
                    _MiInvernadero(
                        invernaderoId: invernaderoId,
                        onButtonPressed: _handleButtonAction,
                        isDark: isDark),

                    const SizedBox(height: 25),

                    // --- SECCIÓN 2: CULTIVOS ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cultivos Activos',
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: primaryGreen,
                                letterSpacing: -0.5)),
                        if (isReady)
                          TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => CultivoPage(
                                        appId: widget.appId,
                                        invernaderoId: invernaderoId!))),
                            child: Text("Ver todos",
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: primaryGreen)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isReady)
                      _CultivosCarousel(
                        invernaderoId: invernaderoId!,
                        cultivosRef: _cultivosCollectionRef,
                        isDark: isDark,
                        currentTemp: ghData.temp,
                        currentVpd: ghData.vpd,
                      )
                    else
                      _buildEmptyState(isDark),

                    const SizedBox(height: 35),

                    // --- SECCIÓN 3: MONITOREO EN TIEMPO REAL ---
                    Text('Monitoreo Ambiental',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: primaryGreen,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 18),
                    if (isReady)
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.88,
                        children: [
                          UniversalSensorChart(
                            invernaderoId: invernaderoId!,
                            sensorKey: 'temperatura',
                            label: 'Temperatura',
                            unit: '°C',
                            graphColor: Colors.orangeAccent,
                            icon: Icons.thermostat_rounded,
                          ),
                          UniversalSensorChart(
                            invernaderoId: invernaderoId!,
                            sensorKey: 'humedad',
                            label: 'Humedad',
                            unit: '%',
                            graphColor: Colors.blueAccent,
                            icon: Icons.water_drop_rounded,
                          ),
                          UniversalSensorChart(
                            invernaderoId: invernaderoId!,
                            sensorKey: 'luz_lumenes',
                            label: 'Iluminación',
                            unit: 'Lux',
                            graphColor: Colors.amber,
                            icon: Icons.wb_sunny_rounded,
                          ),
                          const VpdChart(),
                        ],
                      )
                    else
                      _buildMissingInvernadero(isDark),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMissingInvernadero(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getBorder(isDark)),
        boxShadow: AppColors.getShadow(isDark),
      ),
      child: Column(
        children: [
          Icon(Icons.dashboard_customize_rounded,
              size: 48, color: AppColors.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          Text(
            "Configuración Necesaria",
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.getTextMain(isDark)),
          ),
          const SizedBox(height: 8),
          Text(
            "Selecciona un invernadero activo para comenzar el monitoreo en tiempo real.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: AppColors.getTextSecondary(isDark),
                fontSize: 13,
                height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _handleButtonAction(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text("Registrar Invernadero",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getBorder(isDark)),
        boxShadow: AppColors.getShadow(isDark),
      ),
      child: Column(
        children: [
          Icon(Icons.eco_outlined,
              color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.3),
              size: 40),
          const SizedBox(height: 16),
          Text(
            'Sin cultivos registrados',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.getTextMain(isDark)),
          ),
          const SizedBox(height: 4),
          Text(
            'Comienza agregando tu primer cultivo para monitorear su salud.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: AppColors.getTextSecondary(isDark), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// CultivosCarousel (Componente de visualización)

class _CultivosCarousel extends StatelessWidget {
  final String invernaderoId;
  final CollectionReference cultivosRef;
  final bool isDark;
  final double currentTemp;
  final double currentVpd;

  const _CultivosCarousel({
    required this.invernaderoId,
    required this.cultivosRef,
    required this.isDark,
    this.currentTemp = 0.0,
    this.currentVpd = 0.0,
  });

  String _getAssetForCultivo(String nombre) {
    final n = nombre.toLowerCase();
    if (n.contains('jitomate') || n.contains('tomate'))
      return 'assets/jitomate.png';
    if (n.contains('pepino')) return 'assets/pepino.jpg';
    if (n.contains('lechuga')) return 'assets/lechuga.png';
    if (n.contains('pimiento') || n.contains('chile'))
      return 'assets/pimiento.jpg';
    if (n.contains('fresa')) return 'assets/fresa.jpg';
    return 'assets/default.jpg';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: cultivosRef
          .where('invernaderoId', isEqualTo: invernaderoId)
          .limit(5)
          .snapshots(),
      builder: (context, snapshotCultivos) {
        if (snapshotCultivos.hasError)
          return const Text('Error cargando cultivos');
        if (snapshotCultivos.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 180,
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)));
        }

        final docs = snapshotCultivos.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            height: 180,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.getCardColor(isDark),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.getBorder(isDark)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.grass_outlined,
                    color: AppColors.getTextSecondary(isDark), size: 32),
                const SizedBox(height: 12),
                Text('Sin cultivos activos',
                    style: GoogleFonts.inter(
                        color: AppColors.getTextSecondary(isDark),
                        fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        final String estadoCalculado =
            SensorAnalysisService.getCropStatus(currentVpd);

        return SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final nombre = data['cultivo'] ?? 'Cultivo';
              final variedad = data['variedad'] ?? '';
              final titulo = variedad.isNotEmpty ? "$nombre $variedad" : nombre;

              return CropCard(
                title: titulo,
                imageUrl: _getAssetForCultivo(nombre),
                estado: estadoCalculado,
                currentTemp: currentTemp,
                currentVpd: currentVpd,
              );
            },
          ),
        );
      },
    );
  }
}

// _MiInvernadero (Widget Auxiliar)
class _MiInvernadero extends StatelessWidget {
  const _MiInvernadero(
      {required this.invernaderoId,
      required this.onButtonPressed,
      required this.isDark});

  final String? invernaderoId;
  final VoidCallback onButtonPressed;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bool isReady = invernaderoId != null && invernaderoId!.isNotEmpty;
    final String mainText =
        isReady ? 'Mi Invernadero' : 'Configuración Pendiente';
    final String subText = isReady
        ? 'Gestión de Cultivos'
        : 'Debe seleccionar o registrar su invernadero.';
    final String buttonLabel = isReady ? 'Añadir Cultivo' : 'Registrar';

    final Color primaryGreen = AppColors.primary;

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorder(isDark)),
        boxShadow: AppColors.getShadow(isDark),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(mainText,
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: primaryGreen)),
              const SizedBox(height: 2),
              Text(subText,
                  style: GoogleFonts.inter(
                      color: isReady
                          ? AppColors.getTextSecondary(isDark)
                          : Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: onButtonPressed,
            icon: Icon(isReady ? Icons.grass_outlined : Icons.app_registration,
                size: 18),
            label: Text(buttonLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: isDark ? 0 : 4,
              textStyle:
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }
}

class CropCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String estado;
  final double currentTemp;
  final double currentVpd;

  const CropCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.estado,
    this.currentTemp = 0.0,
    this.currentVpd = 0.0,
  });

  Color _getStatusColor() {
    switch (estado) {
      case 'bien':
        return const Color(0xFF2ECC71);
      case 'vpd_alto':
        return Colors.redAccent;
      case 'vpd_bajo':
        return Colors.purpleAccent;
      case 'alerta_plaga':
        return Colors.red;
      default:
        return Colors.orangeAccent;
    }
  }

  IconData _getStatusIcon() {
    switch (estado) {
      case 'bien':
        return Icons.check_circle;
      case 'vpd_alto':
        return Icons.whatshot;
      case 'vpd_bajo':
        return Icons.cloud_off;
      case 'luz_baja':
        return Icons.wb_twilight;
      case 'alerta_plaga':
        return Icons.bug_report;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  String _getEstadoTexto() {
    switch (estado) {
      case 'bien':
        return 'Saludable';
      case 'vpd_alto':
        return 'Estrés Calor';
      case 'vpd_bajo':
        return 'Riesgo Hongo';
      case 'luz_baja':
        return 'Falta Luz';
      case 'alerta_plaga':
        return 'Plaga';
      default:
        return 'Revisar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final isDark = themeNotifier.isDark;

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => PlantDetailsDialog(
              title: title, imageUrl: imageUrl, estado: estado),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 160,
        margin: const EdgeInsets.only(right: 14, bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.getCardColor(isDark),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          boxShadow: AppColors.getShadow(isDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.asset(
                    imageUrl,
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(height: 110, color: Colors.grey[200]),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getStatusIcon(), color: color, size: 16),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: AppColors.getTextMain(isDark),
                        letterSpacing: -0.2),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Fila de datos pequeños
                  Row(
                    children: [
                      _smallData(Icons.thermostat,
                          "${currentTemp.toStringAsFixed(0)}°", isDark),
                      const SizedBox(width: 8),
                      _smallData(Icons.water_drop,
                          "${currentVpd.toStringAsFixed(1)}", isDark),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getEstadoTexto(),
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallData(IconData icon, String val, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 10, color: AppColors.getTextSecondary(isDark)),
        const SizedBox(width: 2),
        Text(val,
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.getTextSecondary(isDark))),
      ],
    );
  }
}

class PlantDetailsDialog extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String
      estado; // Recibe: 'vpd_bajo', 'vpd_alto', 'luz_baja', 'bien', etc.

  const PlantDetailsDialog({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.estado,
  });

  Map<String, dynamic> _getDiagnostico() {
    // Aquí traducimos el ESTADO del sensor a CIENCIA del cultivo
    switch (estado) {
      // CASOS DE VPD (Humedad/Temperatura)
      case 'vpd_bajo': // Equivale a humedad excesiva / moho
        return {
          'titulo': 'Transpiración Bloqueada (VPD Bajo)',
          'desc':
              'El aire está saturado (<0.4 kPa). La planta no puede evaporar agua ni absorber Calcio.',
          'riesgo': 'Alto riesgo de hongos (Botrytis) y necrosis en bordes.',
          'accion':
              'Aumentar ventilación inmediatamente o encender deshumidificador.',
          'color': Colors.purple, // Morado suele indicar hongos/humedad
          'icon': Icons.cloud_off
        };

      case 'vpd_alto': // Equivale a sequía / calor excesivo
        return {
          'titulo': 'Cierre de Estomas (VPD Alto)',
          'desc':
              'El ambiente es muy seco (>1.6 kPa). La planta ha cerrado sus poros para no deshidratarse.',
          'riesgo': 'Detención del crecimiento y quemaduras en hojas.',
          'accion':
              'Aumentar humedad relativa (nebulizar) o reducir temperatura.',
          'color': Colors.red,
          'icon': Icons.whatshot
        };

      case 'luz_baja':
        return {
          'titulo': 'Insuficiencia Lumínica',
          'desc':
              'La planta no está recibiendo fotones suficientes para la fotosíntesis óptima.',
          'riesgo': 'Crecimiento lento y tallos débiles (Etilación).',
          'accion': 'Revisar mallas sombra o encender iluminación de apoyo.',
          'color': Colors.amber,
          'icon': Icons.wb_twilight
        };

      case 'bien':
        return {
          'titulo': 'Entorno Óptimo',
          'desc':
              'Los niveles de VPD y Luz están en el rango ideal para este cultivo.',
          'riesgo': 'Crecimiento máximo y salud celular excelente.',
          'accion': 'Mantener los parámetros actuales.',
          'color': AppColors.primary,
          'icon': Icons.check_circle
        };

      default:
        return {
          'titulo': 'Estado Desconocido',
          'desc': 'No hay datos suficientes para un diagnóstico preciso.',
          'riesgo': 'N/A',
          'accion': 'Verificar conexión de sensores.',
          'color': Colors.grey,
          'icon': Icons.help_outline
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _getDiagnostico();
    final Color themeColor = info['color'];

    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, _) {
        final background = AppColors.getCardColor(isDark);
        final textMain = AppColors.getTextMain(isDark);
        final textSec = AppColors.getTextSecondary(isDark);

        return Dialog(
          backgroundColor: background,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Imagen de Cabecera
                Stack(
                  children: [
                    Image.asset(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          height: 180,
                          color: isDark ? Colors.grey[900] : Colors.grey[200]),
                    ),
                    Positioned.fill(
                      child: Container(
                        height: 60,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 20,
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              const Shadow(blurRadius: 4, color: Colors.black)
                            ]),
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Diagnóstico Principal
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child:
                                Icon(info['icon'], color: themeColor, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  info['titulo'],
                                  style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: themeColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Diagnóstico en tiempo real",
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: textSec,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Explicación Científica
                      Text("ANÁLISIS FISIOLÓGICO:",
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: textSec.withValues(alpha: 0.5),
                              letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text(info['desc'],
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              color: textMain,
                              height: 1.5,
                              fontWeight: FontWeight.w500)),

                      const SizedBox(height: 20),

                      // Riesgo (Solo si no está bien)
                      if (estado != 'bien') ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: const Border(
                                left:
                                    BorderSide(color: Colors.orange, width: 4)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 18, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(info['riesgo'],
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.orange[200]
                                              : Colors.orange[900],
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w500))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Acción Recomendada (Botón Grande)
                      if (estado != 'bien')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.engineering, size: 18),
                            label: Text(info['accion']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                              textStyle: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(
                                  color: AppColors.primary, width: 2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold),
                            ),
                            child: const Text("Todo en orden"),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class UniversalSensorChart extends StatefulWidget {
  final String invernaderoId;
  final String sensorKey;
  final String label;
  final Color graphColor;
  final String unit;
  final IconData icon;

  const UniversalSensorChart({
    super.key,
    required this.invernaderoId,
    required this.sensorKey,
    required this.label,
    required this.graphColor,
    required this.unit,
    this.icon = Icons.sensors,
  });

  @override
  State<UniversalSensorChart> createState() => _UniversalSensorChartState();
}

class _UniversalSensorChartState extends State<UniversalSensorChart> {
  final List<FlSpot> _spots = [];
  late StreamSubscription<DatabaseEvent> _stream;
  double _currentValue = 0.0;
  double _previousValue = 0.0;
  double _minY = 0;
  double _maxY = 100;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  void _setupStream() {
    final ref = FirebaseDatabase.instance.ref('sensores/data');

    _stream = ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) return;

      double newValue = 0.0;
      if (data is Map) {
        final rawValue = data[widget.sensorKey];
        newValue = double.tryParse(rawValue.toString()) ?? 0.0;
      }

      if (mounted) {
        setState(() {
          _previousValue = _currentValue;
          _currentValue = newValue;
          _isLoading = false;
          _spots.add(FlSpot(_spots.length.toDouble(), newValue));

          if (_spots.length > 30) {
            _spots.removeAt(0);
            for (int i = 0; i < _spots.length; i++) {
              _spots[i] = FlSpot(i.toDouble(), _spots[i].y);
            }
          }

          if (_spots.isNotEmpty) {
            final yValues = _spots.map((e) => e.y).toList();
            double min = yValues.reduce((a, b) => a < b ? a : b);
            double max = yValues.reduce((a, b) => a > b ? a : b);

            double margin = (max - min) * 0.2;
            if (margin < 2) margin = 5;
            _minY = (min - margin) < 0 ? 0 : (min - margin);
            _maxY = max + margin;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _stream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDark;
    final bool isRising = _currentValue > _previousValue;
    final bool isFalling = _currentValue < _previousValue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getBorder(isDark)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: widget.graphColor.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ENCABEZADO (Icono y Título)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.graphColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.graphColor, size: 18),
              ),
              // Tendencia
              if (!_isLoading)
                Icon(
                  isRising
                      ? Icons.trending_up
                      : (isFalling ? Icons.trending_down : Icons.trending_flat),
                  size: 16,
                  color: isRising
                      ? Colors.greenAccent
                      : (isFalling ? Colors.orangeAccent : Colors.grey),
                ),
            ],
          ),

          const SizedBox(height: 12),

          Expanded(
            child: Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.getTextSecondary(isDark),
              ),
            ),
          ),

          // VALOR GRANDE
          Text(
            '${_currentValue.toStringAsFixed(1)}${widget.unit}',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.getTextMain(isDark),
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          // GRÁFICA EXPANDIDA
          Expanded(
            flex: 2,
            child: _isLoading && _spots.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                        color: widget.graphColor, strokeWidth: 2))
                : LineChart(
                    LineChartData(
                      minY: _minY,
                      maxY: _maxY,
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _spots,
                          isCurved: true,
                          color: widget.graphColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                widget.graphColor.withValues(alpha: 0.15),
                                widget.graphColor.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
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
}

class VpdChart extends StatefulWidget {
  const VpdChart({super.key});

  @override
  State<VpdChart> createState() => _VpdChartState();
}

class _VpdChartState extends State<VpdChart> {
  final List<FlSpot> _spots = [];
  late StreamSubscription<DatabaseEvent> _stream;
  double _currentVpd = 0.0;

  // Colores según estado del VPD
  Color get _statusColor {
    if (_currentVpd < 0.4) return Colors.blue; // Muy húmedo
    if (_currentVpd > 1.6) return Colors.red; // Muy seco
    return Colors.green; // Óptimo
  }

  @override
  void initState() {
    super.initState();
    _setupVpdStream();
  }

  void _setupVpdStream() {
    final ref = FirebaseDatabase.instance.ref('sensores/data');

    _stream = ref.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        double temp = double.tryParse(data['temperatura'].toString()) ?? 0;
        double hum = double.tryParse(data['humedad'].toString()) ?? 0;

        // CÁLCULO CIENTÍFICO EXACTO (Ecuación de Tetens)
        double exponente = (17.27 * temp) / (temp + 237.3);
        double svp = 0.61078 * math.exp(exponente);
        double vpd = svp * (1 - (hum / 100));

        if (vpd < 0) vpd = 0;

        if (mounted) {
          setState(() {
            _currentVpd = vpd;
            _spots.add(FlSpot(_spots.length.toDouble(), vpd));
            if (_spots.length > 30) _spots.removeAt(0);
            for (int i = 0; i < _spots.length; i++) {
              _spots[i] = FlSpot(i.toDouble(), _spots[i].y);
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _stream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getBorder(isDark)),
        boxShadow: AppColors.getShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.water_drop_outlined,
                    color: _statusColor, size: 18),
              ),
              // Chip de estado pequeño
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentVpd < 0.4
                      ? "RIESGO"
                      : (_currentVpd > 1.6 ? "SECO" : "ÓPTIMO"),
                  style: GoogleFonts.inter(
                      color: _statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text("VPD (Estrés)",
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.getTextSecondary(isDark),
                  fontWeight: FontWeight.w700)),
          Text(
            "${_currentVpd.toStringAsFixed(2)} kPa",
            style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.getTextMain(isDark),
                letterSpacing: -1),
          ),
          const SizedBox(height: 12),
          // Gráfica
          Expanded(
            flex: 2,
            child: _spots.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                        color: _statusColor, strokeWidth: 2))
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 3,
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _spots,
                          isCurved: true,
                          color: _statusColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                _statusColor.withValues(alpha: 0.15),
                                _statusColor.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
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
}
