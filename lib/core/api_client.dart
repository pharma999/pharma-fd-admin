import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:home_care_admin/core/token_storage.dart';

class ApiClient {
  static const String _serverLanIp = '192.168.1.7';

  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kIsWeb) return 'http://localhost:8080/api';
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://$_serverLanIp:8080/api';
    }
    return 'http://localhost:8080/api';
  }

  static Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> get(String path) async {
    try {
      final headers = await _headers();
      final response = await http
          .get(Uri.parse('$baseUrl$path'), headers: headers)
          .timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Request failed: $e');
    }
  }

  static Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Request failed: $e');
    }
  }

  static Future<Map<String, dynamic>> patch(
      String path, Map<String, dynamic> body) async {
    try {
      final headers = await _headers();
      final response = await http
          .patch(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Request failed: $e');
    }
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    try {
      final headers = await _headers();
      final response = await http
          .delete(Uri.parse('$baseUrl$path'), headers: headers)
          .timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Request failed: $e');
    }
  }

  static Future<String> uploadFile(String filePath) async {
    try {
      final token = await TokenStorage.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload'),
      );
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final url = (data['data'] as Map<String, dynamic>?)?['url'] as String? ??
            data['url'] as String? ??
            '';
        return url;
      } else {
        String errorMessage = 'Upload failed: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage = errorData['error'] as String? ??
              errorData['message'] as String? ??
              errorMessage;
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Upload failed: $e');
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'data': decoded};
      } catch (_) {
        return {'raw': response.body};
      }
    } else {
      String errorMessage = 'Request failed with status ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = errorData['error'] as String? ??
            errorData['message'] as String? ??
            errorMessage;
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }
}
