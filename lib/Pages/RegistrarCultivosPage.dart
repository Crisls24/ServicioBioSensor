import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invernadero/main.dart';
import 'package:invernadero/core/theme/app_colors.dart';
import 'package:invernadero/core/theme/theme_notifier.dart';

const Color kPrimaryGreen = Color(0xFF2E7D32);
const Color kLightGreen = Color(0xFFE8F5E9);
const Color kAccentOrange = Color(0xFFEF6C00);
const Color kSurfaceWhite = Colors.white;
const Color kTextDark = Color(0xFF1B5E20);

// Datos estáticos
final List<String> listaCultivos = [
  'Jitomate',
  'Pepino',
  'Pimiento',
  'Fresa',
  'Lechuga'
];
final List<String> listaFases = [
  'Germinación',
  'Crecimiento',
  'Floración',
  'Fructificación',
  'Cosecha'
];
final List<String> listaSustratos = [
  'Tierra',
  'Fibra de Coco',
  'Lana de Roca',
  'Hidroponía'
];

class InvernaderoData {
  final double superficieM2;
  final List<String> lotesDisponibles = const ['Norte', 'Centro', 'Sur'];
  InvernaderoData({required this.superficieM2});
}

// SELECTOR DE LOTE
class AliveLoteSelector extends StatelessWidget {
  final InvernaderoData data;
  final List<String> selectedLotes;
  final Function(String) onLoteToggled;
  final Set<String> lotesOcupados;

  const AliveLoteSelector({
    super.key,
    required this.data,
    required this.selectedLotes,
    required this.onLoteToggled,
    required this.lotesOcupados,
  });

