import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:invernadero/Pages/RegistroInvernadero.dart';
import 'package:invernadero/Pages/SideNav.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invernadero/core/theme/app_colors.dart';
import 'package:invernadero/core/theme/theme_notifier.dart';

class Gestioninvernadero extends StatefulWidget {
  final String appId;

  const Gestioninvernadero({super.key, required this.appId});

  @override
  State<Gestioninvernadero> createState() => _GestioninvernaderoState();
}

class _GestioninvernaderoState extends State<Gestioninvernadero> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String searchQuery = '';

  // FUNCIÓN AUXILIAR DE RUTA

  CollectionReference<Map<String, dynamic>> _getPublicCollectionRef(
      String collectionName) {
    return _firestore
        .collection('artifacts')
        .doc(widget.appId)
        .collection('public')
        .doc('data')
        .collection(collectionName);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color.withValues(alpha: 0.95),
        behavior: SnackBarBehavior.floating,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.all(24),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                  color: Colors.white24, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setAndNavigateToHome(String invernaderoId) async {
    if (currentUser == null) {
      _showSnackBar(
          'Debe iniciar sesión.', Icons.lock_outline, Colors.redAccent);
      return;
    }

    try {
      await _getPublicCollectionRef('usuarios').doc(currentUser!.uid).set({
        'invernaderoId': invernaderoId,
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _showSnackBar('Error al visitar.', Icons.error_outline, Colors.redAccent);
    }
  }

  // CORRECCIÓN CRÍTICA 3: Rutas en _deleteInvernadero
  Future<void> _deleteInvernadero(String id) async {
    final isDark = themeNotifier.isDark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getCardColor(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.delete_sweep_rounded,
                  color: Colors.redAccent, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              '¿Eliminar Invernadero?',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.getTextMain(isDark)),
            ),
            const SizedBox(height: 12),
            Text(
              'Esta acción eliminará permanentemente todos los datos asociados. No se puede deshacer.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: AppColors.getTextSecondary(isDark),
                  fontSize: 13,
                  height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: GoogleFonts.inter(
                    color: AppColors.getTextSecondary(isDark),
                    fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Eliminar',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _getPublicCollectionRef('invernaderos').doc(id).delete();
      _showSnackBar(
          'Invernadero eliminado', Icons.delete_outline, Colors.redAccent);
      if (currentUser?.uid != null) {
        final userDoc = await _getPublicCollectionRef('usuarios')
            .doc(currentUser!.uid)
            .get();
        if (userDoc.data()?['invernaderoId'] == id) {
          await _getPublicCollectionRef('usuarios')
              .doc(currentUser!.uid)
              .update({'invernaderoId': ''});
        }
      }
    }
  }

  void _showOptionsMenu(BuildContext context, String id, String nombre) {
    final isDark = themeNotifier.isDark;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCardColor(isDark),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            Text(nombre,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.getTextMain(isDark))),
            const SizedBox(height: 24),
            _optionTile(Icons.people_outline_rounded,
                'Administrar Colaboradores', AppColors.primary, isDark, () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/empleados', arguments: id);
            }),
            _optionTile(Icons.edit_outlined, 'Editar Información',
                Colors.orangeAccent, isDark, () {
              Navigator.pop(context);
              _showSnackBar('Edición próximamente', Icons.info_outline,
                  AppColors.primary);
            }),
            _optionTile(Icons.delete_outline_rounded,
                'Eliminar Permanentemente', Colors.redAccent, isDark, () {
              Navigator.pop(context);
              _deleteInvernadero(id);
            }),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(IconData icon, String title, Color color, bool isDark,
      VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.getTextMain(isDark))),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
    );
  }

  Widget _buildInvernaderoCard(Map<String, dynamic> data, String activeId) {
    final nombre = data['nombre'] ?? 'Invernadero';
    final id = data['id'] ?? '';
    final ubicacion = data['ubicacion'] ?? 'Sin ubicación';
    final isDark = themeNotifier.isDark;
    final isActive = (id == activeId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isActive
            ? [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 14,
                    spreadRadius: 1)
              ]
            : AppColors.getShadow(isDark),
        border: Border.all(
            color: isActive ? AppColors.primary : AppColors.getBorder(isDark),
            width: isActive ? 2.5 : 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _setAndNavigateToHome(id),
          splashColor: AppColors.primary.withValues(alpha: 0.1),
          highlightColor: AppColors.primary.withValues(alpha: 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Imagen
              Stack(
                children: [
                  ShaderMask(
                    shaderCallback: (rect) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.7)
                      ],
                    ).createShader(rect),
                    blendMode: BlendMode.darken,
                    child: Image.asset(
                      'assets/GestionInv2.png',
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          height: 110,
                          color: AppColors.primary.withValues(alpha: 0.1)),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showOptionsMenu(context, id, nombre),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.more_vert_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ),
                  if (isActive)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 8)
                            ]),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text('EN USO',
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1)),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Text(
                      nombre,
                      style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            color: AppColors.getTextSecondary(isDark)
                                .withValues(alpha: 0.5),
                            size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(ubicacion,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    color: AppColors.getTextSecondary(isDark),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.login_rounded,
                            size: 16,
                            color: isActive ? AppColors.primary : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Abrir invernadero',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color:
                                  isActive ? AppColors.primary : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, _) {
        final background = AppColors.getBg(isDark);
        final textPrimary = AppColors.getTextMain(isDark);

        return Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: background,
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          RegistroInvernaderoPage(appId: widget.appId))),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_home_work_rounded),
              label: Text('Nuevo Invernadero',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900, letterSpacing: 0)),
            ),
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: AppBar(
                backgroundColor: background.withValues(alpha: 0.92),
                elevation: 0,
                foregroundColor: AppColors.primary,
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    color: AppColors.primary,
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                title: Text(
                  'Mis Invernaderos',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: textPrimary,
                  ),
                ),
                centerTitle: false,
              ),
            ),
            drawer: Drawer(
                backgroundColor: background,
                child: SideNav(currentRoute: 'gestion', appId: widget.appId)),
            body: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 64,
              ),
              child: StreamBuilder<DocumentSnapshot>(
                stream: _getPublicCollectionRef('usuarios')
                    .doc(currentUser!.uid)
                    .snapshots(),
                builder: (context, userSnapshot) {
                final activeId = (userSnapshot.data?.data()
                        as Map<String, dynamic>?)?['invernaderoId'] ??
                    '';

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Barra de Búsqueda
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: _buildSearchBar(isDark),
                      ),
                    ),

                    // Listado Principal
                    StreamBuilder<QuerySnapshot>(
                      stream: _getPublicCollectionRef('invernaderos')
                          .where('ownerId', isEqualTo: currentUser!.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SliverFillRemaining(
                              child: Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.primary)));
                        }

                        final docs = snapshot.data?.docs ?? [];
                        // TODO: support fuzzy search improvements in a future UI pass.
                        final filtrados = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final nombre =
                              (data['nombre'] ?? '').toString().toLowerCase();
                          final ubicacion =
                              (data['ubicacion'] ?? '').toString().toLowerCase();
                          return nombre.contains(searchQuery) ||
                              ubicacion.contains(searchQuery);
                        }).toList();

                        if (filtrados.isEmpty) {
                          return SliverFillRemaining(
                              child: _buildEmptyState(isDark));
                        }

                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final doc = filtrados[i];
                                return _buildInvernaderoCard(
                                    doc.data() as Map<String, dynamic>
                                      ..['id'] = doc.id,
                                    activeId);
                              },
                              childCount: filtrados.length,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _searchFocus.hasFocus
                ? AppColors.getTextMain(isDark).withValues(alpha: 0.35)
                : AppColors.getBorder(isDark),
            width: 1.5),
        boxShadow: _searchFocus.hasFocus
            ? [
                BoxShadow(
                    color:
                        AppColors.getTextMain(isDark).withValues(alpha: 0.08),
                    blurRadius: 10,
                    spreadRadius: 1)
              ]
            : [],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
        style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.getTextMain(isDark),
            fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          icon: Icon(Icons.search_rounded,
              color: _searchFocus.hasFocus ? AppColors.primary : Colors.grey,
              size: 20),
          hintText: 'Buscar por nombre o ciudad...',
          hintStyle: GoogleFonts.inter(
              color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
          border: InputBorder.none,
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle),
            child: Icon(Icons.eco_rounded,
                size: 64, color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 24),
          Text(
            searchQuery.isEmpty
                ? 'Aún no tienes invernaderos'
                : 'No hay resultados',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.getTextMain(isDark)),
          ),
          const SizedBox(height: 12),
          Text(
            searchQuery.isEmpty
                ? 'Crea tu primer espacio de cultivo para comenzar el monitoreo inteligente.'
                : 'Intenta con otro nombre o borra el filtro.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.getTextSecondary(isDark),
                height: 1.5),
          ),
          if (searchQuery.isEmpty) ...[
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          RegistroInvernaderoPage(appId: widget.appId))),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('Registrar Mi Primer Invernadero',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
            ),
          ],
        ],
      ),
    );
  }
}
