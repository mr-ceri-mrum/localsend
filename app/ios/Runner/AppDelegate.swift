import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var fileTransferBackgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var fileTransferRenewTimer: Timer?
  private var silentAudioPlayer: AVAudioPlayer?
  private var isTransferActive = false

  private static let backgroundTaskRenewIntervalSeconds: TimeInterval = 5

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
        self.startFileTransferBackground()
        result(nil)
      case "endFileTransferBackground":
        self.stopFileTransferBackground()
        result(nil)
      case "pulseFileTransferBackground":
        self.pulseFileTransferBackground()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Public entry points

  private func startFileTransferBackground() {
    isTransferActive = true
    startSilentAudio()
    beginNewBackgroundTaskIfNeeded()
    ensureRenewTimer()
  }

  private func pulseFileTransferBackground() {
    isTransferActive = true
    startSilentAudio()
    if fileTransferBackgroundTask == .invalid {
      beginNewBackgroundTaskIfNeeded()
    } else {
      renewBackgroundTask()
    }
    ensureRenewTimer()
  }

  private func stopFileTransferBackground() {
    isTransferActive = false
    stopSilentAudio()
    fileTransferRenewTimer?.invalidate()
    fileTransferRenewTimer = nil
    if fileTransferBackgroundTask != .invalid {
      UIApplication.shared.endBackgroundTask(fileTransferBackgroundTask)
      fileTransferBackgroundTask = .invalid
    }
  }

  // MARK: - Silent audio (keeps the app alive in background)

  private func startSilentAudio() {
    guard silentAudioPlayer == nil else { return }

    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
    } catch {
      return
    }

    guard let player = Self.createSilentPlayer() else { return }
    player.numberOfLoops = -1
    player.volume = 0.01
    player.play()
    silentAudioPlayer = player
  }

  private func stopSilentAudio() {
    silentAudioPlayer?.stop()
    silentAudioPlayer = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  /// Builds an AVAudioPlayer with 1 second of PCM silence (no file needed).
  private static func createSilentPlayer() -> AVAudioPlayer? {
    let sampleRate: Int = 44100
    let numSamples = sampleRate // 1 second
    let bytesPerSample = 2 // 16-bit
    let dataSize = numSamples * bytesPerSample

    var wav = Data()
    // RIFF header
    wav.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
    wav.appendLittleEndianUInt32(UInt32(36 + dataSize))
    wav.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
    // fmt sub-chunk
    wav.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
    wav.appendLittleEndianUInt32(16)      // sub-chunk size
    wav.appendLittleEndianUInt16(1)       // PCM
    wav.appendLittleEndianUInt16(1)       // mono
    wav.appendLittleEndianUInt32(UInt32(sampleRate))
    wav.appendLittleEndianUInt32(UInt32(sampleRate * bytesPerSample))
    wav.appendLittleEndianUInt16(UInt16(bytesPerSample))
    wav.appendLittleEndianUInt16(16)      // bits per sample
    // data sub-chunk
    wav.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
    wav.appendLittleEndianUInt32(UInt32(dataSize))
    wav.append(contentsOf: [UInt8](repeating: 0, count: dataSize))

    return try? AVAudioPlayer(data: wav)
  }

  // MARK: - Background task management (belt-and-suspenders alongside audio)

  private func ensureRenewTimer() {
    guard fileTransferRenewTimer == nil else { return }
    let interval = Self.backgroundTaskRenewIntervalSeconds
    let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
      guard let self = self, self.isTransferActive else { return }
      self.startSilentAudio()
      if self.fileTransferBackgroundTask == .invalid {
        self.beginNewBackgroundTaskIfNeeded()
      } else {
        self.renewBackgroundTask()
      }
    }
    fileTransferRenewTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func beginNewBackgroundTaskIfNeeded() {
    guard fileTransferBackgroundTask == .invalid else { return }
    fileTransferBackgroundTask = UIApplication.shared.beginBackgroundTask(
      withName: "org.localsend.filetransfer"
    ) { [weak self] in
      self?.onBackgroundTaskExpired()
    }
  }

  private func renewBackgroundTask() {
    let old = fileTransferBackgroundTask
    guard old != .invalid else {
      beginNewBackgroundTaskIfNeeded()
      return
    }
    fileTransferBackgroundTask = .invalid
    beginNewBackgroundTaskIfNeeded()
    UIApplication.shared.endBackgroundTask(old)
  }

  private func onBackgroundTaskExpired() {
    let expired = fileTransferBackgroundTask
    fileTransferBackgroundTask = .invalid
    if expired != .invalid {
      UIApplication.shared.endBackgroundTask(expired)
    }
    if isTransferActive {
      beginNewBackgroundTaskIfNeeded()
    }
  }
}

// MARK: - Data helpers

private extension Data {
  mutating func appendLittleEndianUInt32(_ value: UInt32) {
    var v = value.littleEndian
    append(Data(bytes: &v, count: 4))
  }
  mutating func appendLittleEndianUInt16(_ value: UInt16) {
    var v = value.littleEndian
    append(Data(bytes: &v, count: 2))
  }
}
