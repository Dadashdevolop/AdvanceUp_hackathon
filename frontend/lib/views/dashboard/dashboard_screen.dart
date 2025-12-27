// Dosya: lib/views/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/farm_provider.dart';
import '../../providers/ui_provider.dart';
import '../../services/notification_service.dart';
import '../../services/websocket_service.dart';
import '../../config/theme.dart';
import './camera_screen.dart';
import './sensors_screen.dart';
import './status_screen.dart';
import './audio_screen.dart';
import './barn_3d_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final List<Widget> _screens = const [
    StatusScreen(),
    SensorsScreen(),
    CameraScreen(),
    AudioScreen(),
    Barn3DScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Listen to motion events during build (required by Riverpod)
    ref.listen(farmDataStreamProvider, (previous, next) async {
      if (next.hasValue) {
        final data = next.value!;
        final s = data.detectedObject.toLowerCase();
        if (s.contains('hareket') || s.contains('motion')) {
          await NotificationService().showMotionDetectedNotification();
        }
      }
    });

    final currentIndex = ref.watch(bottomNavIndexProvider);
    final connectionAsync = ref.watch(connectionStatusProvider);
    final connectionStatus =
        connectionAsync.value ?? ConnectionStatus.connecting;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      extendBody: true,
      appBar: AppBar(
        title:
            ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradient.createShader(bounds),
                  child: Text(
                    "XEYRON akıllı çiftlik",
                    style: GoogleFonts.audiowide(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                .animate()
                .fadeIn(duration: 500.ms)
                .shimmer(delay: 1000.ms, duration: 2000.ms),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.backgroundColor,
                AppTheme.cardBackground.withOpacity(0.8),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildConnectionBanner(connectionStatus),
          Expanded(
            child: Hero(
              tag: 'screen_$currentIndex',
              child: _screens[currentIndex],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.cardBackground.withOpacity(0.95),
              AppTheme.backgroundColor,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            ref.read(bottomNavIndexProvider.notifier).state = index;
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: AppTheme.accentColor,
          unselectedItemColor: AppTheme.textTertiary,
          elevation: 0,
          selectedLabelStyle: GoogleFonts.roboto(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: GoogleFonts.roboto(fontSize: 11),
          items: [
            BottomNavigationBarItem(
              icon: Icon(FontAwesomeIcons.shieldHalved)
                  .animate(target: currentIndex == 0 ? 1 : 0)
                  .scale(end: const Offset(1.2, 1.2)),
              label: 'Durum',
            ),
            BottomNavigationBarItem(
              icon: Icon(FontAwesomeIcons.gaugeHigh)
                  .animate(target: currentIndex == 1 ? 1 : 0)
                  .scale(end: const Offset(1.2, 1.2)),
              label: 'Sensörler',
            ),
            BottomNavigationBarItem(
              icon: Icon(FontAwesomeIcons.video)
                  .animate(target: currentIndex == 2 ? 1 : 0)
                  .scale(end: const Offset(1.2, 1.2)),
              label: 'Kamera',
            ),
            BottomNavigationBarItem(
              icon: Icon(FontAwesomeIcons.microphone)
                  .animate(target: currentIndex == 3 ? 1 : 0)
                  .scale(end: const Offset(1.2, 1.2)),
              label: 'Ses',
            ),
            BottomNavigationBarItem(
              icon: Icon(FontAwesomeIcons.cube)
                  .animate(target: currentIndex == 4 ? 1 : 0)
                  .scale(end: const Offset(1.2, 1.2)),
              label: '3D',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBanner(ConnectionStatus status) {
    late final Color color;
    late final String label;
    late final IconData icon;

    switch (status) {
      case ConnectionStatus.connected:
        color = AppTheme.successColor;
        label = "Canlı veri bağlı";
        icon = FontAwesomeIcons.circleCheck;
        break;
      case ConnectionStatus.connecting:
        color = AppTheme.warningColor;
        label = "Bağlantı kuruluyor...";
        icon = FontAwesomeIcons.circleNotch;
        break;
      case ConnectionStatus.error:
        color = AppTheme.dangerColor;
        label = "Bağlantı hatası - tekrar deniyor";
        icon = FontAwesomeIcons.triangleExclamation;
        break;
      case ConnectionStatus.disconnected:
        color = AppTheme.textTertiary;
        label = "Bağlantı koptu - tekrar deniyor";
        icon = FontAwesomeIcons.plug;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
        ),
        border: Border(
          bottom: BorderSide(color: color.withOpacity(0.3), width: 2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18)
              .animate(
                onPlay: (controller) => status == ConnectionStatus.connecting
                    ? controller.repeat()
                    : null,
              )
              .rotate(duration: 1500.ms),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.roboto(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          if (status == ConnectionStatus.connected)
            Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                )
                .animate(onPlay: (controller) => controller.repeat())
                .fadeIn(duration: 800.ms)
                .then()
                .fadeOut(duration: 800.ms),
        ],
      ),
    ).animate().slideY(begin: -1, end: 0, duration: 300.ms);
  }
}
