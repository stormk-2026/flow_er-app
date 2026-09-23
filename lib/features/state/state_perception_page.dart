import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/focus/focus_entry_hint.dart';
import '../../core/greeting/home_greeting.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/day_night_theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/audio/app_audio_service.dart';
import '../../services/sensors/focus_sensor_service.dart';
import 'widgets/thought_capture_overlay.dart';
import 'widgets/flow_sound_icon.dart';

enum _FocusTrigger { tap, sensor }

enum _FocusPhase { idle, blurringIn, focused, blurringOut }

const _focusMomentRefresh = Duration(minutes: 30);
const _minimumRecordedFocus = Duration(seconds: 15);
const _fallbackFocusMoment = '先把此刻放轻。\n你已经在回到自己。';
const _returnFromAwayHint = '刚才有一阵风经过，这一段不替你记入入静。';

class StatePerceptionPage extends ConsumerStatefulWidget {
  const StatePerceptionPage({
    super.key,
    required this.isActive,
    required this.featuresEnabled,
    required this.onShellHide,
  });

  /// 仅当中间 Tab 可见时为 true；离开后不响应传感器/三击，并恢复底栏。
  final bool isActive;

  /// 已登录才开放三击/扣置心流与底部引导。
  final bool featuresEnabled;
  final ValueChanged<bool> onShellHide;

  @override
  ConsumerState<StatePerceptionPage> createState() =>
      _StatePerceptionPageState();
}

