import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';
import '../services/api/api_client.dart';

const _cachedEmailKey = 'cached_email';
const _cachedNicknameKey = 'cached_nickname';

class AuthSession {
  const AuthSession({required this.email, required this.nickname});

  final String email;
  final String nickname;
}

class AuthController extends AsyncNotifier<AuthSession?> {
  AuthRepository get _repo => const AuthRepository();

  @override
  Future<AuthSession?> build() async {
    final token = await ApiClient.instance.getToken();
    if (token == null) return null;

    // 先用本地缓存的昵称/邮箱立即恢复 UI，再后台验证 token
    final prefs = await SharedPreferences.getInstance();
    final cachedEmail = prefs.getString(_cachedEmailKey);
    final cachedNickname = prefs.getString(_cachedNicknameKey);
    final boundAccount = await ApiClient.instance.storedAccount();
    if (cachedEmail != null &&
        cachedNickname != null &&
        cachedEmail.toLowerCase() == boundAccount) {
      // 异步验证 token，失效才清除
      _repo
          .me()
          .then((profile) async {
            if (await ApiClient.instance.getToken() != token) return;
            if (profile == null) {
              await ApiClient.instance.clearToken();
              await _clearCache();
              state = const AsyncData(null);
            }
          })
          .catchError((Object _) {
            /* 网络故障保留已有登录态 */
          });
      return AuthSession(email: cachedEmail, nickname: cachedNickname);
    }

    // 无本地缓存时走网络
    final profile = await _repo.me();
    if (profile == null) {
      await ApiClient.instance.clearToken();
      return null;
    }
    await _saveCache(email: profile.email, nickname: profile.nickname);
    return AuthSession(email: profile.email, nickname: profile.nickname);
  }

  Future<String?> sendCode(String email) async {
    return _repo.sendCode(email);
  }

  Future<VerifyResult> verifyCode({
    required String email,
    required String code,
    bool enableAi = false,
  }) async {
    final result = await _repo.verifyCode(
      email: email,
      code: code,
      enableAi: enableAi,
    );
    if (!result.isNewUser) {
      await _saveCache(email: result.email, nickname: result.nickname);
      state = AsyncData(
        AuthSession(email: result.email, nickname: result.nickname),
      );
    }
    return result;
  }

  Future<String?> setNickname({
    required String email,
    required String nickname,
  }) async {
    final error = await _repo.setNickname(nickname);
    if (error == null) {
      await _saveCache(email: email, nickname: nickname);
      state = AsyncData(AuthSession(email: email, nickname: nickname));
    }
    return error;
  }

  Future<void> logout() async {
    await _repo.logout();
    await _clearCache();
    state = const AsyncData(null);
  }

  Future<void> accountDeleted() async {
    await ApiClient.instance.clearToken();
    await _clearCache();
    state = const AsyncData(null);
  }

  Future<void> _saveCache({
    required String email,
    required String nickname,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedEmailKey, email);
    await prefs.setString(_cachedNicknameKey, nickname);
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedEmailKey);
    await prefs.remove(_cachedNicknameKey);
  }
}

final authProvider = AsyncNotifierProvider<AuthController, AuthSession?>(
  AuthController.new,
);
