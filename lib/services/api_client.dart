import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiClient {
  // ⚠️ CRITICAL: This changes based on where you run
  //
  // 10.0.2.2 = Android Emulator → your PC's localhost
  // localhost = Web (Chrome) → your PC's localhost
  // 192.168.x.x = Real phone on WiFi → your PC's IP

  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2/adsb_api/api';
    } else if (Platform.isIOS) {
      return 'http://localhost/adsb_api/api';
    } else {
      return 'http://localhost/adsb_api/api'; // Web
    }
  }

  static Future<Map<String, dynamic>> post(
      String endpoint,
      Map<String, dynamic> body,
      ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Server error (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> get(
      String endpoint, {
        Map<String, String>? query,
      }) async {
    try {
      final uri = Uri.parse('$baseUrl/$endpoint').replace(queryParameters: query);
      final response = await http.get(uri);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Server error (${response.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection failed: $e'};
    }
  }
}