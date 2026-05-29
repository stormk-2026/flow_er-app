import 'package:dio/dio.dart';

import '../services/api/api_client.dart';

class AuthRepository {
  const AuthRepository();

  Dio get _dio => ApiClient.instance.dio;

  /// 发送短信验证码。返回错误信息，null 表示成功。
  Future<String?> sendCode(String phone) async {
    try {
      await _dio.post<void>(
        '/api/v1/auth/send-code',
        data: {'phone': phone},
      );
      return null;
    } on DioException catch (e) {
      return _extractError(e) ?? '发送失败，请稍后重试';
    }
  }

  /// 验证短信验证码。成功返回 [VerifyResult]，失败抛出错误信息。
  Future<VerifyResult> verifyCode({
    required String phone,
    required String smsCode,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/verify-code',
      data: {'phone': phone, 'sms_code': smsCode},
    );
    final data = resp.data!;
    final token = data['token'] as String;
    await ApiClient.instance.saveToken(token);
    return VerifyResult(
      token: token,
      isNewUser: data['is_new_user'] as bool? ?? false,
      nickname: data['user']?['nickname'] as String? ?? '',
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
      return _extractError(e) ?? '设置失败，请稍后重试';
    }
  }

  /// 获取当前用户信息。
  Future<UserProfile?> me() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/api/v1/auth/me');
      final data = resp.data!;
      return UserProfile(
        id: data['id'] as String,
        phone: data['phone'] as String,
        nickname: data['nickname'] as String? ?? '',
      );
    } on DioException {
      return null;
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

  String? _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return data['detail']?.toString();
    }
    return null;
  }
}

class VerifyResult {
  const VerifyResult({
    required this.token,
    required this.isNewUser,
    required this.nickname,
  });

  final String token;
  final bool isNewUser;
  final String nickname;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    required this.nickname,
  });

  final String id;
  final String phone;
  final String nickname;
}
