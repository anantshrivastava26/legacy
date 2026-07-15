import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown for any non-2xx API response, with a user-friendly message.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? body;

  ApiException(this.statusCode, this.message, [this.body]);

  @override
  String toString() => message;
}

/// HTTP client with JWT auth and automatic refresh-token rotation.
class ApiClient {
  /// Change this to your Railway backend URL after deploying, e.g.
  /// https://familytree-backend-production.up.railway.app
  static const String baseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');

  String? _accessToken;
  String? _refreshToken;

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');
    _refreshToken = prefs.getString('refreshToken');
  }

  bool get hasSession => _refreshToken != null;

  Future<void> saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', access);
    await prefs.setString('refreshToken', refresh);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retried = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    late http.Response res;
    final encoded = body != null ? jsonEncode(body) : null;

    switch (method) {
      case 'GET':
        res = await http.get(uri, headers: _headers());
        break;
      case 'POST':
        res = await http.post(uri, headers: _headers(), body: encoded);
        break;
      case 'PATCH':
        res = await http.patch(uri, headers: _headers(), body: encoded);
        break;
      case 'DELETE':
        res = await http.delete(uri, headers: _headers());
        break;
      default:
        throw ArgumentError('Unsupported method $method');
    }

    // Try one silent refresh on 401
    if (res.statusCode == 401 && !retried && _refreshToken != null) {
      final ok = await _tryRefresh();
      if (ok) return _request(method, path, body: body, retried: true);
    }

    final Map<String, dynamic> json = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>)
        : <String, dynamic>{};

    if (res.statusCode >= 200 && res.statusCode < 300) return json;

    throw ApiException(
      res.statusCode,
      json['error']?.toString() ?? 'Something went wrong. Please try again.',
      json,
    );
  }

  Future<bool> _tryRefresh() async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      );
      if (res.statusCode != 200) {
        await clearTokens();
        return false;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      await saveTokens(json['accessToken'], json['refreshToken']);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) =>
      _request('POST', path, body: body ?? {});
  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _request('PATCH', path, body: body);
  Future<Map<String, dynamic>> delete(String path) => _request('DELETE', path);
}
