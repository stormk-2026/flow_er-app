import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../settings/privacy_page.dart';

class AuthConsentSection extends StatelessWidget {
  const AuthConsentSection({
    super.key,
    required this.privacyAccepted,
    required this.enabled,
    required this.onPrivacyChanged,
  });

  final bool privacyAccepted;
  final bool enabled;
  final ValueChanged<bool> onPrivacyChanged;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.notoSansSc(
      fontSize: 12,
      height: 1.6,
      color: AppColors.textSecondary,
    );
    Widget link(String label, {bool ai = false}) => TextButton(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryAction,
        textStyle: style,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        minimumSize: const Size(0, 40),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PrivacyNoticePage(showAiDisclosure: ai),
        ),
      ),
      child: Text(label),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          key: const ValueKey('privacy-consent'),
          value: privacyAccepted,
          semanticLabel: '我已阅读并同意隐私说明和 AI 回响功能说明',
          activeColor: const Color(0xFF516356),
          onChanged: enabled
              ? (value) => onPrivacyChanged(value ?? false)
              : null,
        ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('我已阅读并同意', style: style),
              link('《隐私说明》'),
              Text('和', style: style),
              link('《AI 回响功能说明》', ai: true),
            ],
          ),
        ),
      ],
    );
  }
}
