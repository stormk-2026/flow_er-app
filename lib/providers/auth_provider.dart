import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';
import '../services/api/api_client.dart';

const _cachedPhoneKey = 'cached_phone';
const _cachedNicknameKey = 'cached_nickname';

class AuthSession {
  const AuthSession({
    required this.phone,
    required this.nickname,
  });

  final String phone;
  final String nickname;
}

class AuthController extends AsyncNotifier<AuthSession?> {
  AuthRepository get _repo => const AuthRepository();

  @override
  Future<AuthSession?> build() async {
    final token = await ApiClient.instance.getToken();
    if (token == null) return null;

    // 先用本地缓存的昵称/手机号立即恢复 UI，再后台验证 token
    final prefs = await SharedPreferences.getInstance();
    final cachedPhone = prefs.getString(_cachedPhoneKey);
    final cachedNickname = prefs.getString(_cachedNicknameKey);
    if (cachedPhone != null && cachedNickname != null) {
      // 异步验证 token，失效才清除
      _repo.me().then((profile) async {
        if (profile == null) {
          await ApiClient.instance.clearToken();
          await _clearCache();
          state = const AsyncData(null);
        }
      });
      return AuthSession(phone: cachedPhone, nickname: cachedNickname);
    }

    // 无本地缓存时走网络
    final profile = await _repo.me();
    if (profile == null) {
      await ApiClient.instance.clearToken();
      return null;
    }
    await _saveCache(phone: profile.phone, nickname: profile.nickname);
    return AuthSession(phone: profile.phone, nickname: profile.nickname);
  }

  Future<String?> sendCode(String phone) async {
    return _repo.sendCode(phone);
  }

  Future<VerifyResult> verifyCode({
    required String phone,
    required String smsCode,
  }) async {
    final result = await _repo.verifyCode(phone: phone, smsCode: smsCode);
    if (!result.isNewUser) {
      await _saveCache(phone: phone, nickname: result.nickname);
      state = AsyncData(AuthSession(phone: phone, nickname: result.nickname));
    }
    return result;
  }

  Future<String?> setNickname({
    required String phone,
    required String nickname,
  }) async {
    final error = await _repo.setNickname(nickname);
    if (error == null) {
      await _saveCache(phone: phone, nickname: nickname);
      state = AsyncData(AuthSession(phone: phone, nickname: nickname));
    }
    return error;
  }

  Future<void> logout() async {
    await _repo.logout();
    await _clearCache();
    state = const AsyncData(null);
  }

  Future<void> _saveCache({
    required String phone,
    required String nickname,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedPhoneKey, phone);
    await prefs.setString(_cachedNicknameKey, nickname);
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedPhoneKey);
    await prefs.remove(_cachedNicknameKey);
  }
}

final authProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);
