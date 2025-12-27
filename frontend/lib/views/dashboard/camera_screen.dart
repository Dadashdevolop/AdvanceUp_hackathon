import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/farm_provider.dart';
import '../../providers/ui_provider.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../widgets/glass_card.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  bool _isControllerRunning = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final farmDataAsync = ref.watch(farmDataStreamProvider);

    return farmDataAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      ),
      error: (err, stack) => Center(
        child: Text(
          "Bağlantı Hatası: $err",
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (farmData) {
        final statusColor = farmData.isDanger
            ? Colors.redAccent
            : const Color(0xFF00E676);
        final statusText = farmData.isDanger ? "TEHLİKE!" : "GÜVENLİ";

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Kamera ve State Banner
              Expanded(
                flex: 5,
                child:
                    Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: statusColor, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(21),
                            child: Stack(
                              children: [
                                // Split view: top camera feed, bottom detected object name
                                Column(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: farmData.imageBase64 != null
                                          ? Container(
                                              color: Colors.black,
                                              child: Image.memory(
                                                base64Decode(
                                                  farmData.imageBase64!,
                                                ),
                                                gaplessPlayback: true,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                              ),
                                            )
                                          : Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                        FontAwesomeIcons
                                                            .videoSlash,
                                                        color: Colors.white24,
                                                        size: 50,
                                                      )
                                                      .animate(
                                                        onPlay: (controller) =>
                                                            controller.repeat(),
                                                      )
                                                      .fadeIn(duration: 800.ms)
                                                      .then()
                                                      .fadeOut(
                                                        duration: 800.ms,
                                                      ),
                                                  const SizedBox(height: 10),
                                                  const Text(
                                                    "Sinyal Bekleniyor...",
                                                    style: TextStyle(
                                                      color: Colors.white54,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              statusColor.withOpacity(0.25),
                                              statusColor.withOpacity(0.05),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          border: Border(
                                            top: BorderSide(
                                              color: statusColor,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Text(
                                              farmData.detectedObject.isNotEmpty
                                                  ? farmData.detectedObject
                                                  : "Tanımlı Nesne Yok",
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.orbitron(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Futuristic Corner Frames
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: _buildCornerFrame(statusColor),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Transform.flip(
                                    flipX: true,
                                    child: _buildCornerFrame(statusColor),
                                  ),
                                ),
                                Positioned(
                                  bottom: 12,
                                  left: 12,
                                  child: Transform.flip(
                                    flipY: true,
                                    child: _buildCornerFrame(statusColor),
                                  ),
                                ),
                                Positioned(
                                  bottom: 12,
                                  right: 12,
                                  child: Transform.flip(
                                    flipX: true,
                                    flipY: true,
                                    child: _buildCornerFrame(statusColor),
                                  ),
                                ),

                                // Status Overlay (Top)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: GlassCard(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    borderRadius: 0,
                                    gradientColors: [
                                      statusColor.withOpacity(0.3),
                                      statusColor.withOpacity(0.1),
                                    ],
                                    child: Row(
                                      children: [
                                        Icon(
                                          FontAwesomeIcons.video,
                                          color: statusColor,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'LIVE',
                                          style: GoogleFonts.orbitron(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                shape: BoxShape.circle,
                                              ),
                                            )
                                            .animate(
                                              onPlay: (controller) =>
                                                  controller.repeat(),
                                            )
                                            .fadeIn(duration: 600.ms)
                                            .then()
                                            .fadeOut(duration: 600.ms),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .scale(begin: const Offset(0.95, 0.95)),
              ),
              const SizedBox(height: 16),

              // Sadece kontrol butonu (güvenlik durumu çerçeve rengiyle belirtiliyor)
              const SizedBox(height: 4),
              GestureDetector(
                onTapDown: (_) => HapticFeedback.mediumImpact(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 200,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isControllerRunning
                          ? [AppTheme.dangerColor, const Color(0xFFF97316)]
                          : [AppTheme.successColor, const Color(0xFF14B8A6)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isControllerRunning
                                    ? AppTheme.dangerColor
                                    : AppTheme.successColor)
                                .withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading
                          ? null
                          : () => _isControllerRunning
                                ? _stopController(context)
                                : _startController(context),
                      borderRadius: BorderRadius.circular(28),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isControllerRunning
                                        ? FontAwesomeIcons.stop
                                        : FontAwesomeIcons.play,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isControllerRunning
                                        ? "Durdur"
                                        : "Controller Başlat",
                                    style: GoogleFonts.roboto(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ).animate(target: _isLoading ? 1 : 0).shake(duration: 300.ms),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _startController(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final ok = await api.startController();

      if (ok) {
        setState(() {
          _isControllerRunning = true;
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Controller başlatıldı'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
        print('✅ Controller başlatıldı');
      } else {
        setState(() {
          _isLoading = false;
        });
        throw Exception('Sunucu hatası: controller başlatılamadı');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      print('❌ Controller başlatma hatası: $e');
    }
  }

  void _stopController(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final ok = await api.stopController();

      if (ok) {
        setState(() {
          _isControllerRunning = false;
          _isLoading = false;
        });
        // Manuel durdurma zamanını işaretle (1 dakika otomatik açma yok)
        ref.read(lastManualStopProvider.notifier).state = DateTime.now();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Controller durduruldu'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        print('⏹️ Controller durduruldu');
      } else {
        setState(() {
          _isLoading = false;
        });
        throw Exception('Sunucu hatası: controller durdurulamadı');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      print('❌ Controller durdurma hatası: $e');
    }
  }

  Widget _buildCornerFrame(Color color) {
    return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: 3),
              left: BorderSide(color: color, width: 3),
            ),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .fadeIn(duration: 1000.ms)
        .then()
        .fadeOut(duration: 1000.ms);
  }
}
