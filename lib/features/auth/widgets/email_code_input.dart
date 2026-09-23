import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// One native editor preserves paste/autofill; six equal cells present the code.
class EmailCodeInput extends StatefulWidget {
  const EmailCodeInput({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmitted;

  @override
  State<EmailCodeInput> createState() => _EmailCodeInputState();
}

class _EmailCodeInputState extends State<EmailCodeInput> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _focus]),
      builder: (context, _) {
        final code = widget.controller.text;
        final caret = widget.controller.selection.extentOffset;
        final active = (caret < 0 ? code.length : caret).clamp(0, 5);
        return Column(
          children: [
            Text(
              '输入 6 位验证码',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansSc(
                fontSize: 13,
                letterSpacing: 0.3,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 58,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Exclude decorative digits: the native field reads the code
                  // once to assistive technology and accepts the whole OTP.
                  ExcludeSemantics(
                    child: Row(
                      children: [
                        for (var i = 0; i < 6; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: AnimatedContainer(
                              key: ValueKey('otp-cell-$i'),
                              duration: const Duration(milliseconds: 160),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      widget.enabled &&
                                          _focus.hasFocus &&
                                          i == active
                                      ? AppColors.primaryAction.withValues(
                                          alpha: 0.7,
                                        )
                                      : AppColors.divider,
                                ),
                              ),
                              child: Text(
                                i < code.length ? code[i] : '·',
                                style: GoogleFonts.notoSansSc(
                                  fontSize: i < code.length ? 24 : 18,
                                  fontWeight: FontWeight.w400,
                                  color: i < code.length
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted.withValues(
                                          alpha: 0.4,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Semantics(
                    label: '6 位邮箱验证码',
                    child: TextField(
                      key: const ValueKey('email-code-editor'),
                      controller: widget.controller,
                      focusNode: _focus,
                      autofocus: true,
                      enabled: widget.enabled,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      // The accessible, full-width editor is also the touch target.
                      style: const TextStyle(
                        color: Colors.transparent,
                        fontSize: 24,
                      ),
                      showCursor: false,
                      textAlign: TextAlign.center,
                      expands: true,
                      maxLines: null,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => widget.onSubmitted(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
