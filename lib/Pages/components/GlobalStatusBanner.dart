import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/state/greenhouse_state_notifier.dart';
import '../../core/services/sensor_analysis_service.dart';

class GlobalStatusBanner extends StatelessWidget {
  const GlobalStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GreenhouseData>(
      valueListenable: greenhouseState,
      builder: (context, data, _) {
        final bool isCritical = data.status == GreenhouseStatus.critical;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: data.statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: data.statusColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              // Icono con pulso si es crítico
              _StatusIcon(status: data.status, color: data.statusColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusTitle(data.status),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: data.statusColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.statusMessage,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: data.statusColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (isCritical)
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.redAccent),
            ],
          ),
        );
      },
    );
  }

  String _getStatusTitle(GreenhouseStatus status) {
    switch (status) {
      case GreenhouseStatus.optimal: return "ESTADO ÓPTIMO";
      case GreenhouseStatus.attention: return "REQUERIR ATENCIÓN";
      case GreenhouseStatus.critical: return "ALERTA CRÍTICA";
    }
  }
}

class _StatusIcon extends StatefulWidget {
  final GreenhouseStatus status;
  final Color color;

  const _StatusIcon({required this.status, required this.color});

  @override
  State<_StatusIcon> createState() => _StatusIconState();
}

class _StatusIconState extends State<_StatusIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final IconData iconData = widget.status == GreenhouseStatus.optimal 
        ? Icons.check_circle_rounded 
        : (widget.status == GreenhouseStatus.attention ? Icons.warning_rounded : Icons.error_rounded);

    if (widget.status != GreenhouseStatus.critical) {
      return Icon(iconData, color: widget.color, size: 32);
    }

    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticIn),
      ),
      child: Icon(iconData, color: widget.color, size: 32),
    );
  }
}
