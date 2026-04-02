import 'package:localsend_app/util/native/ios_live_activity_sync.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// A provider holding the progress of the send process.
/// It is implemented as [ChangeNotifier] for performance reasons.
final progressProvider = ChangeNotifierProvider((ref) => ProgressNotifier());

class ProgressNotifier extends ChangeNotifier {
  final _progressMap = <String, Map<String, double>>{}; // session id -> (file id -> 0..1)

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

  void removeSession(String sessionId) {
    _progressMap.remove(sessionId);
    notifyListeners();
    scheduleIosLiveActivityProgressSync();
  }

  void removeAllSessions() {
    _progressMap.clear();
    notifyListeners();
    scheduleIosLiveActivityProgressSync();
  }

  /// Only for debug purposes
  Map<String, Map<String, double>> getData() {
    return _progressMap;
  }
}
