import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();
  VoidCallback? _onTapOpenCamera;

  Future<void> init({required GlobalKey<NavigatorState> navigatorKey}) async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );

    await _fln.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload ?? '';
        if (payload == 'open_camera') {
          _onTapOpenCamera?.call();
        }
      },
    );

    // Android 13+ Bildirim izinleri
    await _fln
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  void setOnTapOpenCamera(VoidCallback onTap) {
    _onTapOpenCamera = onTap;
  }

  Future<void> showMotionDetectedNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'agroshield_motion_channel',
          'Hareket Bildirimleri',
          channelDescription: 'Hareket algılandığında bildirim gönderir',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _fln.show(
      1001,
      'Hareket Algılandı',
      'Kamerayı açmak için dokunun',
      details,
      payload: 'open_camera',
    );
  }
}
