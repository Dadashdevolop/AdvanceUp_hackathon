import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/farm_data.dart';

class ApiService {
  Future<FarmData?> fetchLatestReading({int limit = 1}) async {
    final uri = Uri.parse('${AppConstants.historyEndpoint}?limit=$limit');
    try {
      final response = await http.get(uri);
      // Detaylı loglar için status ve body
      // ignore: avoid_print
      print('HTTP GET ${uri.toString()} => ${response.statusCode}');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is List && body.isNotEmpty) {
          return FarmData.fromJson(body.first as Map<String, dynamic>);
        }
      } else {
        // ignore: avoid_print
        print('History fetch failed: ${response.body}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('History fetch exception: $e');
    }
    return null;
  }

  Future<bool> startController() async {
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/controller/start');
    try {
      final response = await http.post(
        uri,
        headers: {
          'X-API-Key': 'AgroShield_Secret_2025',
          'Content-Type': 'application/json',
        },
      );
      // ignore: avoid_print
      print('HTTP POST ${uri.toString()} => ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('Start controller error: $e');
      return false;
    }
  }

  Future<bool> stopController() async {
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/controller/stop');
    try {
      final response = await http.post(
        uri,
        headers: {
          'X-API-Key': 'AgroShield_Secret_2025',
          'Content-Type': 'application/json',
        },
      );
      // ignore: avoid_print
      print('HTTP POST ${uri.toString()} => ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('Stop controller error: $e');
      return false;
    }
  }
}
