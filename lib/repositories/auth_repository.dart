import 'package:flow_er/core/i18n/ui_text.dart';
import 'package:dio/dio.dart';

import '../services/api/api_client.dart';

class AuthRepository {
  const AuthRepository({Dio? dio}) : _client = dio;

  final Dio? _client;
  Dio get _dio => _client ?? ApiClient.instance.dio;

  /// 发送邮箱验证码。返回错误信息，null 表示成功。
  Future<String?> sendCode(String email) async {
    try {
      await _dio.post<void>('/api/v1/auth/send-code', data: {'email': email});
      return null;
    } on DioException catch (e) {
      return authErrorMessage(e);
    }
  }

  /// 验证邮箱验证码。成功返回 [VerifyResult]，失败抛出错误信息。
  Future<VerifyResult> verifyCode({
    required String email,
    required String code,
    bool enableAi = false,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/verify-code',
      data: {'email': email, 'code': code},
    );
    final data = resp.data!;
    final token = data['token'] as String;
    var aiConsentSaveFailed = false;
    // Apply an explicit opt-in to the verified account before exposing its
    // session to background sync. An unchecked box preserves existing consent.
    if (enableAi && data['user']['ai_consent'] != true) {
      try {
        await _dio.put<void>(
          '/api/v1/auth/ai-consent',
          data: {'enabled': true},
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
            extra: {'fixedToken': token},
          ),
        );
      } on DioException {
        // The OTP has already been consumed. Keep login usable, but report that
        // consent was not confirmed; never pretend AI was successfully enabled.
        aiConsentSaveFailed = true;
      }
    }
    await ApiClient.instance.saveToken(
      token,
      account: data['user']['email'] as String,
    );
    return VerifyResult(
      token: token,
      isNewUser: data['is_new_user'] as bool? ?? false,
      nickname: data['user']?['nickname'] as String? ?? '',
      email: data['user']['email'] as String,
      aiConsentSaveFailed: aiConsentSaveFailed,
    );
  }

  /// 新用户设置昵称（已有 token）。返回错误信息，null 表示成功。
  Future<String?> setNickname(String nickname) async {
    try {
      await _dio.post<void>(
        '/api/v1/auth/set-nickname',
        data: {'nickname': nickname},
      );
      return null;
    } on DioException catch (e) {
      return authErrorMessage(e);
    }
  }

  /// 获取当前用户信息。
  Future<UserProfile?> me() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/auth/me');
      final data = resp.data!;
      return UserProfile(
        id: data['id'] as String,
        email: data['email'] as String,
        nickname: data['nickname'] as String? ?? '',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return null;
      }
      rethrow;
    }
  }

  /// 登出，清除本地 token。
  Future<void> logout() async {
    try {
      await _dio.post<void>('/api/v1/auth/logout');
    } on DioException {
      // 登出即便后端失败也清本地 token
    }
    await ApiClient.instance.clearToken();
  }
}

class VerifyResult {
  const VerifyResult({
    required this.token,
    required this.isNewUser,
    required this.email,
    required this.nickname,
    this.aiConsentSaveFailed = false,
  });

  final String token;
  final bool isNewUser;
  final String email;
  final String nickname;
  final bool aiConsentSaveFailed;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.nickname,
  });

  final String id;
  final String email;
  final String nickname;
}

String authErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    final detail = data is Map ? data['detail'] : null;
    if (detail is Map && detail['message'] is String) {
      return detail['message'] as String;
    }
    if (error.response?.statusCode == 422) return '请检查邮箱和验证码格式'.tr;
    if (error.response?.statusCode == 429) return '请求过于频繁，请稍后再试'.tr;
    if (error.response == null) return '网络连接失败，请检查网络后重试'.tr;
  }
  return '操作暂未完成，请稍后重试'.tr;
}
