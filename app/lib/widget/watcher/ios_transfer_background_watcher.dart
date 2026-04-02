import 'dart:async';

import 'package:common/model/session_status.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/util/native/ios_channel.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Keeps a [UIBackgroundTask] on iOS while any file transfer is in progress.
class IosTransferBackgroundWatcher extends StatefulWidget {
  const IosTransferBackgroundWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<IosTransferBackgroundWatcher> createState() => _IosTransferBackgroundWatcherState();
}

class _IosTransferBackgroundWatcherState extends State<IosTransferBackgroundWatcher> with Refena {
  bool? _lastActive;
  Timer? _statePoll;
  bool _pollStarted = false;

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
    _statePoll?.cancel();
    super.dispose();
  }

  void _syncIosBackgroundTaskFromProviders() {
    final sendMap = ref.read(sendProvider);
    final server = ref.read(serverProvider);
    final sendActive = sendMap.values.any((s) => s.status == SessionStatus.sending);
    final receiveActive = server?.session?.status == SessionStatus.sending;
    final active = sendActive || receiveActive;

    if (_lastActive != active) {
      _lastActive = active;
      unawaited(setIosFileTransferBackgroundActive(active));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sendMap = ref.watch(sendProvider);
    final server = ref.watch(serverProvider);
    final sendActive = sendMap.values.any((s) => s.status == SessionStatus.sending);
    final receiveActive = server?.session?.status == SessionStatus.sending;
    final active = sendActive || receiveActive;

    if (_lastActive != active) {
      _lastActive = active;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(setIosFileTransferBackgroundActive(active));
      });
    }

    return widget.child;
  }
}