class _StatePerceptionPageState extends ConsumerState<StatePerceptionPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _blurController;

  _FocusPhase _phase = _FocusPhase.idle;
  _FocusTrigger? _trigger;

  // 三击检测
  int _tapCount = 0;
  DateTime? _lastTap;

  // 传感器
  UserMotionState? _lastMotion;
  Timer? _stillTimer;
  Timer? _motionTimer;

  // 传感器保护：页面激活后延迟 2s 才允许传感器触发，防止启动时误触
  bool _sensorReady = false;

  // 专注计时
  DateTime? _focusStartedAt;
  DateTime? _activeSegmentStartedAt;
  Duration _accumulatedActiveDuration = Duration.zero;
  Timer? _momentTimer;
  String? _currentMoment;
  int _sessionJournalCount = 0;
  int _awayCount = 0;
  bool _wasAwayDuringFlow = false;

  bool _showCapture = false;
  bool _flowMuted = false;
  bool _mediaPickerActive = false;

  // 点击波纹注入
  final _tapRippleNotifier = ValueNotifier<int>(0);
  late final AppAudioService _audioService;

  /// 进入页面时 mock 一条「今日宜」，登录后展示。
  late final String _dailyTip = HomeGreeting.mockDailyTip();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioService = ref.read(appAudioServiceProvider);

    _blurController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // 延迟 2s 后才允许传感器触发，同时重置 _lastMotion
    // 这样扣手机（静止）后 2s 内传感器事件会更新 _lastMotion 但不触发专注
    // 2s 后下一次状态变化才会触发
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _lastMotion = null; // 重置，让下一次传感器事件重新判断
        _sensorReady = true;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setShellHidden(false);
    unawaited(_audioService.endFlowSilently());
    _blurController.dispose();
    _stillTimer?.cancel();
    _motionTimer?.cancel();
    _momentTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _onAppBackgrounded();
    }
  }

  @override
  void didUpdateWidget(StatePerceptionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.featuresEnabled && !widget.featuresEnabled) {
      _forceResetToIdle();
    }
    if (oldWidget.isActive && !widget.isActive) {
      _onTabDeactivated();
    } else if (!oldWidget.isActive && widget.isActive) {
      _onTabActivated();
    }
  }

  void _forceResetToIdle() {
    unawaited(_audioService.endFlowSilently());
    if (_phase != _FocusPhase.idle) {
      setState(() => _resetFocusState(resetBlur: true));
    }
    _setShellHidden(false);
  }

  void _resetFocusState({required bool resetBlur}) {
    _stillTimer?.cancel();
    _motionTimer?.cancel();
    _momentTimer?.cancel();
    if (resetBlur) {
      _blurController.stop();
      _blurController.value = 0;
    }
    _phase = _FocusPhase.idle;
    _trigger = null;
    _showCapture = false;
    _currentMoment = null;
    _tapCount = 0;
    _focusStartedAt = null;
    _activeSegmentStartedAt = null;
    _accumulatedActiveDuration = Duration.zero;
    _sessionJournalCount = 0;
    _awayCount = 0;
    _wasAwayDuringFlow = false;
    _mediaPickerActive = false;
  }

  void _onTabActivated() {
    _sensorReady = false;
    _lastMotion = null;
    _stillTimer?.cancel();
    _motionTimer?.cancel();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted && widget.isActive) {
        _lastMotion = null;
        _sensorReady = true;
      }
    });
    _onAppResumed();
  }

  void _onTabDeactivated() {
    _stillTimer?.cancel();
    _motionTimer?.cancel();
    _momentTimer?.cancel();
    _sensorReady = false;
    unawaited(_audioService.endFlowSilently());

    if (_phase != _FocusPhase.idle) {
      final report = _buildFocusReport();
      _recordFocusSessionIfNeeded(report);
      setState(() => _resetFocusState(resetBlur: true));
    }
    _setShellHidden(false);
  }

  void _onAppBackgrounded() {
    if (_phase == _FocusPhase.idle) return;
    if (_mediaPickerActive) return;
    _settleActiveSegment();
    _awayCount++;
    _wasAwayDuringFlow = true;
    _showCapture = false;
    _momentTimer?.cancel();
    unawaited(_audioService.pauseFlowSilently());
  }

  void _onAppResumed() {
    if (_mediaPickerActive) return;
    if (_phase != _FocusPhase.focused || !_wasAwayDuringFlow) return;
    _resumeActiveSegment();
    _wasAwayDuringFlow = false;
    unawaited(_audioService.resumeFlowAmbient());
    _showGentleHint(_returnFromAwayHint);
  }

  // ── 三击检测 ──────────────────────────────────────────────────────────────
  void _onTap() {
    if (!widget.featuresEnabled || !widget.isActive) return;
    if (_phase == _FocusPhase.blurringIn || _phase == _FocusPhase.blurringOut) {
      return;
    }

    // 每次点击都注入一个额外波纹
    _tapRippleNotifier.value++;
    if (_phase == _FocusPhase.idle) {
      unawaited(_audioService.playCenterDotTap());
    }

    final now = DateTime.now();
    if (_lastTap == null ||
        now.difference(_lastTap!) > const Duration(milliseconds: 600)) {
      _tapCount = 0;
    }
    _lastTap = now;
    _tapCount++;

    if (_tapCount >= 3) {
      _tapCount = 0;
      if (_phase == _FocusPhase.idle) {
        _enterFocus(_FocusTrigger.tap);
      } else if (_phase == _FocusPhase.focused) {
        _exitFocus();
      }
    }
  }

  // ── 传感器处理 ────────────────────────────────────────────────────────────
  void _onMotionChanged(UserMotionState motion) {
    if (!widget.featuresEnabled || !widget.isActive) return;
    if (!ref.read(settingsProvider).sensorFocusEnabled) return;
    if (_lastMotion == motion) return;
    _lastMotion = motion;

    if (!_sensorReady) return; // 保护期内不响应

    if (_phase == _FocusPhase.idle && motion == UserMotionState.steady) {
      _stillTimer?.cancel();
      _stillTimer = Timer(const Duration(milliseconds: 1500), () {
        if (_phase == _FocusPhase.idle && mounted) {
          _enterFocus(_FocusTrigger.sensor);
        }
      });
    } else {
      _stillTimer?.cancel();
    }

    if (_phase == _FocusPhase.focused &&
        _trigger == _FocusTrigger.sensor &&
        motion == UserMotionState.moving) {
      _motionTimer?.cancel();
      _motionTimer = Timer(const Duration(seconds: 3), () {
        if (_phase == _FocusPhase.focused && mounted) {
          _exitFocus();
        }
      });
    } else if (motion == UserMotionState.steady) {
      _motionTimer?.cancel();
    }
  }

  // ── 进入专注 ──────────────────────────────────────────────────────────────
  Future<void> _enterFocus(_FocusTrigger trigger) async {
    if (!mounted) return;
    setState(() {
      _phase = _FocusPhase.blurringIn;
      _trigger = trigger;
      _showCapture = false;
      _currentMoment = null;
      _activeSegmentStartedAt = null;
      _accumulatedActiveDuration = Duration.zero;
      _sessionJournalCount = 0;
      _awayCount = 0;
      _wasAwayDuringFlow = false;
    });
    _setShellHidden(true);
    unawaited(_audioService.enterFlow());

    await _blurController.forward();
    if (!mounted) return;

    _focusStartedAt = DateTime.now();
    _resumeActiveSegment();
    setState(() => _phase = _FocusPhase.focused);
    _startMomentTimer();
  }

  // ── 退出专注 ──────────────────────────────────────────────────────────────
  Future<void> _exitFocus() async {
    if (!mounted) return;
    _momentTimer?.cancel();
    final report = _buildFocusReport();
    _recordFocusSessionIfNeeded(report);
    unawaited(_audioService.exitFlow());
    setState(() {
      _phase = _FocusPhase.blurringOut;
      _currentMoment = null;
    });

    await _blurController.reverse();
    if (!mounted) return;

    setState(() {
      _phase = _FocusPhase.idle;
      _trigger = null;
      _focusStartedAt = null;
      _sessionJournalCount = 0;
    });
    _setShellHidden(false);
    if (report != null && report.shouldShow) {
      unawaited(_showFocusReport(report));
    }
  }

  Future<void> _toggleFlowMuted() async {
    final muted = await _audioService.toggleFlowMuted();
    if (!mounted) return;
    setState(() => _flowMuted = muted);
  }

  // ── 通知 Shell 隐藏/显示 ──────────────────────────────────────────────────
  void _setShellHidden(bool hide) {
    widget.onShellHide(hide);
  }

  _FocusReport? _buildFocusReport() {
    final started = _focusStartedAt;
    final trigger = _trigger;
    if (started == null || trigger == null) return null;

    _settleActiveSegment();
    final ended = DateTime.now();
    return _FocusReport(
      startedAt: started,
      endedAt: ended,
      duration: _accumulatedActiveDuration,
      trigger: trigger,
      journalCount: _sessionJournalCount,
      awayCount: _awayCount,
    );
  }

  void _recordFocusSessionIfNeeded(_FocusReport? report) {
    if (report == null || !report.shouldRecord) return;

    _focusStartedAt = null;
    final triggerType = report.trigger == _FocusTrigger.tap ? 'tap' : 'sensor';
    final repository = ref.read(focusSessionRepositoryProvider);
    final syncService = ref.read(focusSessionSyncServiceProvider);

    unawaited(
      repository
          .recordSession(
            startedAt: report.startedAt,
            endedAt: report.endedAt,
            triggerType: triggerType,
            durationSecondsOverride: report.duration.inSeconds,
          )
          .then((session) async {
            await syncService.pushSession(session);
            if (!mounted) return;
            invalidateAnalyticsWidgetProviders(ref);
          }),
    );
  }

  Future<void> _showFocusReport(_FocusReport report) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _FocusReportSheet(report: report),
    );
  }

  void _resumeActiveSegment() {
    _activeSegmentStartedAt ??= DateTime.now();
    _startMomentTimer();
  }

  void _settleActiveSegment() {
    final segmentStarted = _activeSegmentStartedAt;
    if (segmentStarted == null) return;
    final now = DateTime.now();
    if (now.isAfter(segmentStarted)) {
      _accumulatedActiveDuration += now.difference(segmentStarted);
    }
    _activeSegmentStartedAt = null;
  }

  Duration _activeDurationSnapshot() {
    final segmentStarted = _activeSegmentStartedAt;
    if (segmentStarted == null) return _accumulatedActiveDuration;
    final now = DateTime.now();
    if (!now.isAfter(segmentStarted)) return _accumulatedActiveDuration;
    return _accumulatedActiveDuration + now.difference(segmentStarted);
  }

  void _startMomentTimer() {
    _momentTimer?.cancel();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (_phase == _FocusPhase.focused && mounted) {
        _refreshFocusMoment();
      }
    });
    _momentTimer = Timer.periodic(_focusMomentRefresh, (_) {
      if (_phase != _FocusPhase.focused || !mounted) return;
      _refreshFocusMoment();
    });
  }

  void _showGentleHint(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  Future<void> _refreshFocusMoment() async {
    final startedAt = _focusStartedAt;
    final trigger = _trigger;
    if (startedAt == null || trigger == null) return;

    final elapsedSeconds = _activeDurationSnapshot().inSeconds;
    final triggerType = trigger == _FocusTrigger.tap ? 'tap' : 'sensor';
    try {
      final text = await ref
          .read(focusMomentServiceProvider)
          .fetchMoment(
            startedAt: startedAt,
            elapsedSeconds: elapsedSeconds,
            triggerType: triggerType,
          );
      if (_phase != _FocusPhase.focused || !mounted) return;
      await _showMoment(text);
    } catch (_) {
      if (_phase != _FocusPhase.focused || !mounted) return;
      await _showMoment(_fallbackFocusMoment);
    }
  }

  Future<void> _showMoment(String text) async {
    if (!mounted) return;
    setState(() => _currentMoment = text);
  }

  // ── 下滑手势 ──────────────────────────────────────────────────────────────
  void _onSwipeDown() {
    if (!widget.featuresEnabled) return;
    if (_phase == _FocusPhase.focused) {
      setState(() => _showCapture = true);
    }
  }

  void _dismissCapture() => setState(() => _showCapture = false);

  void _setMediaPickerActive(bool active) {
    if (_mediaPickerActive == active) return;
    _mediaPickerActive = active;
  }

  Future<void> _onCaptureSubmitting(Future<void> saveFuture) async {
    setState(() => _showCapture = false);
    await saveFuture;
    if (!mounted) return;
    final state = ref.read(intentControllerProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.error.toString(),
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    setState(() => _sessionJournalCount++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已归入心笺', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final sensorFocusEnabled = settings.sensorFocusEnabled;
    final soundEnabled = settings.soundEnabled;

    _audioService.setEnabled(soundEnabled);

    if (widget.featuresEnabled && widget.isActive && sensorFocusEnabled) {
      ref.listen(focusStateProvider, (_, next) {
        next.whenData((s) => _onMotionChanged(s.motionState));
      });
    }

    ref.listen(settingsProvider, (previous, next) {
      if (previous?.sensorFocusEnabled == true && !next.sensorFocusEnabled) {
        _stillTimer?.cancel();
        _motionTimer?.cancel();
      }
      if (previous?.soundEnabled != next.soundEnabled) {
        unawaited(_audioService.setEnabled(next.soundEnabled));
      }
    });

    return IgnorePointer(
      ignoring: !widget.featuresEnabled,
      child: GestureDetector(
        onTap: _onTap,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 200) _onSwipeDown();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _blurController,
          builder: (context, child) {
            final blurAmount = _blurController.value * 18.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                child!,

                if (_phase != _FocusPhase.idle)
                  _BlurOverlay(blurAmount: blurAmount),

                // 时间感知文案（环形上方）
                if (_phase == _FocusPhase.focused)
                  _BreathText(
                    text: _currentMoment ?? '',
                    visible: _currentMoment != null,
                    top: true,
                  ),

                // 三击模式：下滑提示 + 退出提示（环形下方）
                if (_phase == _FocusPhase.focused && !_showCapture)
                  const _BreathText(
                    text: '下滑记下此刻\n再次三击退出心流',
                    visible: true,
                    top: false,
                  ),

                if (_phase == _FocusPhase.focused && soundEnabled)
                  _FlowMuteButton(muted: _flowMuted, onTap: _toggleFlowMuted),

                if (_showCapture)
                  ThoughtCaptureOverlay(
                    onDismiss: _dismissCapture,
                    onSubmitting: _onCaptureSubmitting,
                    onMediaPickerActiveChanged: _setMediaPickerActive,
                  ),
              ],
            );
          },
          child: _IdleContent(
            phase: _phase,
            dailyTip: _dailyTip,
            showFocusHint: widget.featuresEnabled,
            tapNotifier: _tapRippleNotifier,
          ),
        ),
      ),
    );
  }
}

