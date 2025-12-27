class AppConstants {
  // DİKKAT: Başında https:// YOK, sonunda / YOK. Sadece domain.
  static const String serverDomain =
      "uninduced-unequilateral-toshia.ngrok-free.dev";

  // Ngrok SSL (https) sağladığı için wss:// (Secure WebSocket) kullanıyoruz.
  static const String socketUrl = "wss://$serverDomain/ws/dashboard";

  // REST tabanlı istekler için temel adres
  static const String apiBaseUrl = "https://$serverDomain";

  // En son geçmiş verisini almak için uç nokta
  static const String historyEndpoint = "$apiBaseUrl/api/history";

  // Ses analizi için uç nokta
  static const String audioAnalyzeEndpoint = "$apiBaseUrl/api/audio/analyze";
}
