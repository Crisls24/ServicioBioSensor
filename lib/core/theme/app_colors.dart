import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF00C853); // Emerald brand color
  
  // Eco-Premium Dark Palette (Forest Charcoal)
  static const Color bgDark = Color(0xFF080A08);
  static const Color surfaceDark = Color(0xFF121512);
  static const Color borderDark = Color(0xFF1F241F);
  static const Color textMainDark = Color(0xFFF0F4F0);
  static const Color textSecondaryDark = Color(0xFF8A958A);
  
  // Eco-Premium Light Palette (Clean Slate)
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textMainLight = Color(0xFF1E293B);
  static const Color textSecondaryLight = Color(0xFF64748B);

  // Status Colors
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color textLabel = Color(0xFFA7F3D0); // For dark labels
  static const Color textLabelLight = Color(0xFF059669); // For light labels

  // Dynamic Getters
  static Color getBg(bool isDark) => isDark ? bgDark : bgLight;
  static Color getSurface(bool isDark) => isDark ? surfaceDark : surfaceLight;
  static Color getBorder(bool isDark) => isDark ? borderDark : borderLight;
  static Color getTextMain(bool isDark) => isDark ? textMainDark : textMainLight;
  static Color getTextSecondary(bool isDark) => isDark ? textSecondaryDark : textSecondaryLight;
  static Color getLabel(bool isDark) => isDark ? textLabel : textLabelLight;
  static Color getInputBg(bool isDark) => isDark ? Colors.white.withValues(alpha: 0.05) : Color(0xFFF1F5F9);
  static Color getCardColor(bool isDark) => isDark ? Colors.white.withValues(alpha: 0.07) : Colors.white.withValues(alpha: 0.85);
  static List<BoxShadow> getShadow(bool isDark) {
    if (isDark) return [];
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.02),
        blurRadius: 5,
        offset: const Offset(0, 2),
      ),
    ];
  }
}
