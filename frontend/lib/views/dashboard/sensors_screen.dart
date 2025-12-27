import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/farm_data.dart';
import '../../providers/farm_provider.dart';
import '../../config/theme.dart';
import '../widgets/sensor_card.dart';
import '../widgets/liquid_water_level.dart';

class SensorsScreen extends ConsumerWidget {
  const SensorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmDataAsync = ref.watch(farmDataStreamProvider);

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
      child: farmDataAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF06B6D4))
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(duration: 1500.ms),
              const SizedBox(height: 16),
              Text(
                "Veriler yükleniyor...",
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FontAwesomeIcons.triangleExclamation,
                color: AppTheme.dangerColor,
                size: 48,
              ).animate().shake(duration: 500.ms),
              const SizedBox(height: 16),
              Text(
                "Veri Hatası: $err",
                style: TextStyle(color: AppTheme.dangerColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        data: (farmData) {
          // Danger detection
          final isDangerSituation =
              farmData.detectedObject?.toLowerCase().contains('tehlike') ==
              true;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with gradient
                ShaderMask(
                      shaderCallback: (bounds) =>
                          AppTheme.primaryGradient.createShader(bounds),
                      child: Text(
                        "Sensör Verileri",
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideX(begin: -0.2, end: 0),
                const SizedBox(height: 20),

                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 1.6,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      SensorCard(
                        title: "Sıcaklık",
                        value: "${farmData.temperature}°C",
                        icon: FontAwesomeIcons.temperatureHalf,
                        color: _getTemperatureColor(
                          farmData.temperature.toInt(),
                        ),
                        isDanger: farmData.temperature > 35,
                      ),
                      SensorCard(
                        title: "Nem",
                        value: "%${farmData.humidity}",
                        icon: FontAwesomeIcons.droplet,
                        color: Colors.blue,
                      ),

                      // Liquid Water Level - SPECIAL WIDGET
                      LiquidWaterLevel(
                        waterLevel: farmData.waterLevel,
                        isDanger: farmData.waterLevel < 30,
                      ),

                    if (farmData.feedLevel != null)
                      SensorCard(
                        title: "Yem Doluluk",
                        value: "${farmData.feedLevel}%",
                        icon: FontAwesomeIcons.wheatAwn,
                        color: _getFeedStockColor(farmData.feedLevel!),
                        isDanger: farmData.feedLevel! < 20,
                        ),
                      if (farmData.lightLevel != null)
                        SensorCard(
                          title: "Işık Seviyesi",
                          value: farmData.lightLevel! > 600 ? "Gece" : "Gündüz",
                          icon: farmData.lightLevel! > 600
                              ? FontAwesomeIcons.moon
                              : FontAwesomeIcons.sun,
                          color: farmData.lightLevel! > 600
                              ? Colors.indigo
                              : Colors.amber,
                        ),
                      if (farmData.soundLevel != null)
                        SensorCard(
                          title: "Ses Seviyesi",
                          value: farmData.soundLevel! > 600
                              ? "Yüksek"
                              : "Normal",
                          icon: FontAwesomeIcons.volumeHigh,
                          color: farmData.soundLevel! > 600
                              ? Colors.red
                              : Colors.green,
                          isDanger: farmData.soundLevel! > 600,
                        ),
                      if (farmData.motorStatus != null)
                        SensorCard(
                          title: "Motor",
                          value: farmData.motorStatus! ? "Çalışıyor" : "Durdu",
                          icon: FontAwesomeIcons.gears,
                          color: farmData.motorStatus!
                              ? Colors.green
                              : Colors.grey,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Footer with status
                Center(
                  child:
                      Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDangerSituation
                                  ? AppTheme.dangerColor.withOpacity(0.2)
                                  : AppTheme.successColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDangerSituation
                                    ? AppTheme.dangerColor
                                    : AppTheme.successColor,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isDangerSituation
                                      ? FontAwesomeIcons.triangleExclamation
                                      : FontAwesomeIcons.circleCheck,
                                  color: isDangerSituation
                                      ? AppTheme.dangerColor
                                      : AppTheme.successColor,
                                  size: 14,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Son Veri: ${farmData.timestamp}",
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate(onPlay: (controller) => controller.repeat())
                          .shimmer(delay: 2000.ms, duration: 1500.ms),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getTemperatureColor(int temp) {
    if (temp > 35) return Colors.red;
    if (temp > 28) return Colors.orange;
    if (temp > 20) return Colors.green;
    return Colors.blue;
  }

  Color _getFeedStockColor(int feedLevel) {
    if (feedLevel < 20) return Colors.red;
    if (feedLevel < 40) return Colors.orange;
    return Colors.green;
  }
}
