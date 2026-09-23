import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://47.114.112.184:8000',
);
const _tokenKey = 'auth_token';

/// 全局单例 API 客户端，统一处理 base URL、Bearer token、错误格式。
class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token =
              options.extra['fixedToken'] as String? ?? await getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
  }

  static final instance = ApiClient._();

  late final Dio _dio;
  static const _secure = FlutterSecureStorage();

  Dio get dio => _dio;

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(
      _tokenKey,
    ); // Legacy shared token requires a fresh sign-in.
    final session = await _readSession();
    return session?['token'];
  }

  Future<Map<String, String>?> _readSession() async {
    final raw = await _secure.read(key: _tokenKey);
    if (raw == null) return null;
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<String?> storedAccount() async => (await _readSession())?['account'];

  Future<void> saveToken(String token, {required String account}) async {
    final prefs = await SharedPreferences.getInstance();
    // Token and owner change atomically; no window with B's token and A's owner.
    await _secure.write(
      key: _tokenKey,
      value: jsonEncode({'token': token, 'account': account.toLowerCase()}),
    );
    await prefs.remove(_tokenKey);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await _secure.delete(key: _tokenKey);
  }

  /// Bind background work to the account that created it, never a later login.
  Future<Options> accountOptions(String? account) async {
    final session = await _readSession();
    if (account == null ||
        session == null ||
        session['account'] != account.toLowerCase()) {
      throw StateError('Account changed or signed out');
    }
    return Options(extra: {'fixedToken': session['token']});
  }
}
