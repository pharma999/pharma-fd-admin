import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'token_storage.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        h['Authorization'] = 'Bearer $token';
      }
    }
    return h;
  }

  dynamic _handle(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode == 401) {
      TokenStorage.clear();
      throw ApiException('Session expired. Please login again.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
          body['message'] ?? body['error'] ?? 'Error ${res.statusCode}');
    }
    return body;
  }

  Future<dynamic> get(String endpoint,
      {Map<String, String>? query}) async {
    var uri = Uri.parse('${ApiConfig.baseUrl}/$endpoint');
    if (query != null) uri = uri.replace(queryParameters: query);
    final res = await http
        .get(uri, headers: await _headers())
        .timeout(Duration(seconds: ApiConfig.timeoutSec));
    return _handle(res);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body,
      {bool auth = true}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/$endpoint');
    final res = await http
        .post(uri, headers: await _headers(auth: auth), body: jsonEncode(body))
        .timeout(Duration(seconds: ApiConfig.timeoutSec));
    return _handle(res);
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/$endpoint');
    final res = await http
        .put(uri, headers: await _headers(), body: jsonEncode(body))
        .timeout(Duration(seconds: ApiConfig.timeoutSec));
    return _handle(res);
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/$endpoint');
    final req = http.Request('PATCH', uri);
    req.headers.addAll(await _headers());
    req.body = jsonEncode(body);
    final streamed = await req.send().timeout(Duration(seconds: ApiConfig.timeoutSec));
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/$endpoint');
    final res = await http
        .delete(uri, headers: await _headers())
        .timeout(Duration(seconds: ApiConfig.timeoutSec));
    return _handle(res);
  }
}