// ─── 待机内容 ─────────────────────────────────────────────────────────────────
class _IdleContent extends ConsumerWidget {
  const _IdleContent({
    required this.phase,
    required this.dailyTip,
    required this.showFocusHint,
    required this.tapNotifier,
  });

  final _FocusPhase phase;
  final String dailyTip;
  final bool showFocusHint;
  final ValueNotifier<int> tapNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIdle = phase == _FocusPhase.idle;
    final nickname = ref.watch(authProvider).valueOrNull?.nickname;
    final sensorFocusEnabled = ref.watch(settingsProvider).sensorFocusEnabled;
    final greeting = HomeGreeting.build(nickname: nickname, dailyTip: dailyTip);
    final focusHint = FocusEntryHint.build(
      sensorFocusEnabled: sensorFocusEnabled,
    );

    // Column + 固定 260 波纹 + bottom 120 在小屏（含 AppBar/底栏）会溢出
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomInset = 88.0;
        final rippleSize = (constraints.maxHeight * 0.34).clamp(140.0, 240.0);

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset),
          child: Column(
            children: [
              if (showFocusHint) ...[
                const SizedBox(height: 12),
                AnimatedOpacity(
                  opacity: isIdle ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: Text(
                    greeting,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSansSc(
                      fontSize: 15,
                      height: 1.7,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              _ZenRippleWidget(size: rippleSize, tapNotifier: tapNotifier),
              const Spacer(),
              if (showFocusHint)
                AnimatedOpacity(
                  opacity: isIdle ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: Text(
                    focusHint,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSansSc(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.8,
                    ),
                  ),
                ),
              if (showFocusHint) const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// ─── 统一呼吸文字组件 ─────────────────────────────────────────────────────────
// top=true 放环形上方，top=false 放环形下方
// visible 控制整体淡入淡出，呼吸感由内部动画自己管理
class _BreathText extends StatefulWidget {
  const _BreathText({
    required this.text,
    required this.visible,
    required this.top,
  });

  final String text;
  final bool visible;
  final bool top;

  @override
  State<_BreathText> createState() => _BreathTextState();
}

class _BreathTextState extends State<_BreathText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathCtrl;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    // 环形中心大约在屏幕 50% 处，上方文案在环形上方 ~180px，下方在 ~160px
    final top = widget.top ? screenH * 0.5 - 280 : null;
    final bottom = widget.top ? null : 130.0;

    return Positioned(
      left: 40,
      right: 40,
      top: top,
      bottom: bottom,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOut,
        child: AnimatedBuilder(
          animation: _breathCtrl,
          builder: (context, child) {
            // 呼吸范围 0.45 ~ 1.0，渐渐消失再渐渐出现
            final breath = 0.45 + _breathCtrl.value * 0.55;
            return Opacity(opacity: breath, child: child);
          },
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansSc(
              fontSize: 13,
              height: 1.9,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _FlowMuteButton extends StatelessWidget {
  const _FlowMuteButton({required this.muted, required this.onTap});

  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 14,
      right: 14,
      child: SafeArea(
        child: IconButton(
          tooltip: muted ? '开启声音' : '静音',
          onPressed: onTap,
          icon: FlowSoundIcon(
            muted: muted,
            color: AppColors.textMuted.withValues(alpha: 0.82),
          ),
        ),
      ),
    );
  }
}

class _FocusReport {
  const _FocusReport({
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.trigger,
    required this.journalCount,
    required this.awayCount,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final Duration duration;
  final _FocusTrigger trigger;
  final int journalCount;
  final int awayCount;

  bool get shouldRecord => duration >= _minimumRecordedFocus;
  bool get shouldShow => shouldRecord;

  String get durationText {
    final minutes = duration.inMinutes;
    if (minutes < 1) return '${duration.inSeconds} 秒';
    final hours = minutes ~/ 60;
    final remainMinutes = minutes % 60;
    if (hours == 0) return '$minutes 分钟';
    if (remainMinutes == 0) return '$hours 小时';
    return '$hours 小时 $remainMinutes 分钟';
  }

  String get journalText {
    return journalCount == 0 ? '未落心笺' : '留下 $journalCount 枚心笺';
  }

  String get awayText {
    return awayCount == 0 ? '未曾离席' : '离席 $awayCount 次';
  }
}

class _FocusReportSheet extends StatelessWidget {
  const _FocusReportSheet({required this.report});

  final _FocusReport report;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: isNightTheme ? 0.08 : 0.42),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isNightTheme ? 0.2 : 0.08,
                ),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本次入静',
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _ReportMetric(label: '时长', value: report.durationText),
                    _ReportMetric(label: '心笺', value: report.journalText),
                    if (report.awayCount > 0)
                      _ReportMetric(label: '离席', value: report.awayText),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  _reportCopy(report),
                  style: GoogleFonts.notoSansSc(
                    fontSize: 13,
                    height: 1.75,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      '收下',
                      style: GoogleFonts.notoSansSc(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _reportCopy(_FocusReport report) {
    if (report.awayCount > 2) {
      return '今天的风有些杂。流境只替你记下真正留在此处的时间。';
    }
    if (report.awayCount > 0) {
      return '有些事来过，又被你放下了。这里记录的是你真正留在此处的时间。';
    }
    if (report.journalCount > 0) {
      return '这一段静里，你没有急着追赶，只把浮起的念头轻轻安放。';
    }
    return '这一段时间没有被催促，也没有被打断。你只是安静地，把自己收回来了一点。';
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.glassBorder.withValues(alpha: 0.7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.notoSansSc(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansSc(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 扩散环形 ─────────────────────────────────────────────────────────────────
class _ZenRippleWidget extends StatefulWidget {
  const _ZenRippleWidget({this.size = 240, this.tapNotifier});

  final double size;
  final ValueNotifier<int>? tapNotifier;

  @override
  State<_ZenRippleWidget> createState() => _ZenRippleWidgetState();
}

class _ZenRippleWidgetState extends State<_ZenRippleWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // 每个点击波纹记录它的"出生时刻"（_ctrl.value 时的进度）
  final List<double> _tapWaves = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    widget.tapNotifier?.addListener(_onTapRipple);
  }

  @override
  void didUpdateWidget(_ZenRippleWidget old) {
    super.didUpdateWidget(old);
    if (old.tapNotifier != widget.tapNotifier) {
      old.tapNotifier?.removeListener(_onTapRipple);
      widget.tapNotifier?.addListener(_onTapRipple);
    }
  }

  @override
  void dispose() {
    widget.tapNotifier?.removeListener(_onTapRipple);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapRipple() {
    // 记录当前进度作为这个点击波纹的起点
    _tapWaves.add(_ctrl.value);
    // 最多保留 6 个点击波纹，避免堆积
    if (_tapWaves.length > 6) _tapWaves.removeAt(0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value < 0.5 ? _ctrl.value * 2 : (1 - _ctrl.value) * 2;
        final blur = 1.0 + 3.5 * Curves.easeInOut.transform(t);

        // 计算每个点击波纹当前的扩散进度（0→1），超过 1 就移除
        final tapProgresses = <double>[];
        final toRemove = <double>[];
        for (final birth in _tapWaves) {
          // 点击波纹用独立的线性进度，1.2s 扩散完
          var elapsed = (_ctrl.value - birth);
          if (elapsed < 0) elapsed += 1.0; // 处理循环
          final p = (elapsed * 3200 / 1200).clamp(0.0, 1.0);
          if (p >= 1.0) {
            toRemove.add(birth);
          } else {
            tapProgresses.add(p);
          }
        }
        for (final b in toRemove) {
          _tapWaves.remove(b);
        }

        return ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _RipplePainter(
              progress: _ctrl.value,
              coreRadius: widget.size * 32 / 260,
              tapProgresses: tapProgresses,
            ),
          ),
        );
      },
    );
  }
}

class _RipplePainter extends CustomPainter {
  const _RipplePainter({
    required this.progress,
    this.coreRadius = 32.0,
    this.tapProgresses = const [],
  });

  final double progress;
  final double coreRadius;
  final List<double> tapProgresses;

  static const _waveCount = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.48;

    // 内晕
    canvas.drawCircle(
      center,
      coreRadius + 16,
      Paint()
        ..color = const Color(0xFF516356).withValues(alpha: 0.07)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      coreRadius + 40,
      Paint()
        ..color = const Color(0xFF516356).withValues(alpha: 0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 常规循环波纹
    for (var i = 0; i < _waveCount; i++) {
      final phase = (progress + i / _waveCount) % 1.0;
      final radius = coreRadius + phase * (maxRadius - coreRadius);
      final fade = 1 - Curves.easeOut.transform(phase);
      final alpha = 0.10 * fade;
      if (alpha <= 0.005) continue;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFF516356).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 - 1.6 * phase,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFF516356).withValues(alpha: alpha * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.2 - 1.6 * phase) * 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // 点击额外波纹：更亮、更快消散
    for (final p in tapProgresses) {
      final radius = coreRadius + p * (maxRadius - coreRadius);
      final fade = 1 - Curves.easeOut.transform(p);
      final alpha = 0.28 * fade; // 比常规波纹更亮

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFF516356).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8 - 2.0 * p,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFF516356).withValues(alpha: alpha * 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.8 - 2.0 * p) * 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // 中心圆
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()..color = const Color(0xFF737873),
    );
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) =>
      old.progress != progress ||
      old.coreRadius != coreRadius ||
      old.tapProgresses != tapProgresses;
}

// ─── 高斯模糊遮罩 ─────────────────────────────────────────────────────────────
class _BlurOverlay extends StatelessWidget {
  const _BlurOverlay({required this.blurAmount});

  final double blurAmount;

  @override
  Widget build(BuildContext context) {
    if (blurAmount <= 0) return const SizedBox.shrink();
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: ColoredBox(
          key: const ValueKey('focus-glass-surface'),
          color: AppColors.surface.withValues(
            alpha: blurAmount / 18 * (isNightTheme ? 0.55 : 0.15),
          ),
        ),
      ),
    );
  }
}
