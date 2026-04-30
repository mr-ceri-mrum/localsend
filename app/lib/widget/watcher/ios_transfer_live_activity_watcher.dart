import 'dart:async';

import 'package:common/model/file_status.dart';
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
const _appGroupId = 'group.Ilyas';

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
  /// Cleared when transfer ends; used to reset Island UserDefaults (avoids stale 100% from last run).
  String? _lastIslandTransferFingerprint;

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
        // Kill stale activities from previous app sessions that were never properly ended.
        try {
          await _live.endAllActivities();
        } catch (_) {}
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
        _lastIslandTransferFingerprint = null;
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

      final fingerprint = _transferFingerprint(
        sendActive: sendActive,
        receiveActive: receiveActive,
        sendMap: sendMap,
        receiveSession: receiveSession,
      );
      if (fingerprint != null && fingerprint != _lastIslandTransferFingerprint) {
        _lastIslandTransferFingerprint = fingerprint;
        // Same Live Activity id reuses App Group keys; overwrite immediately so Dynamic Island
        // does not briefly show the previous transfer's 100%.
        await _live.createOrUpdateActivity(
          _activityId,
          {
            'title': title,
            'subtitle': subtitle,
            'progress': 0.0,
            'progressPct': 0,
            'isSending': isSending ? 1 : 0,
          },
        );
      }

      final rawProgress = isSending ? _aggregateSendProgress(sendMap) : _aggregateReceiveProgress(receiveSession);
      final clamped = rawProgress.clamp(0.0, 1.0);
      final forIsland = _capIslandProgressIfStillWorking(
        clamped: clamped,
        isSending: isSending,
        sendMap: sendMap,
        receiveSession: receiveSession,
      );
      final pct = (forIsland * 100).round().clamp(0, 100);

      await _live.createOrUpdateActivity(
        _activityId,
        {
          'title': title,
          'subtitle': subtitle,
          'progress': forIsland,
          // Integer percent for UserDefaults; some assets report size 0 until sent (avoids "00").
          'progressPct': pct,
          'isSending': isSending ? 1 : 0,
        },
      );
    } catch (_) {}
  }

  /// Identifies the current transfer so we can reset Island storage when starting a new one.
  String? _transferFingerprint({
    required bool sendActive,
    required bool receiveActive,
    required Map<String, SendSessionState> sendMap,
    required ReceiveSessionState? receiveSession,
  }) {
    if (sendActive) {
      final parts = <String>[];
      for (final e in sendMap.entries) {
        if (e.value.status == SessionStatus.sending) {
          final ids = e.value.files.keys.toList()..sort();
          parts.add('${e.key}:${ids.join(',')}');
        }
      }
      parts.sort();
      if (parts.isEmpty) {
        return null;
      }
      return 's:${parts.join('|')}';
    }
    if (receiveActive && receiveSession != null) {
      final ids = receiveSession.files.keys.toList()..sort();
      return 'r:${receiveSession.sessionId}:${ids.join(',')}';
    }
    return null;
  }

  /// Avoid showing 100% on the Island while bytes are still moving (stale keys or progress glitches).
  double _capIslandProgressIfStillWorking({
    required double clamped,
    required bool isSending,
    required Map<String, SendSessionState> sendMap,
    required ReceiveSessionState? receiveSession,
  }) {
    if (clamped < 1.0) {
      return clamped;
    }
    final stillWorking = _hasFilesStillInFlight(
      isSending: isSending,
      sendMap: sendMap,
      receiveSession: receiveSession,
    );
    if (stillWorking) {
      return 0.999;
    }
    return clamped;
  }

  bool _hasFilesStillInFlight({
    required bool isSending,
    required Map<String, SendSessionState> sendMap,
    required ReceiveSessionState? receiveSession,
  }) {
    if (isSending) {
      for (final s in sendMap.values) {
        if (s.status != SessionStatus.sending) {
          continue;
        }
        for (final f in s.files.values) {
          if (f.status == FileStatus.queue || f.status == FileStatus.sending) {
            return true;
          }
        }
      }
      return false;
    }
    if (receiveSession == null) {
      return false;
    }
    for (final f in receiveSession.files.values) {
      if (f.status == FileStatus.queue || f.status == FileStatus.sending) {
        return true;
      }
    }
    return false;
  }

  double _aggregateSendProgress(Map<String, SendSessionState> sendMap) {
    final prog = ref.read(progressProvider);
    var weighted = 0.0;
    var total = 0;
    var count = 0;
    var unweightedSum = 0.0;
    for (final s in sendMap.values) {
      if (s.status != SessionStatus.sending) {
        continue;
      }
      for (final f in s.files.values) {
        final p = prog.getProgress(sessionId: s.sessionId, fileId: f.file.id);
        count += 1;
        unweightedSum += p;
        final sz = f.file.size;
        total += sz;
        weighted += p * sz;
      }
    }
    if (count == 0) {
      return 0;
    }
    if (total == 0) {
      return unweightedSum / count;
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
    var count = 0;
    var unweightedSum = 0.0;
    for (final f in session.files.values) {
      final p = prog.getProgress(sessionId: session.sessionId, fileId: f.file.id);
      count += 1;
      unweightedSum += p;
      final sz = f.file.size;
      total += sz;
      weighted += p * sz;
    }
    if (count == 0) {
      return 0;
    }
    if (total == 0) {
      return unweightedSum / count;
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