  @override
  Widget build(BuildContext context) {
    double areaPorLote = data.superficieM2 / data.lotesDisponibles.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: kPrimaryGreen.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('DISTRIBUCIÓN DEL ÁREA',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: kLightGreen, borderRadius: BorderRadius.circular(8)),
                child: Text(
                    '${data.superficieM2.toStringAsFixed(0)} m² Totales',
                    style: const TextStyle(
                        fontSize: 12,
                        color: kPrimaryGreen,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: data.lotesDisponibles.asMap().entries.map((entry) {
              String lote = entry.value;
              bool isSelected = selectedLotes.contains(lote);
              bool isOccupied = lotesOcupados.contains(lote);

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (isOccupied) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'La sección $lote ya está ocupada por otro cultivo 🔒'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: Colors.grey[800],
                      ));
                    } else {
                      onLoteToggled(lote);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 85,
                    decoration: BoxDecoration(
                      color: isOccupied
                          ? Colors.grey[200]
                          : isSelected
                              ? kPrimaryGreen
                              : kLightGreen,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              isSelected ? kPrimaryGreen : Colors.transparent,
                          width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isOccupied
                              ? Icons.lock
                              : (isSelected
                                  ? Icons.check_circle
                                  : Icons.eco_outlined),
                          color: isOccupied
                              ? Colors.grey
                              : (isSelected ? Colors.white : kPrimaryGreen),
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lote,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isOccupied
                                ? Colors.grey
                                : (isSelected ? Colors.white : kTextDark),
                          ),
                        ),
                        if (!isOccupied)
                          Text(
                            '${areaPorLote.toStringAsFixed(0)}m²',
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? Colors.white70
                                  : kPrimaryGreen.withOpacity(0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// PÁGINA PRINCIPAL
class CultivoPage extends StatefulWidget {
  final String invernaderoId;
  final String appId;

  const CultivoPage(
      {super.key, required this.invernaderoId, required this.appId});

  @override
  State<CultivoPage> createState() => _CultivoPageState();
}

class _CultivoPageState extends State<CultivoPage> {
  String? _selectedCultivo;
  List<String> _selectedLotes = [];
  String _variedad = '';
  DateTime _fechaSiembra = DateTime.now();
  String? _selectedFase;
  String? _selectedSustrato;
  int _activeStep = 1;

  static const Map<String, double> _recommendedRiego = {
    'Jitomate': 6.0,
    'Pepino': 5.0,
    'Pimiento': 5.5,
    'Fresa': 4.0,
    'Lechuga': 3.5,
  };

  // Controlador para el campo de agua para poder actualizarlo desde el asistente
  final TextEditingController _aguaController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _loteSectionKey = GlobalKey();
  final GlobalKey _extraSectionKey = GlobalKey();

  final _formKey = GlobalKey<FormState>();
  Set<String> _lotesOcupados = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInvernaderoData(widget.invernaderoId);
  }

  @override
  void dispose() {
    _aguaController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInvernaderoData(String id) async {
    setState(() => _isLoading = true);
    try {
      final cultivosSnap = await publicCollection(widget.appId, 'cultivos')
          .where('invernaderoId', isEqualTo: id)
          .get();

      final ocupados = <String>{};
      for (final doc in cultivosSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['lotes'] != null) {
          ocupados.addAll(List<String>.from(data['lotes']));
        }
      }

      if (mounted) {
        setState(() {
          _lotesOcupados = ocupados;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando lotes: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _saveCultivo() async {
    if (_selectedCultivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecciona qué cultivo vas a sembrar 🌱'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (_selectedLotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecciona una sección del plano 👆'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? true)) return;

    double? consumoAgua = double.tryParse(_aguaController.text);

    final cultivoData = {
      'invernaderoId': widget.invernaderoId,
      'lotes': _selectedLotes,
      'cultivo': _selectedCultivo,
      'variedad': _variedad,
      'fechaSiembra': _fechaSiembra,
      'faseActual': _selectedFase,
      'sustrato': _selectedSustrato,
      'consumoAguaLitrosM2': consumoAgua,
      'fechaRegistro': Timestamp.now(),
    };

    try {
      await publicCollection(widget.appId, 'cultivos').add(cultivoData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('¡Cultivo registrado correctamente! 🌱'),
            backgroundColor: kPrimaryGreen));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
    }
  }

  // ASISTENTE DE CÁLCULO
  void _handleCultivoSelect(String cultivo) {
    setState(() {
      _selectedCultivo = cultivo;
      final recommended = _recommendedRiego[cultivo];
      if (recommended != null && _aguaController.text.isEmpty) {
        _aguaController.text = recommended.toStringAsFixed(1);
      }
      _activeStep = 2;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSection(_loteSectionKey);
    });
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    final context = key.currentContext;
    if (context == null) return;

    await Scrollable.ensureVisible(context,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: 0.1);
  }

  void _showCalculadoraRiego() {
    double litrosPorPlanta = 0;
    double plantasPorMetro = 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.calculate, color: kPrimaryGreen),
            SizedBox(width: 10),
            Text('Asistente de Riego',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Si no conoces el dato en L/m², responde estas preguntas:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '¿Litros por planta al día?',
                suffixText: 'L',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (v) => litrosPorPlanta = double.tryParse(v) ?? 0,
            ),
            const SizedBox(height: 15),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '¿Plantas por m²?',
                suffixText: 'plantas',
                helperText: 'Densidad de siembra',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (v) => plantasPorMetro = double.tryParse(v) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryGreen,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              // Fórmula: L/m2 = LitrosPorPlanta * PlantasPorMetro
              double total = litrosPorPlanta * plantasPorMetro;
              _aguaController.text = total.toStringAsFixed(2);
              Navigator.pop(context);
            },
            child: const Text('Usar Resultado',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, _) {
        final background = AppColors.getBg(isDark);
        final surface = AppColors.getCardColor(isDark);
        final textPrimary = AppColors.getTextMain(isDark);
        final accent = AppColors.primary;

        return Scaffold(
          backgroundColor: background,
          appBar: AppBar(
            backgroundColor: background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: textPrimary,
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Registrar cultivo',
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textPrimary)),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStepHeader(isDark),
                  const SizedBox(height: 20),
                  _buildCultivoSelectorStep(isDark),
                  const SizedBox(height: 18),
                  _buildLoteSelectorStep(isDark),
                  const SizedBox(height: 18),
                  _buildOptionalDetailsStep(isDark),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: (_selectedCultivo != null &&
                        _selectedLotes.isNotEmpty &&
                        !_isLoading)
                    ? _saveCultivo
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 8,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Registrar cultivo',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepHeader(bool isDark) {
    final accent = AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: accent.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: accent.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(Icons.tour, color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registra tu cultivo en 3 pasos',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.getTextMain(isDark))),
                const SizedBox(height: 4),
                Text(
                    'Menos formulario, más acción. Elige, selecciona y guarda.',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.getTextSecondary(isDark),
                        height: 1.4)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text('Paso $_activeStep/3',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 13, color: accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildCultivoSelectorStep(bool isDark) {
    final accent = AppColors.primary;
    final textPrimary = AppColors.getTextMain(isDark);
    final selectedCultivo = _selectedCultivo;
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 72) / 2;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: accent.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('¿QUÉ VAS A SEMBRAR?',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: textPrimary)),
          const SizedBox(height: 8),
          Text('Toca una opción para avanzar. Elige lo que vas a sembrar hoy.',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.getTextSecondary(isDark),
                  height: 1.4)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: listaCultivos.map((cultivo) {
              final active = cultivo == selectedCultivo;
              return GestureDetector(
                onTap: () => _handleCultivoSelect(cultivo),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: itemWidth,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: active
                        ? accent.withOpacity(0.14)
                        : AppColors.getBg(isDark),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: active ? accent : AppColors.getBorder(isDark),
                        width: active ? 2 : 1),
                    boxShadow: active
                        ? [
                            BoxShadow(
                                color: accent.withOpacity(0.12),
                                blurRadius: 18,
                                offset: const Offset(0, 10))
                          ]
                        : [
                            BoxShadow(
                                color: AppColors.getTextMain(isDark)
                                    .withOpacity(0.03),
                                blurRadius: 12,
                                offset: const Offset(0, 6))
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                              active
                                  ? Icons.check_circle
                                  : Icons.local_florist_outlined,
                              color: active ? accent : AppColors.primary,
                              size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(cultivo,
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: active ? accent : textPrimary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Cultivo recomendado',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.getTextSecondary(isDark))),
                      const SizedBox(height: 10),
                      Text(
                          _recommendedRiego[cultivo] != null
                              ? '${_recommendedRiego[cultivo]!.toStringAsFixed(1)} L/m²'
                              : 'Sin datos',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? accent
                                  : AppColors.getTextMain(isDark))),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoteSelectorStep(bool isDark) {
    final bool canSelect = _selectedCultivo != null;
    return Container(
      key: _loteSectionKey,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Selecciona el área donde sembrarás',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.getTextMain(isDark))),
          const SizedBox(height: 8),
          Text('Escoge un lote libre y evita secciones ya ocupadas.',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.getTextSecondary(isDark),
                  height: 1.4)),
          const SizedBox(height: 18),
          if (!canSelect)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: kPrimaryGreen, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Primero selecciona el cultivo para activar el selector de lotes.',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(isDark),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: canSelect ? 1.0 : 0.5,
            child: AbsorbPointer(
              absorbing: !canSelect,
              child: AliveLoteSelector(
                data: InvernaderoData(superficieM2: 120),
                selectedLotes: _selectedLotes,
                onLoteToggled: _handleLoteToggle,
                lotesOcupados: _lotesOcupados,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalDetailsStep(bool isDark) {
    return Container(
      key: _extraSectionKey,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Detalles opcionales',
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.getTextMain(isDark))),
                      const SizedBox(height: 4),
                      Text('Completa solo si deseas guardar información extra.',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.getTextSecondary(isDark),
                              height: 1.4)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('Opcional',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildTextFieldVibrant('Variedad', Icons.label_outline, 'Ej: Roma',
                (v) => _variedad = v, isDark),
            const SizedBox(height: 14),
            _buildDropdownVibrant('Fase', Icons.timeline, _selectedFase,
                listaFases, (v) => _selectedFase = v, isDark),
            const SizedBox(height: 14),
            _buildDropdownVibrant('Sustrato', Icons.layers, _selectedSustrato,
                listaSustratos, (v) => _selectedSustrato = v, isDark),
            const SizedBox(height: 14),
            _buildDateVibrant(isDark),
            const SizedBox(height: 14),
            _buildAguaFieldWithAssistant(isDark),
            const SizedBox(height: 4),
            Text(
              'El valor de riego se sugiere según el cultivo seleccionado.',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.getTextSecondary(isDark),
                  height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Row(
      children: [
        Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
                color: kAccentOrange, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.grey[400])),
      ],
    );
  }

  // Nuevo Widget para el Agua
  Widget _buildAguaFieldWithAssistant(bool isDark) {
    final textPrimary = AppColors.getTextMain(isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Riego (L/m²)',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textPrimary)),
            GestureDetector(
              onTap: _showCalculadoraRiego,
              child: Text('¿Ayuda?',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _aguaController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.water_drop,
                      size: 20, color: AppColors.primary),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calculate_outlined,
                        color: Colors.grey),
                    onPressed: _showCalculadoraRiego,
                    tooltip: 'Calcular',
                  ),
                  hintText: '0.0',
                  hintStyle: TextStyle(
                      color: AppColors.primary.withOpacity(0.4), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                ),
                style:
                    TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                keyboardAppearance: Brightness.light,
              ),
              const SizedBox(height: 10),
              if (_selectedCultivo != null)
                Text(
                    'Valor recomendado para $_selectedCultivo: ${_recommendedRiego[_selectedCultivo]!.toStringAsFixed(1)} L/m²',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(isDark))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldVibrant(String label, IconData icon, String hint,
      Function(String) onChanged, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.getTextMain(isDark))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12)),
          child: TextFormField(
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
              hintText: hint,
              hintStyle: TextStyle(
                  color: AppColors.primary.withOpacity(0.4), fontSize: 13),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            ),
            style: TextStyle(
                color: AppColors.getTextMain(isDark),
                fontWeight: FontWeight.w500),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownVibrant(String label, IconData icon, String? value,
      List<String> items, Function(String?) onChanged, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.getTextMain(isDark))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: AppColors.primary),
              hint: Row(children: [
                Icon(icon, size: 20, color: AppColors.primary.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text('Elegir',
                    style: TextStyle(
                        color: AppColors.primary.withOpacity(0.4),
                        fontSize: 13))
              ]),
              items: items
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e,
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.getTextMain(isDark)))))
                  .toList(),
              onChanged: (v) => setState(() => onChanged(v)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateVibrant(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fecha',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.getTextMain(isDark))),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now());
            if (picked != null) setState(() => _fechaSiembra = picked);
          },
          child: Container(
            height: 48,
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text("${_fechaSiembra.day}/${_fechaSiembra.month}",
                    style: TextStyle(
                        color: AppColors.getTextMain(isDark),
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleLoteToggle(String lote) {
    if (_selectedCultivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Primero selecciona el cultivo'),
          backgroundColor: Colors.redAccent));
      return;
    }
    if (_lotesOcupados.contains(lote)) return;
    setState(() {
      if (_selectedLotes.contains(lote)) {
        _selectedLotes.remove(lote);
      } else {
        _selectedLotes.add(lote);
      }
      _activeStep = _selectedLotes.isEmpty ? 2 : 3;
    });
    if (_selectedLotes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSection(_extraSectionKey);
      });
    }
  }
}
