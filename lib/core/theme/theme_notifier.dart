import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ValueNotifier<bool> {
  ThemeNotifier() : super(false) {
    _loadTheme();
  }

  // true = Dark, false = Light
  bool get isDark => value;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getBool('isDark') ?? false; // Default to Light
  }

  Future<void> toggleTheme() async {
    value = !value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', value);
  }
}

// Global instance for simple access without provider
final themeNotifier = ThemeNotifier();
