import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Extends runtime while the user has switched away during an active file transfer.
  /// A single task expires after a short budget (~30s typical); we renew periodically so
  /// large transfers can keep running in the background for much longer.
  private var fileTransferBackgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var fileTransferRenewTimer: Timer?

  /// Renew before the usual expiration window so the execution budget resets.
  private static let backgroundTaskRenewIntervalSeconds: TimeInterval = 22

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController

    let engine = controller.engine
    let channel = FlutterMethodChannel(
      name: "ios-delegate-channel",
      binaryMessenger: engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: nil, details: nil))
        return
      }
      switch call.method {
      case "isReduceMotionEnabled":
        result(UIAccessibility.isReduceMotionEnabled)
      case "beginFileTransferBackground":
        self.startOrContinueFileTransferBackground()
        result(nil)
      case "endFileTransferBackground":
        self.stopFileTransferBackground()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func startOrContinueFileTransferBackground() {
    if fileTransferBackgroundTask == .invalid {
      beginNewFileTransferBackgroundTask()
    }
    if fileTransferRenewTimer == nil {
      let interval = Self.backgroundTaskRenewIntervalSeconds
      let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
        self?.renewFileTransferBackgroundTaskIfNeeded()
      }
      fileTransferRenewTimer = timer
      RunLoop.main.add(timer, forMode: .common)
    }
  }

  private func beginNewFileTransferBackgroundTask() {
    fileTransferBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "org.localsend.filetransfer") { [weak self] in
      self?.onFileTransferBackgroundTaskExpired()
    }
    if fileTransferBackgroundTask == .invalid {
      fileTransferRenewTimer?.invalidate()
      fileTransferRenewTimer = nil
    }
  }

  /// End the current task and request a new one so the background time budget resets.
  private func renewFileTransferBackgroundTaskIfNeeded() {
    guard fileTransferBackgroundTask != .invalid else {
      return
    }
    UIApplication.shared.endBackgroundTask(fileTransferBackgroundTask)
    fileTransferBackgroundTask = .invalid
    beginNewFileTransferBackgroundTask()
  }

  private func onFileTransferBackgroundTaskExpired() {
    // Last-chance extension: grab a new task if Flutter still considers transfer active
    // (renewal timer should normally run before this).
    renewFileTransferBackgroundTaskIfNeeded()
  }

  private func stopFileTransferBackground() {
    fileTransferRenewTimer?.invalidate()
    fileTransferRenewTimer = nil
    if fileTransferBackgroundTask != .invalid {
      UIApplication.shared.endBackgroundTask(fileTransferBackgroundTask)
      fileTransferBackgroundTask = .invalid
    }
  }
}