import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flow_er/core/i18n/ui_text.dart';
import 'package:flow_er/providers/settings_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UiText.english = false;
  });
  tearDown(() => UiText.english = false);

  test('language choice is saved and restored', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(settingsProvider);
    await container
        .read(settingsProvider.notifier)
        .setLanguage(AppLanguage.english);
    expect(container.read(settingsProvider).language, AppLanguage.english);
    expect('设置'.tr, 'Settings');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language'), 'english');

    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    restored.read(settingsProvider);
    await Future<void>.delayed(Duration.zero);
    expect(restored.read(settingsProvider).language, AppLanguage.english);
  });

  test('only explicitly marked product copy is translated', () {
    UiText.english = true;
    const journal = '慢下来，听见这一刻。';
    const aiReflection = '此刻不必匆忙。';
    expect('心笺'.tr, 'Journal');
    expect(journal, '慢下来，听见这一刻。');
    expect(aiReflection, '此刻不必匆忙。');
  });
}
