import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Set by [IosTransferLiveActivityWatcher] on iOS. Invoked after each progress tick
/// so Dynamic Island updates without relying on widget rebuilds or timers.
VoidCallback? iosLiveActivityOnProgressTick;

void scheduleIosLiveActivityProgressSync() {
  if (defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  iosLiveActivityOnProgressTick?.call();
}

/// Call from [main] before [runApp]. [AppDelegate] invokes this channel while the app is
/// backgrounded so Live Activity progress keeps updating when iOS throttles Dart timers.
void registerIosLiveActivityNativeSyncListener() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  const MethodChannel('ios-delegate-callbacks').setMethodCallHandler((call) async {
    if (call.method == 'requestLiveActivitySync') {
      scheduleIosLiveActivityProgressSync();
    }
  });
}
