import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:liquid_progress_indicator_v2/liquid_progress_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import 'glass_card.dart';

class LiquidWaterLevel extends StatelessWidget {
  final int waterLevel;
  final bool isDanger;

  const LiquidWaterLevel({
    Key? key,
    required this.waterLevel,
    this.isDanger = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = waterLevel / 100.0;
    final color = _getWaterColor(waterLevel);

    return GlassCard(
      gradientColors: [color.withOpacity(0.2), color.withOpacity(0.05)],
      boxShadow: isDanger
          ? AppTheme.pulsingShadow(AppTheme.dangerColor)
          : AppTheme.cardShadow,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          Text(
            "Su Seviyesi",
            style: GoogleFonts.roboto(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // Liquid Indicator
          Expanded(
            child: Center(
              child:
                  SizedBox(
                        width: 70,
                        height: 70,
                        child: LiquidCircularProgressIndicator(
                          value: percentage,
                          valueColor: AlwaysStoppedAnimation(color),
                          backgroundColor: Colors.white.withOpacity(0.1),
                          borderColor: color.withOpacity(0.5),
                          borderWidth: 3.0,
                          direction: Axis.vertical,
                          center: Text(
                            '%$waterLevel',
                            style: GoogleFonts.orbitron(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [Shadow(color: color, blurRadius: 10)],
                            ),
                          ),
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(
                        duration: 2000.ms,
                        color: color.withOpacity(0.3),
                      ),
            ),
          ),

          const SizedBox(height: 8),

          // Status Icon
          Icon(FontAwesomeIcons.water, color: color, size: 20)
              .animate(onPlay: (controller) => controller.repeat())
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.2, 1.2),
                duration: 1000.ms,
              )
              .then()
              .scale(
                begin: const Offset(1.2, 1.2),
                end: const Offset(1.0, 1.0),
                duration: 1000.ms,
              ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8));
  }

  Color _getWaterColor(int level) {
    if (level < 30) return AppTheme.dangerColor;
    if (level < 50) return AppTheme.warningColor;
    if (level < 70) return const Color(0xFF06B6D4); // Cyan
    return const Color(0xFF3B82F6); // Blue
  }
}
