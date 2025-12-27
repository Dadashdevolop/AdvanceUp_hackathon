class AudioEvent {
  final String label; // 'danger' or 'safe'
  final double confidence;
  final String timestamp;

  AudioEvent({
    required this.label,
    required this.confidence,
    required this.timestamp,
  });

  factory AudioEvent.fromJson(Map<String, dynamic> json) {
    String parseTimestamp(dynamic raw) {
      if (raw == null) return '';
      if (raw is String) return raw;
      return raw.toString();
    }

    return AudioEvent(
      label: json['label'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0).toDouble(),
      timestamp: parseTimestamp(json['timestamp']),
    );
  }
}
