import 'dart:math' as math;
import 'package:flutter/material.dart';

enum GreenhouseStatus { optimal, attention, critical }

class SensorAnalysisService {
  // Rangos ideales sugeridos
  static const double tempMin = 18.0;
  static const double tempMax = 28.0;
  static const double humMin = 40.0;
  static const double humMax = 70.0;
  static const double vpdMin = 0.8;
  static const double vpdMax = 1.2;

  /// Calcula el VPD usando la ecuación de Tetens
  static double calculateVPD(double temp, double hum) {
    if (temp <= 0) return 0.0;
    double exponent = (17.27 * temp) / (temp + 237.3);
    double svp = 0.61078 * math.exp(exponent);
    double vpd = svp * (1 - (hum / 100));
    return vpd < 0 ? 0 : vpd;
  }

  /// Determina el estado global basado en todos los sensores
  static Map<String, dynamic> analyzeGlobalState({
    required double temp,
    required double hum,
    required double light,
    required double vpd,
  }) {
    int points = 0;
    List<String> issues = [];

    // Análisis de Temperatura
    if (temp < 15 || temp > 35) {
      points += 2;
      issues.add(temp > 35 ? "Calor extremo" : "Frío excesivo");
    } else if (temp < tempMin || temp > tempMax) {
      points += 1;
    }

    // Análisis de Humedad
    if (hum < 30 || hum > 85) {
      points += 2;
      issues.add(hum > 85 ? "Humedad crítica (Hongos)" : "Aire muy seco");
    } else if (hum < humMin || hum > humMax) {
      points += 1;
    }

    // Análisis de VPD
    if (vpd < 0.4 || vpd > 2.0) {
      points += 2;
      issues.add(vpd < 0.4 ? "Transpiración bloqueada" : "Estrés hídrico alto");
    } else if (vpd < vpdMin || vpd > vpdMax) {
      points += 1;
    }

    GreenhouseStatus status;
    String message;
    Color color;

    if (points >= 3) {
      status = GreenhouseStatus.critical;
      message = issues.isNotEmpty ? issues.first : "Múltiples alertas críticas";
      color = Colors.redAccent;
    } else if (points >= 1) {
      status = GreenhouseStatus.attention;
      message = issues.isNotEmpty ? issues.first : "Parámetros fuera de rango";
      color = Colors.orangeAccent;
    } else {
      status = GreenhouseStatus.optimal;
      message = "Ambiente perfectamente equilibrado";
      color = const Color(0xFF2ECC71); // Esmeralda premium
    }

    return {
      'status': status,
      'message': message,
      'color': color,
      'points': points,
    };
  }

  /// Traduce el estado de un cultivo específico para las tarjetas
  static String getCropStatus(double vpd) {
    if (vpd < 0.4) return 'vpd_bajo';
    if (vpd > 1.6) return 'vpd_alto';
    return 'bien';
  }
}
