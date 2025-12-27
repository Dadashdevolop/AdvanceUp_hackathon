import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/farm_data.dart';
import '../../providers/farm_provider.dart';

class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmDataAsync = ref.watch(farmDataStreamProvider);

    return farmDataAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      ),
      error: (err, stack) => Center(
        child: Text(
          "Veri Hatası: $err",
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (farmData) {
        final cardTextStyle = GoogleFonts.roboto(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        );

        Color statusColor(bool ok) => ok ? Colors.green : Colors.orange;

        final tarimOk = farmData.humidity >= 30;
        final lojistikOk = farmData.waterLevel >= 30;
        final guvenlikOk = !farmData.isDanger && farmData.temperature < 30;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Sistem Durumu",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF00E676),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _buildStatusModule(
                      title: "Dikey Tarım",
                      value: tarimOk ? "Büyüme Stabil" : "Nem Düşük",
                      color: statusColor(tarimOk),
                      icon: FontAwesomeIcons.seedling,
                      description: "Nem: ${farmData.humidity}%",
                    ),
                    const SizedBox(height: 16),
                    _buildStatusModule(
                      title: "Lojistik & Su",
                      value: lojistikOk ? "Su Yeterli" : "Su Az",
                      color: statusColor(lojistikOk),
                      icon: FontAwesomeIcons.truckRampBox,
                      description: "Su Seviyesi: ${farmData.waterLevel}%",
                    ),
                    const SizedBox(height: 16),
                    _buildStatusModule(
                      title: "Güvenlik",
                      value: guvenlikOk ? "Alan Güvenli" : "Alarm Aktif",
                      color: statusColor(guvenlikOk),
                      icon: FontAwesomeIcons.shieldHalved,
                      description: "Sıcaklık: ${farmData.temperature}°C",
                    ),
                    const SizedBox(height: 16),
                    _buildStatusModule(
                      title: "Kamera",
                      value: farmData.isDanger ? "TEHLİKE!" : "GÜVENLİ",
                      color: farmData.isDanger
                          ? Colors.redAccent
                          : Colors.green,
                      icon: FontAwesomeIcons.video,
                      description: "Tespit: ${farmData.detectedObject}",
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusModule({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 12)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
