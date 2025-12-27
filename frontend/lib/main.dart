import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'views/dashboard/dashboard_screen.dart';
import 'services/notification_service.dart';
import 'providers/ui_provider.dart';
import 'providers/farm_provider.dart';
import 'services/api_service.dart';
import 'config/theme.dart';

void main() {
  runApp(
    // Riverpod'un çalışması için uygulamayı ProviderScope ile sarmalıyoruz
    const ProviderScope(child: MyApp()),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Bildirim servisini başlat ve tıklama aksiyonunu ayarla
    NotificationService().init(navigatorKey: _navigatorKey).then((_) {
      NotificationService().setOnTapOpenCamera(() async {
        // Kamera sekmesine geç
        ref.read(bottomNavIndexProvider.notifier).state = 2;
        // Controller'ı başlat
        final api = ref.read(apiServiceProvider);
        await api.startController();
      });
    });

    // WebSocket otomatik başlar farm provider içerisinde
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Agro-Shield Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const DashboardScreen(),
    );
  }
}
