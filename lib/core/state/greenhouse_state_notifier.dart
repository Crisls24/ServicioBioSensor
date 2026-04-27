import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../services/sensor_analysis_service.dart';

class GreenhouseData {
  final double temp;
  final double humidity;
  final double light;
  final double vpd;
  final GreenhouseStatus status;
  final String statusMessage;
  final Color statusColor;
  final Map<String, double> previousValues;

  GreenhouseData({
    this.temp = 0.0,
    this.humidity = 0.0,
    this.light = 0.0,
    this.vpd = 0.0,
    this.status = GreenhouseStatus.optimal,
    this.statusMessage = "Cargando datos...",
    this.statusColor = Colors.grey,
    this.previousValues = const {},
  });
}

class GreenhouseStateNotifier extends ValueNotifier<GreenhouseData> {
  StreamSubscription? _subscription;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('sensores/data');

  GreenhouseStateNotifier() : super(GreenhouseData()) {
    _startListening();
  }

  void _startListening() {
    _subscription = _dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        final double newTemp = double.tryParse(data['temperatura'].toString()) ?? 0.0;
        final double newHum = double.tryParse(data['humedad'].toString()) ?? 0.0;
        final double newLight = double.tryParse(data['luz_lumenes'].toString()) ?? 0.0;
        final double newVpd = SensorAnalysisService.calculateVPD(newTemp, newHum);

        final analysis = SensorAnalysisService.analyzeGlobalState(
          temp: newTemp,
          hum: newHum,
          light: newLight,
          vpd: newVpd,
        );

        // Guardamos valores previos para tendencias
        final Map<String, double> prev = {
          'temp': value.temp,
          'hum': value.humidity,
          'light': value.light,
          'vpd': value.vpd,
        };

        value = GreenhouseData(
          temp: newTemp,
          humidity: newHum,
          light: newLight,
          vpd: newVpd,
          status: analysis['status'],
          statusMessage: analysis['message'],
          statusColor: analysis['color'],
          previousValues: prev,
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// Singleton global para facilitar el acceso sin inyección compleja por ahora
final greenhouseState = GreenhouseStateNotifier();
