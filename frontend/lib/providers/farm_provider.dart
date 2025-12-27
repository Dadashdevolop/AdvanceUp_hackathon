// Dosya: lib/providers/farm_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/farm_data.dart';
import '../services/websocket_service.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../models/audio_event.dart';

// Servisi sağlayan provider
final webSocketServiceProvider = Provider((ref) => WebSocketService());
final apiServiceProvider = Provider((ref) => ApiService());
final audioServiceProvider = Provider((ref) => AudioService());

// Bağlantı durumunu dinleyen provider
final connectionStatusProvider = StreamProvider.autoDispose<ConnectionStatus>((
  ref,
) {
  final service = ref.watch(webSocketServiceProvider);
  return service.statusStream;
});

// Ses analizi akışı
final audioEventStreamProvider = StreamProvider.autoDispose<AudioEvent>((ref) {
  final audio = ref.watch(audioServiceProvider);
  // Başlat
  audio.startListening();
  // Temizlik
  ref.onDispose(() => audio.stopListening());
  return audio.stream;
});

// Stream'i dinleyen provider (UI bunu dinleyecek)
final farmDataStreamProvider = StreamProvider.autoDispose<FarmData>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  final apiService = ref.watch(apiServiceProvider);

  ref.onDispose(() => wsService.close());

  return Stream<FarmData>.multi((controller) async {
    // İlk ekranda boş beklememek için REST ile son veriyi çek
    final initial = await apiService.fetchLatestReading(limit: 1);
    if (initial != null) {
      controller.add(initial);
    }

    await for (final data in wsService.getFarmDataStream()) {
      controller.add(data);
    }
  });
});
