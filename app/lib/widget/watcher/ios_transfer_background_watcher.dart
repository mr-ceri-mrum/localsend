import 'dart:async';

import 'package:common/model/session_status.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/util/native/ios_channel.dart' show pulseIosFileTransferBackground, setIosFileTransferBackgroundActive;
import 'package:refena_flutter/refena_flutter.dart';

/// Handshake ([SessionStatus.waiting]) and uploads/downloads ([SessionStatus.sending]) must not be
/// suspended on iOS or the TCP connection drops.
bool _transferSessionNeedsIosBackground(SessionStatus status) {
  return status == SessionStatus.waiting || status == SessionStatus.sending;
}

/// Keeps a [UIBackgroundTask] on iOS while any file transfer is in progress.
class IosTransferBackgroundWatcher extends StatefulWidget {
  const IosTransferBackgroundWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<IosTransferBackgroundWatcher> createState() => _IosTransferBackgroundWatcherState();
}

class _IosTransferBackgroundWatcherState extends State<IosTransferBackgroundWatcher> with Refena, WidgetsBindingObserver {
  bool? _lastActive;
  Timer? _statePoll;
  Timer? _budgetPulse;
  bool _pollStarted = false;

  static const _budgetPulseInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    // Renew native budget as soon as we leave the foreground (don't wait for the next timer tick).
    if (state == AppLifecycleState.paused) {
      final sendMap = ref.read(sendProvider);
      final server = ref.read(serverProvider);
      final recv = server?.session;
      final active = sendMap.values.any((s) => _transferSessionNeedsIosBackground(s.status)) ||
          (recv != null && _transferSessionNeedsIosBackground(recv.status));
      if (active) {
        unawaited(pulseIosFileTransferBackground());
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS || _pollStarted) {
      return;
    }
    _pollStarted = true;
    // In background, widgets may not rebuild when transfer ends; poll so we end the native task.
    _statePoll = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) {
        return;
      }
      _syncIosBackgroundTaskFromProviders();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statePoll?.cancel();
    _budgetPulse?.cancel();
    super.dispose();
  }

  void _applyFileTransferBackground(bool active) {
    if (_lastActive != active) {
      _lastActive = active;
      unawaited(setIosFileTransferBackgroundActive(active));
      if (active) {
        unawaited(pulseIosFileTransferBackground());
      }
    }
    if (active) {
      _budgetPulse ??= Timer.periodic(_budgetPulseInterval, (_) {
        if (!mounted) {
          return;
        }
        unawaited(pulseIosFileTransferBackground());
      });
    } else {
      _budgetPulse?.cancel();
      _budgetPulse = null;
    }
  }

  void _syncIosBackgroundTaskFromProviders() {
    final sendMap = ref.read(sendProvider);
    final server = ref.read(serverProvider);
    final sendActive = sendMap.values.any((s) => _transferSessionNeedsIosBackground(s.status));
    final receiveActive =
        server?.session != null && _transferSessionNeedsIosBackground(server!.session!.status);
    final active = sendActive || receiveActive;
    _applyFileTransferBackground(active);
  }

  @override
  Widget build(BuildContext context) {
    final sendMap = ref.watch(sendProvider);
    final server = ref.watch(serverProvider);
    final sendActive = sendMap.values.any((s) => _transferSessionNeedsIosBackground(s.status));
    final receiveActive =
        server?.session != null && _transferSessionNeedsIosBackground(server!.session!.status);
    final active = sendActive || receiveActive;

    _applyFileTransferBackground(active);

    return widget.child;
  }
}
