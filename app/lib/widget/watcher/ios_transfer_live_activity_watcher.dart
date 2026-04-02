import 'dart:async';

import 'package:common/model/session_status.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:live_activities/live_activities.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/model/state/send/send_session_state.dart';
import 'package:localsend_app/model/state/server/receive_session_state.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:localsend_app/provider/network/server/server_provider.dart';
import 'package:localsend_app/provider/progress_provider.dart';
import 'package:localsend_app/util/native/ios_live_activity_sync.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Shows a Live Activity / Dynamic Island transfer indicator on iOS 16.1+.
const _activityId = 'localsend_file_transfer';
const _appGroupId = 'group.org.localsend.localsendApp';

class IosTransferLiveActivityWatcher extends StatefulWidget {
  const IosTransferLiveActivityWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<IosTransferLiveActivityWatcher> createState() => _IosTransferLiveActivityWatcherState();
}

class _IosTransferLiveActivityWatcherState extends State<IosTransferLiveActivityWatcher> with Refena {
  static final LiveActivities _live = LiveActivities();
  static Future<void>? _initFuture;
  static bool _initDone = false;

  bool _hooksRegistered = false;
  Timer? _pollWhileActive;
  int _lastProgressPushMs = 0;
  int _lastSessionSyncMs = 0;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(_ensureInit());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (defaultTargetPlatform != TargetPlatform.iOS || _hooksRegistered) {
      return;
    }
    _hooksRegistered = true;
    iosLiveActivityOnProgressTick = () {
      unawaited(_maybePushLiveActivity(throttleHeavyNative: true));
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncLiveActivityFromProviders());
    });
  }

  @override
  void dispose() {
    _pollWhileActive?.cancel();
    _pollWhileActive = null;
    if (iosLiveActivityOnProgressTick != null) {
      iosLiveActivityOnProgressTick = null;
    }
    super.dispose();
  }

  Future<void> _ensureInit() async {
    if (_initDone) {
      return;
    }
    _initFuture ??= () async {
      try {
        await _live.init(
          appGroupId: _appGroupId,
          requireNotificationPermission: false,
        );
        _initDone = true;
      } catch (_) {
        _initDone = false;
      }
    }();
    await _initFuture;
  }

  void _ensurePollWhileTransferring() {
    _pollWhileActive ??= Timer.periodic(const Duration(milliseconds: 220), (_) {
      unawaited(_maybePushLiveActivity(throttleHeavyNative: false));
    });
  }

  void _stopPoll() {
    _pollWhileActive?.cancel();
    _pollWhileActive = null;
  }

  /// [throttleHeavyNative] avoids hammering ActivityKit when progress fires very frequently.
  Future<void> _maybePushLiveActivity({required bool throttleHeavyNative}) async {
    if (throttleHeavyNative) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastProgressPushMs < 110) {
        return;
      }
      _lastProgressPushMs = now;
    }
    await _syncLiveActivityFromProviders();
  }

  Future<void> _syncLiveActivityFromProviders() async {
    await _ensureInit();
    if (!_initDone || !mounted) {
      return;
    }
    try {
      final enabled = await _live.areActivitiesEnabled();
      if (!enabled) {
        return;
      }

      final sendMap = ref.read(sendProvider);
      final server = ref.read(serverProvider);

      final sendActive = sendMap.values.any((s) => s.status == SessionStatus.sending);
      final receiveSession = server?.session;
      final receiveActive = receiveSession?.status == SessionStatus.sending;
      final active = sendActive || receiveActive;

      if (!active) {
        _stopPoll();
        await _live.endActivity(_activityId);
        return;
      }

      _ensurePollWhileTransferring();

      final isSending = sendActive;
      final title = isSending ? t.progressPage.titleSending : t.progressPage.titleReceiving;
      String subtitle = '';
      if (isSending) {
        for (final s in sendMap.values) {
          if (s.status == SessionStatus.sending) {
            subtitle = s.target.alias;
            break;
          }
        }
      } else {
        subtitle = receiveSession?.senderAlias ?? '';
      }

      final progress = isSending ? _aggregateSendProgress(sendMap) : _aggregateReceiveProgress(receiveSession);

      await _live.createOrUpdateActivity(
        _activityId,
        {
          'title': title,
          'subtitle': subtitle,
          'progress': progress.clamp(0.0, 1.0),
          'isSending': isSending ? 1 : 0,
        },
      );
    } catch (_) {}
  }

  double _aggregateSendProgress(Map<String, SendSessionState> sendMap) {
    final prog = ref.read(progressProvider);
    var weighted = 0.0;
    var total = 0;
    for (final s in sendMap.values) {
      if (s.status != SessionStatus.sending) {
        continue;
      }
      for (final f in s.files.values) {
        final sz = f.file.size;
        total += sz;
        weighted += prog.getProgress(sessionId: s.sessionId, fileId: f.file.id) * sz;
      }
    }
    if (total == 0) {
      return 0;
    }
    return weighted / total;
  }

  double _aggregateReceiveProgress(ReceiveSessionState? session) {
    if (session == null) {
      return 0;
    }
    final prog = ref.read(progressProvider);
    var weighted = 0.0;
    var total = 0;
    for (final f in session.files.values) {
      final sz = f.file.size;
      total += sz;
      weighted += prog.getProgress(sessionId: session.sessionId, fileId: f.file.id) * sz;
    }
    if (total == 0) {
      return 0;
    }
    return weighted / total;
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      ref.watch(sendProvider);
      ref.watch(serverProvider);
      ref.watch(progressProvider);
      // Session state changes do not always emit progress immediately; keep Island in sync
      // when a transfer starts and when only send/server maps change.
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastSessionSyncMs > 60) {
        _lastSessionSyncMs = now;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_syncLiveActivityFromProviders());
        });
      }
    }

    return widget.child;
  }
}
