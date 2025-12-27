import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../config/constants.dart';
import '../models/audio_event.dart';

class AudioService {
  final Record _recorder = Record();
  bool _initialized = false;
  bool _running = false;
  final _controller = StreamController<AudioEvent>.broadcast();

  Stream<AudioEvent> get stream => _controller.stream;

  Future<bool> _initRecorder() async {
    if (_initialized) return true;
    try {
      final status = await Permission.microphone.request();
      // ignore: avoid_print
      print('[Mikrofon] İzin durumu: $status');
      if (!status.isGranted) {
        // ignore: avoid_print
        print('[Mikrofon] İzin reddedildi: $status');
        return false;
      }
      _initialized = true;
      // ignore: avoid_print
      print('[Mikrofon] Hazır (record package)');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('[Mikrofon] Init hatası: $e');
      return false;
    }
  }

  Future<void> startListening({
    Duration recordDuration = const Duration(seconds: 3),
    Duration gap = const Duration(seconds: 1),
  }) async {
    if (!await _initRecorder()) {
      // ignore: avoid_print
      print('Ses kaydı başlatılamadı');
      return;
    }

    if (_running) {
      // ignore: avoid_print
      print('Zaten dinleniyor, tekrar başlatılmadı');
      return;
    }

    // ignore: avoid_print
    print(
      'Gerçek mikrofon kaydı başlatıldı (record package, 3s kayıt + 1s bekle döngüsü)',
    );
    _running = true;
    _runLoop(recordDuration, gap);
  }

  void _runLoop(Duration recordDuration, Duration gap) async {
    while (_running) {
      // 3 saniye kayıt ve gönder
      await _captureAndSendFor(recordDuration);

      // 1 saniye bekle
      if (!_running) break;
      await Future.delayed(gap);
    }
  }

  Future<void> _captureAndSendFor(Duration duration) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/audio_$timestamp.wav';

      // ignore: avoid_print
      print('[Kayıt] Başlıyor: $filePath (record package)');

      // Kaydı başlat
      try {
        await _recorder.start(
          path: filePath,
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          samplingRate: 16000,
          numChannels: 1,
        );
        // ignore: avoid_print
        print('[Kayıt] Başladı, PCM16 WAV');
      } catch (e) {
        // ignore: avoid_print
        print('[Kayıt] Başlama hatası: $e');
        rethrow;
      }

      // İstenen süre kadar kaydet
      await Future.delayed(duration);

      // Kaydı durdur
      try {
        final path = await _recorder.stop();
        if (path == null || path.isEmpty) {
          // ignore: avoid_print
          print('[Kayıt] Kayıt yolu boş döndü');
          return;
        }

        // Native layer'ın dosyayı finalize etmesi için bekle
        await Future.delayed(const Duration(milliseconds: 200));

        final file = File(path);
        final fileSize = await file.length();
        // ignore: avoid_print
        print('[Audio] Recorded file size: ${fileSize} bytes');
        if (fileSize <= 44) {
          // ignore: avoid_print
          print('[WARNING] Çok küçük dosya! Ses kaydedilmedi mi?');
        }

        final bytes = await file.readAsBytes();
        final b64 = base64Encode(bytes);
        // ignore: avoid_print
        final prefixLen = b64.length < 50 ? b64.length : 50;
        print(
          '[Audio] Base64 length: ${b64.length}, content prefix: ${b64.substring(0, prefixLen)}',
        );

        // Backend'e gönder
        final uri = Uri.parse(AppConstants.audioAnalyzeEndpoint);
        final resp = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': 'AgroShield_Secret_2025',
          },
          body: jsonEncode({'audio_base64': b64}),
        );

        // ignore: avoid_print
        print('Ses POST => ${resp.statusCode}');
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final event = AudioEvent.fromJson(data);
          _controller.add(event);
        }

        // Dosyayı sil
        try {
          await file.delete();
        } catch (_) {}
      } catch (e) {
        // ignore: avoid_print
        print('[Kayıt] Durdurma hatası: $e');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Ses kaydı/gönder hatası: $e');
    }
  }

  Future<void> stopListening() async {
    _running = false;
    try {
      await _recorder.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stopListening();
    await _recorder.dispose();
    _initialized = false;
  }
}
