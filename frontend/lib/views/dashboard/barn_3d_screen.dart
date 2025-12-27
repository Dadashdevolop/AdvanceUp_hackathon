import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import 'ar_screen.dart';

class Barn3DScreen extends StatefulWidget {
  const Barn3DScreen({super.key});

  @override
  State<Barn3DScreen> createState() => _Barn3DScreenState();
}

class _Barn3DScreenState extends State<Barn3DScreen> {
  late bool autoRotateEnabled;
  late bool arEnabled;

  @override
  void initState() {
    super.initState();
    autoRotateEnabled = true; // Auto-rotate starts ON
    arEnabled = false; // AR starts OFF
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.backgroundColor,
            AppTheme.backgroundColor.withOpacity(0.8),
            const Color(0xFF1E293B),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                            shaderCallback: (bounds) =>
                                AppTheme.primaryGradient.createShader(bounds),
                            child: Text(
                              "Ahır 3D Modeli",
                              style: GoogleFonts.audiowide(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideX(begin: -0.2, end: 0),
                      const SizedBox(height: 4),
                      Text(
                        "Sensörlerin konumunu ve ahırı 360° görüntüleyin",
                        style: GoogleFonts.roboto(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ).animate().fadeIn(duration: 600.ms),
                    ],
                  ),
                ),
                // Control Buttons: Auto-Rotate Toggle
                Tooltip(
                  message: autoRotateEnabled
                      ? "Dönüşü Durdur"
                      : "Dönüşü Başlat",
                  child: GestureDetector(
                    onTap: () {
                      setState(() => autoRotateEnabled = !autoRotateEnabled);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: autoRotateEnabled
                            ? AppTheme.accentColor
                            : AppTheme.cardBackground.withOpacity(0.6),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: autoRotateEnabled
                              ? Colors.white.withOpacity(0.5)
                              : AppTheme.textSecondary.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          if (autoRotateEnabled)
                            BoxShadow(
                              color: AppTheme.accentColor.withOpacity(0.4),
                              blurRadius: 12,
                            ),
                        ],
                      ),
                      child: Icon(
                        autoRotateEnabled ? Icons.play_arrow : Icons.pause,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 500.ms),
              ],
            ),
            const SizedBox(height: 16),

            // 3D Model Viewer
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.accentColor.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentColor.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      // 3D Model
                      ModelViewer(
                        src: 'assets/3d/ahir.glb',
                        alt: 'Ahır 3D modeli',
                        ar: arEnabled,
                        cameraControls: true,
                        autoRotate: autoRotateEnabled,
                        autoRotateDelay: 3000,
                        rotationPerSecond: '30deg',
                        arPlacement: ArPlacement.wall,
                        loading: Loading.lazy,
                        debugLogging: true,
                      ).animate().fadeIn(duration: 500.ms),

                      // (Poster suggestion) If needed, add a poster image to show while loading
                      // by setting `poster: 'assets/3d/poster.png'` in ModelViewer and
                      // declaring it in pubspec. Removed always-on overlay to avoid blocking.

                      // Info Badge (Top Right)
                      Positioned(
                        top: 12,
                        right: 12,
                        child:
                            Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.9,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.3),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Döndür & Yaklaş',
                                        style: GoogleFonts.roboto(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .animate(
                                  onPlay: (controller) => controller.repeat(),
                                )
                                .fadeIn(duration: 1000.ms)
                                .then()
                                .fadeOut(duration: 1000.ms),
                      ),

                      // AR Button (Bottom Left) - Gerçek Ortamda AR (ARCore)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child:
                            GestureDetector(
                                  onTap: () {
                                    // Gerçek ortamda AR (ARCore) ekranına geç
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ARScreen(),
                                      ),
                                    );
                                  },
                                  child: Tooltip(
                                    message: "Gerçek Ortamda AR Aç",
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.accentColor
                                                .withOpacity(0.4),
                                            blurRadius: 15,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.view_in_ar,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                )
                                .animate(
                                  onPlay: (controller) => controller.repeat(),
                                )
                                .scale(
                                  begin: const Offset(1.0, 1.0),
                                  end: const Offset(1.08, 1.08),
                                  duration: 1500.ms,
                                )
                                .then()
                                .scale(
                                  begin: const Offset(1.08, 1.08),
                                  end: const Offset(1.0, 1.0),
                                  duration: 1500.ms,
                                ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.95, 0.95)),
            ),

            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.accentColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Kontroller:",
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "• Döndürmek: Parmağınızı sürükleyin\n"
                    "• Yaklaşmak: İki parmakla sıkıştırın veya kaydırın\n"
                    "• AR Modu: Alt soldaki butona dokunun (uyumlu cihazlarda)",
                    style: GoogleFonts.roboto(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }
}
