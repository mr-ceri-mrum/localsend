import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _methodChannel = MethodChannel('ios-delegate-channel');

Future<bool> isReduceMotionEnabledIOS() async {
  return await _methodChannel.invokeMethod('isReduceMotionEnabled') ?? false;
}

/// Asks iOS for extra execution time while a send/receive transfer is active and the app is backgrounded.
/// Native code periodically renews the background task so large transfers are less likely to stall
/// after ~30s; iOS may still suspend the app in edge cases (memory pressure, low power, etc.).
Future<void> setIosFileTransferBackgroundActive(bool active) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  try {
    await _methodChannel.invokeMethod(active ? 'beginFileTransferBackground' : 'endFileTransferBackground');
  } catch (_) {}
}

/// Resets the iOS background execution budget while a transfer is active (call ~every 5s).
Future<void> pulseIosFileTransferBackground() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  try {
    await _methodChannel.invokeMethod('pulseFileTransferBackground');
  } catch (_) {}
}
