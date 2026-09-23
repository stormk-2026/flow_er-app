import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/glass_dialog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_providers.dart';
import '../../services/api/api_client.dart';

const privacyText = '''流境隐私说明（2026-09-23）

我们使用邮箱和验证码建立账号，保存昵称、心笺文字、图片与专注记录，以提供跨设备同步和统计。手机保留按账号隔离的本地缓存；云端数据由阿里云基础设施承载。旧版共享数据库不会自动归入新账号，也不会自动上传。

登录或注册前，需要主动勾选同意本说明及《AI 回响功能说明》。邮箱验证成功后，流境为该账号开启 AI 回响：将心笺文字、有限的相关历史文字或专注聚合数据发送给第三方大语言模型服务提供方 Moonshot AI（月之暗面），用于分类、回响和简短总结，不发送心笺图片。未勾选不会发送登录验证码，也不会据此开启 AI。

你可以在「设置 → 隐私与数据」撤回 AI 授权。撤回后停止后续 AI 处理，仍保留记录、云同步和数字统计；已发送的数据无法通过撤回授权收回。再次登录时重新勾选并完成验证，会重新授权 AI 处理。

AI 输出可能不准确，不是心理诊断或医疗建议。请不要填写不必要的敏感信息或他人的隐私。

删除心笺后，各设备在同步成功后移除内容；离线删除会暂存在本地等待同步。注销账号须再次验证邮箱，注销后账号及关联记录从业务数据库删除。备份及图片清理的最终期限将随正式发布的保留策略一并说明；本说明仍属于内测版本，未声明第三方服务的训练或保留政策。

旧版共享文件会保留在原设备用于人工核对，不会因切换账号而自动删除。

隐私与数据问题联系邮箱：gg5605568@gmail.com''';

const aiDisclosureText = '''AI 回响功能说明（2026-09-23）

流境使用第三方大语言模型（LLM）服务生成心笺分类、卡片背面的回响及简短总结。这是把内容交给第三方 AI 处理，不是公开发布给其他用户。

服务提供方与数据接收方：Moonshot AI（月之暗面）。

处理的数据：你写下的心笺文字、有限的相关历史文字，以及专注次数、时长等聚合数据。当前不向模型发送心笺图片。请不要输入不必要的敏感信息或他人的隐私。

授权方式：登录页的勾选框默认不勾选。勾选“我已阅读并同意《隐私说明》和《AI 回响功能说明》”代表同意上述第三方处理；完成邮箱验证后，将该授权保存到你的账号。仅阅读说明不会授权，未通过邮箱验证也不会据此开启 AI。

授权持续有效，无需每篇心笺重复确认。开启授权不会自动补生成此前未授权的旧心笺。你可以在「设置 → 隐私与数据」撤回授权，停止后续 AI 处理；已发送的数据无法通过撤回授权收回。撤回不删除心笺，也不影响云同步和数字统计。再次登录时重新勾选并完成验证，会重新授权。

AI 内容可能不准确，仅供自我记录与思考参考，不是心理诊断、医疗建议或事实保证。

本说明仍属内测版本，第三方数据保留、删除及保护承诺尚需在正式发布前核实补齐；不作“绝不留存”或“不用于训练”的未经核实承诺。

隐私与数据问题联系邮箱：gg5605568@gmail.com''';

/// Public disclosure, available before login without requesting account data.
class PrivacyNoticePage extends StatelessWidget {
  const PrivacyNoticePage({super.key, this.showAiDisclosure = false});
  final bool showAiDisclosure;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(showAiDisclosure ? 'AI 回响功能说明' : '隐私说明')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SelectableText(
          showAiDisclosure ? aiDisclosureText : privacyText,
          style: const TextStyle(height: 1.8),
        ),
      ),
    ),
  );
}

class PrivacyPage extends ConsumerStatefulWidget {
  const PrivacyPage({super.key});
  @override
  ConsumerState<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends ConsumerState<PrivacyPage> {
  bool? _enabled;
  bool _busy = false;
  final _code = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/api/v1/auth/me',
      );
      if (mounted) {
        setState(() => _enabled = response.data?['ai_consent'] == true);
      }
    } catch (_) {
      if (mounted) _message('暂时无法读取授权状态');
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _toggle(bool value) async {
    if (_busy) return;
    if (value) {
      final yes = await showGlassDialog(
        context: context,
        title: '允许 AI 生成回响？',
        message:
            '将心笺文字、有限历史或专注聚合数据发送给第三方大语言模型服务提供方 Moonshot AI（月之暗面）进行分析，不发送心笺图片。你可以随时撤回授权；不同意不影响记录和同步。',
        confirmLabel: '同意并开启',
        cancelLabel: '暂不开启',
      );
      if (yes != true || !mounted) return;
    } else {
      final yes = await showGlassDialog(
        context: context,
        title: '撤回 AI 授权？',
        message: '停止后续 AI 回响与总结，不删除心笺，也不影响云同步和数字统计。已发送给第三方模型服务的数据无法通过此操作收回。',
        confirmLabel: '撤回授权',
        cancelLabel: '保留授权',
      );
      if (yes != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await ApiClient.instance.dio.put<void>(
        '/api/v1/auth/ai-consent',
        data: {'enabled': value},
      );
      if (mounted) {
        setState(() => _enabled = value);
        invalidateAnalyticsWidgetProviders(ref);
      }
    } catch (_) {
      if (mounted) _message('设置未保存，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final yes = await showGlassDialog(
      context: context,
      title: '注销账号？',
      message: '这将删除云端账号与关联心笺、专注记录，并清理当前账号的新版本地缓存。操作不可撤销。请先在下方填写邮箱验证码。',
      confirmLabel: '确认注销',
      cancelLabel: '保留账号',
      destructive: true,
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final db = ref.read(databaseProvider);
      await ApiClient.instance.dio.post<void>(
        '/api/v1/auth/delete-account',
        data: {'code': _code.text.trim()},
      );
      await db.transaction(() async {
        await db.delete(db.flowIntents).go();
        await db.delete(db.focusSessions).go();
      });
      await ref.read(authProvider.notifier).accountDeleted();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) _message('注销未完成，请检查验证码及网络后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authProvider).valueOrNull?.email;
    return Scaffold(
      appBar: AppBar(title: const Text('隐私与数据')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SelectableText(privacyText),
          const SizedBox(height: 24),
          if (email != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('AI 回响功能说明'),
              subtitle: Text(
                _enabled == null
                    ? '授权状态读取中'
                    : _enabled!
                    ? '已授权'
                    : '尚未授权',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const PrivacyNoticePage(showAiDisclosure: true),
                ),
              ),
            ),
            TextButton(
              onPressed: _enabled == null || _busy
                  ? null
                  : () => _toggle(!_enabled!),
              child: Text(_enabled == true ? '撤回 AI 授权' : '阅读并授权 AI 回响'),
            ),
            const Divider(),
            const Text('注销前需验证当前登录邮箱'),
            TextField(
              controller: _code,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '邮箱验证码'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final error = await ref
                          .read(authProvider.notifier)
                          .sendCode(email);
                      if (mounted) _message(error ?? '验证码已发送');
                    },
              child: const Text('发送注销验证码'),
            ),
            TextButton(
              onPressed: _busy ? null : _delete,
              child: const Text('注销账号'),
            ),
          ],
        ],
      ),
    );
  }
}
