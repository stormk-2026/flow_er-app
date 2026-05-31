import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AppAudioService {
  AppAudioService({Random? random}) : _random = random ?? Random();

  final Random _random;
  final AudioPlayer _tapPlayer = AudioPlayer();
  final AudioPlayer _intentPlayer = AudioPlayer();
  final AudioPlayer _transitionPlayer = AudioPlayer();
  final AudioPlayer _ambientPlayer = AudioPlayer();

  bool _flowActive = false;
  bool _flowMuted = false;
  bool _enabled = true;
  String? _currentAmbientTrack;

  static const _centerDotTap = 'audio/sfx/water-drip.mp3';
  static const _flowTransition = 'audio/sfx/in-out.mp3';
  static const _intentSent = 'audio/sfx/heart.mp3';
  static const _ambientTracks = [
    'audio/ambient/rain01.mp3',
    'audio/ambient/rain02.mp3',
    'audio/ambient/rain03.mp3',
    'audio/ambient/rain04.mp3',
  ];

  bool get flowMuted => _flowMuted;

  bool get enabled => _enabled;

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (!enabled) {
      await _stopAll();
      return;
    }
    if (_flowActive && !_flowMuted) {
      await _startAmbient();
    }
  }

  Future<void> playCenterDotTap() {
    if (!_enabled) return Future<void>.value();
    return _playSfx(_tapPlayer, _centerDotTap);
  }

  Future<void> playIntentSent() async {
    if (!_enabled || (_flowActive && _flowMuted)) return;
    final shouldRestoreAmbient = _flowActive && !_flowMuted;
    if (shouldRestoreAmbient) {
      await stopAmbient();
    }
    await _playSfxFor(_intentPlayer, _intentSent, const Duration(seconds: 3));
    if (shouldRestoreAmbient && _flowActive && _enabled && !_flowMuted) {
      await _startAmbient();
    }
  }

  Future<void> enterFlow() async {
    _flowActive = true;
    _currentAmbientTrack = _pickAmbientTrack();
    if (!_enabled || _flowMuted) return;

    await _playSfxAndWait(_transitionPlayer, _flowTransition);
    if (_flowActive && !_flowMuted) {
      await _startAmbient();
    }
  }

  Future<void> exitFlow() async {
    _flowActive = false;
    await stopAmbient();
    if (_enabled && !_flowMuted) {
      await _playSfx(_transitionPlayer, _flowTransition);
    }
  }

  Future<void> endFlowSilently() async {
    _flowActive = false;
    await stopAmbient();
    try {
      await _transitionPlayer.stop();
    } catch (error) {
      _logFailure('stop transition', error);
    }
  }

  Future<bool> toggleFlowMuted() async {
    final muted = !_flowMuted;
    await setFlowMuted(muted);
    return muted;
  }

  Future<void> setFlowMuted(bool muted) async {
    if (_flowMuted == muted) return;
    _flowMuted = muted;
    if (muted) {
      await stopAmbient();
      await _transitionPlayer.stop();
      return;
    }
    if (_enabled && _flowActive) {
      await _startAmbient();
    }
  }

  Future<void> stopAmbient() async {
    try {
      await _ambientPlayer.stop();
    } catch (error) {
      _logFailure('stop ambient', error);
    }
  }

  Future<void> dispose() async {
    await _tapPlayer.dispose();
    await _intentPlayer.dispose();
    await _transitionPlayer.dispose();
    await _ambientPlayer.dispose();
  }

  Future<void> _startAmbient() async {
    if (!_enabled || _flowMuted) return;
    try {
      final track = _currentAmbientTrack ?? _pickAmbientTrack();
      _currentAmbientTrack = track;
      await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
      await _ambientPlayer.play(AssetSource(track), volume: 0.42);
    } catch (error) {
      _logFailure('play ambient', error);
    }
  }

  Future<void> _playSfx(AudioPlayer player, String asset) async {
    if (!_enabled) return;
    try {
      await player.stop();
      await player.setReleaseMode(ReleaseMode.release);
      await player.play(AssetSource(asset));
    } catch (error) {
      _logFailure('play $asset', error);
    }
  }

  Future<void> _playSfxAndWait(AudioPlayer player, String asset) async {
    if (!_enabled) return;
    try {
      await player.stop();
      await player.setReleaseMode(ReleaseMode.release);
      final completed = player.onPlayerComplete.first;
      await player.play(AssetSource(asset));
      await completed.timeout(const Duration(seconds: 4));
    } catch (error) {
      _logFailure('play $asset and wait', error);
    }
  }

  Future<void> _playSfxFor(
    AudioPlayer player,
    String asset,
    Duration duration,
  ) async {
    if (!_enabled) return;
    try {
      await player.stop();
      await player.setReleaseMode(ReleaseMode.release);
      await player.play(AssetSource(asset));
      await Future<void>.delayed(duration);
      await player.stop();
    } catch (error) {
      _logFailure('play $asset for $duration', error);
    }
  }

  String _pickAmbientTrack() {
    return _ambientTracks[_random.nextInt(_ambientTracks.length)];
  }

  Future<void> _stopAll() async {
    try {
      await _tapPlayer.stop();
      await _intentPlayer.stop();
      await _transitionPlayer.stop();
      await _ambientPlayer.stop();
    } catch (error) {
      _logFailure('stop all', error);
    }
  }

  void _logFailure(String action, Object error) {
    if (kDebugMode) {
      debugPrint('Audio $action failed: $error');
    }
  }
}
