// Dosya: lib/models/farm_data.dart
class FarmData {
  final String sourceId;
  final double temperature;
  final double humidity;
  final int waterLevel;
  final int? feedLevel; // Yem doluluk yüzdesi (%0-100)
  final int? distance; // Yem stoğu mesafesi (cm) - eski alan
  final int? lightLevel; // Işık seviyesi (0-1023)
  final int? soundLevel; // Ses seviyesi (0-1023)
  final bool? motorStatus; // Motor durumu
  final bool isDanger;
  final String detectedObject;
  final String? imageBase64;
  final String timestamp;

  FarmData({
    required this.sourceId,
    required this.temperature,
    required this.humidity,
    required this.waterLevel,
    this.feedLevel,
    this.distance,
    this.lightLevel,
    this.soundLevel,
    this.motorStatus,
    required this.isDanger,
    required this.detectedObject,
    this.imageBase64,
    required this.timestamp,
  });

  // Boş başlangıç verisi (Hata almamak için)
  factory FarmData.initial() {
    return FarmData(
      sourceId: "Bağlanıyor...",
      temperature: 0.0,
      humidity: 0.0,
      waterLevel: 0,
      feedLevel: null,
      distance: null,
      lightLevel: null,
      soundLevel: null,
      motorStatus: null,
      isDanger: false,
      detectedObject: "Sistem Başlatılıyor",
      timestamp: "--:--",
    );
  }

  factory FarmData.fromJson(Map<String, dynamic> json) {
    String parseTimestamp(dynamic raw) {
      if (raw == null) return '';
      if (raw is String) return raw;
      return raw.toString();
    }

    return FarmData(
      sourceId: json['source_id'] ?? 'Bilinmiyor',
      temperature: (json['temperature'] ?? 0).toDouble(),
      humidity: (json['humidity'] ?? 0).toDouble(),
      waterLevel: json['water_level'] ?? 0,
      feedLevel: json['feed_level'],
      distance: json['distance'],
      lightLevel: json['light_level'],
      soundLevel: json['sound_level'],
      motorStatus: json['motor_status'],
      isDanger: json['is_danger'] ?? false,
      detectedObject: json['detected_object'] ?? 'Yok',
      imageBase64: json['image_base64'],
      timestamp: parseTimestamp(json['timestamp']),
    );
  }
}
