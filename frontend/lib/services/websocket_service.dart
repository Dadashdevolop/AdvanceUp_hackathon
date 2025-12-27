import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/constants.dart';
import '../models/farm_data.dart';

enum ConnectionStatus { connecting, connected, disconnected, error }

class WebSocketService {
  WebSocketChannel? _channel;
  bool _shouldReconnect = true;
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  Stream<FarmData> getFarmDataStream() async* {
    int attempt = 0;
    final backoffs = <Duration>[
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 5),
      const Duration(seconds: 10),
    ];

    while (_shouldReconnect) {
      _statusController.add(ConnectionStatus.connecting);
      final uri = Uri.parse(AppConstants.socketUrl);
      // ignore: avoid_print
      print('WS connecting to ${uri.toString()} (attempt $attempt)');
      try {
        _channel = WebSocketChannel.connect(uri);
        _statusController.add(ConnectionStatus.connected);
        // ignore: avoid_print
        print('WS connected');

        await for (final data in _channel!.stream) {
          try {
            final Map<String, dynamic> jsonData = jsonDecode(data);
            final farmData = FarmData.fromJson(jsonData);
            // ignore: avoid_print
            print('📊 WS veri alındı: ${farmData.detectedObject}');
            yield farmData;
          } catch (e) {
            _statusController.add(ConnectionStatus.error);
            // ignore: avoid_print
            print('WS JSON parse error: $e | Raw: $data');
          }
        }

        // Stream tamamlandıysa bağlantı koptu demektir
        _statusController.add(ConnectionStatus.disconnected);
        // ignore: avoid_print
        print('WS disconnected');
      } catch (e) {
        _statusController.add(ConnectionStatus.error);
        // ignore: avoid_print
        print('WS connection error: $e');
      }

      // Geriye doğru deneme (backoff)
      attempt = (attempt + 1).clamp(0, backoffs.length - 1);
      await Future.delayed(backoffs[attempt]);
    }
  }

  void close() {
    _shouldReconnect = false;
    _channel?.sink.close();
    _statusController.add(ConnectionStatus.disconnected);
    _statusController.close();
  }
}
