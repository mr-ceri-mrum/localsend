import 'package:flutter/foundation.dart';

/// Set by [IosTransferLiveActivityWatcher] on iOS. Invoked after each progress tick
/// so Dynamic Island updates without relying on widget rebuilds or timers.
VoidCallback? iosLiveActivityOnProgressTick;

void scheduleIosLiveActivityProgressSync() {
  if (defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  iosLiveActivityOnProgressTick?.call();
}
