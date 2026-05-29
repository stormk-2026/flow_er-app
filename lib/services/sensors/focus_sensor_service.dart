import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

enum UserMotionState { steady, moving }

class UserFocusState {
  const UserFocusState({required this.motionState, required this.updatedAt});

  final UserMotionState motionState;
  final DateTime updatedAt;

  String get label => switch (motionState) {
    UserMotionState.steady => 'Steady',
    UserMotionState.moving => 'Moving',
  };
}

class FocusSensorService {
  Stream<UserFocusState> watchFocusState() {
    return accelerometerEventStream(
          samplingPeriod: SensorInterval.normalInterval,
        )
        .map((event) {
          final magnitude = sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );
          final deltaFromGravity = (magnitude - 9.8).abs();

          return UserFocusState(
            motionState: deltaFromGravity > 2.0
                ? UserMotionState.moving
                : UserMotionState.steady,
            updatedAt: DateTime.now(),
          );
        })
        .distinct((previous, next) => previous.motionState == next.motionState);
  }
}
