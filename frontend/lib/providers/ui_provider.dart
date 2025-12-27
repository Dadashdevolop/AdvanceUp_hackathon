import 'package:flutter_riverpod/flutter_riverpod.dart';

// Bottom navigation index (0: Durum, 1: Sensörler, 2: Kamera, 3: Ses)
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

// Kullanıcının manuel olarak controller'ı durdurduğu zaman
final lastManualStopProvider = StateProvider<DateTime?>((ref) => null);

// Son manuel durdurmadan itibaren 1 dakika boyunca otomatik açma kapalı
final suppressionActiveProvider = Provider<bool>((ref) {
  final ts = ref.watch(lastManualStopProvider);
  final now = DateTime.now();
  if (ts == null) return false;
  return now.difference(ts) < const Duration(minutes: 1);
});
