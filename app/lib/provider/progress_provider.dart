import 'package:localsend_app/util/native/ios_live_activity_sync.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// A provider holding the progress of the send process.
/// It is implemented as [ChangeNotifier] for performance reasons.
final progressProvider = ChangeNotifierProvider((ref) => ProgressNotifier());

class ProgressNotifier extends ChangeNotifier {
  final _progressMap = <String, Map<String, double>>{}; // session id -> (file id -> 0..1)

  /// Receive-side Windows HEIC/video conversion after the HTTP body has finished (bytes at 100%).
  final _windowsReceivePostProcess = <String, Set<String>>{}; // session id -> file ids

  void setProgress({required String sessionId, required String fileId, required double progress}) {
    Map<String, double>? progressMap = _progressMap[sessionId];
    if (progressMap == null) {
      progressMap = {};
      _progressMap[sessionId] = progressMap;
    }
    progressMap[fileId] = progress;
    notifyListeners();
    scheduleIosLiveActivityProgressSync();
  }

  double getProgress({required String sessionId, required String fileId}) {
    return _progressMap[sessionId]?[fileId] ?? 0.0;
  }

  void setWindowsReceivePostProcess({
    required String sessionId,
    required String fileId,
    required bool active,
  }) {
    if (active) {
      (_windowsReceivePostProcess[sessionId] ??= <String>{}).add(fileId);
    } else {
      _windowsReceivePostProcess[sessionId]?.remove(fileId);
      if (_windowsReceivePostProcess[sessionId]?.isEmpty ?? false) {
        _windowsReceivePostProcess.remove(sessionId);
      }
    }
    notifyListeners();
    scheduleIosLiveActivityProgressSync();
  }

  bool isWindowsReceivePostProcess({required String sessionId, required String fileId}) {
    return _windowsReceivePostProcess[sessionId]?.contains(fileId) ?? false;
  }

  void removeSession(String sessionId) {
    _progressMap.remove(sessionId);
    _windowsReceivePostProcess.remove(sessionId);
    notifyListeners();
    scheduleIosLiveActivityProgressSync();
  }

  void removeAllSessions() {
    _progressMap.clear();
    _windowsReceivePostProcess.clear();
    notifyListeners();
    scheduleIosLiveActivityProgressSync();
  }

  /// Only for debug purposes
  Map<String, Map<String, double>> getData() {
    return _progressMap;
  }
}
