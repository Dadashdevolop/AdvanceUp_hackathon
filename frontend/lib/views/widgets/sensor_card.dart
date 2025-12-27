import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import 'glass_card.dart';

class SensorCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDanger;

  const SensorCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isDanger = false,
  });

  @override
  State<SensorCard> createState() => _SensorCardState();
}

class _SensorCardState extends State<SensorCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child:
          AnimatedScale(
                scale: _isHovered ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: GlassCard(
                  gradientColors: [
                    widget.color.withOpacity(0.15),
                    widget.color.withOpacity(0.05),
                  ],
                  boxShadow: widget.isDanger
                      ? AppTheme.pulsingShadow(widget.color)
                      : [
                          BoxShadow(
                            color: widget.color.withOpacity(
                              _isHovered ? 0.4 : 0.2,
                            ),
                            blurRadius: _isHovered ? 25 : 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated Icon with breathing effect
                      Icon(widget.icon, color: widget.color, size: 28)
                          .animate(onPlay: (controller) => controller.repeat())
                          .shimmer(
                            duration: 2000.ms,
                            color: widget.color.withOpacity(0.5),
                          )
                          .then()
                          .scale(
                            begin: const Offset(1.0, 1.0),
                            end: const Offset(1.1, 1.1),
                            duration: 1500.ms,
                          )
                          .then()
                          .scale(
                            begin: const Offset(1.1, 1.1),
                            end: const Offset(1.0, 1.0),
                            duration: 1500.ms,
                          )
                          .then()
                          .shake(
                            hz: 4,
                            curve: Curves.easeInOutCubic,
                            duration: widget.isDanger ? 500.ms : 0.ms,
                          ),
                      const SizedBox(height: 8),

                      // Animated Value with Counter Effect and Glow
                      Flexible(
                        child:
                            AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  style: GoogleFonts.orbitron(
                                    fontSize: _isHovered ? 20 : 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: widget.color.withOpacity(
                                          _isHovered ? 0.8 : 0.5,
                                        ),
                                        blurRadius: _isHovered ? 15 : 10,
                                      ),
                                      Shadow(
                                        color: widget.color,
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    widget.value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .scale(begin: const Offset(0.8, 0.8))
                                .then()
                                .shimmer(
                                  delay: 500.ms,
                                  duration: 1500.ms,
                                  color: widget.color.withOpacity(0.3),
                                ),
                      ),

                      const SizedBox(height: 2),

                      // Title with gradient
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            widget.color.withOpacity(0.8),
                            widget.color.withOpacity(0.4),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          widget.title,
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(
                begin: 0.3,
                end: 0,
                duration: 500.ms,
                curve: Curves.easeOutBack,
              )
              .then(delay: 100.ms)
              .shimmer(
                duration: 2000.ms,
                color: widget.color.withOpacity(0.15),
              ),
    );
  }
}
