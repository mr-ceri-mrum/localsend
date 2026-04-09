import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:refena_flutter/refena_flutter.dart';

enum WindowsConversionPreset {
  imageToPng,
  videoRemuxMp4,
  videoTranscodeMp4,
}

final windowsManualConversionProvider = ChangeNotifierProvider(
  (ref) => WindowsManualConversionNotifier(),
);

class WindowsManualConversionNotifier extends ChangeNotifier {
  bool isConverting = false;
  String status = 'Ready to convert';
  int elapsedSeconds = 0;

  Timer? _timer;

  Future<String?> start({
    required String inputPath,
    required String outputDirectory,
    required WindowsConversionPreset preset,
    required String? ffmpegCustomPath,
  }) async {
    if (isConverting) {
      return null;
    }
    isConverting = true;
    status = 'Starting FFmpeg...';
    elapsedSeconds = 0;
    notifyListeners();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isConverting) {
        return;
      }
      elapsedSeconds += 1;
      notifyListeners();
    });

    final result = await _manualWindowsConvert(
      inputPath: inputPath,
      outputDirectory: outputDirectory,
      preset: preset,
      ffmpegCustomPath: ffmpegCustomPath,
      onStatus: (msg) {
        status = msg;
        notifyListeners();
      },
    );

    _timer?.cancel();
    isConverting = false;
    status = result != null ? 'Done' : 'Failed';
    notifyListeners();
    return result;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

Future<String?> _manualWindowsConvert({
  required String inputPath,
  required String outputDirectory,
  required WindowsConversionPreset preset,
  required String? ffmpegCustomPath,
  required void Function(String message) onStatus,
}) async {
  final ffmpeg = await _resolveFfmpegExecutableManual(ffmpegCustomPath);
  if (ffmpeg == null) {
    return null;
  }

  // Keep manual conversion laptop-friendly by default:
  // - cap CPU threads
  // - use lighter x264 settings for transcode mode
  final threads = _computeFfmpegThreadLimit();
  final threadArgs = ['-threads', '$threads'];

  final inputBaseName = p.basenameWithoutExtension(inputPath);
  final outputPath = p.join(outputDirectory, switch (preset) {
    WindowsConversionPreset.imageToPng => '$inputBaseName.png',
    WindowsConversionPreset.videoRemuxMp4 || WindowsConversionPreset.videoTranscodeMp4 => '$inputBaseName.mp4',
  });

  final args = switch (preset) {
    WindowsConversionPreset.imageToPng => [
      '-hide_banner',
      '-loglevel',
      'error',
      '-y',
      ...threadArgs,
      '-i',
      inputPath,
      outputPath,
    ],
    WindowsConversionPreset.videoRemuxMp4 => [
      '-hide_banner',
      '-loglevel',
      'error',
      '-y',
      ...threadArgs,
      '-i',
      inputPath,
      '-c',
      'copy',
      '-movflags',
      '+faststart',
      outputPath,
    ],
    WindowsConversionPreset.videoTranscodeMp4 => _buildTranscodeArgs(
      ffmpegExecutable: ffmpeg,
      inputPath: inputPath,
      outputPath: outputPath,
      threadArgs: threadArgs,
      onStatus: onStatus,
    ),
  };

  onStatus('Converting ${p.basename(inputPath)}');
  try {
    final r = await Process.run(ffmpeg, args, runInShell: false);
    if (r.exitCode != 0) {
      return null;
    }
    return outputPath;
  } catch (_) {
    return null;
  }
}

List<String> _buildTranscodeArgs({
  required String ffmpegExecutable,
  required String inputPath,
  required String outputPath,
  required List<String> threadArgs,
  required void Function(String message) onStatus,
}) {
  final preferredEncoder = _detectPreferredH264Encoder(ffmpegExecutable);
  final commonPrefix = <String>[
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-i',
    inputPath,
    '-sn',
    '-dn',
    '-pix_fmt',
    'yuv420p',
    '-vf',
    // Bicubic is lighter than lanczos and usually good enough for compatibility conversion.
    'scale=trunc(iw/2)*2:trunc(ih/2)*2:flags=bicubic',
    ...threadArgs,
    '-c:a',
    'aac',
    '-b:a',
    '128k',
    '-ar',
    '48000',
    '-ac',
    '2',
    '-movflags',
    '+faststart',
  ];

  if (preferredEncoder == 'h264_nvenc') {
    onStatus('Converting (NVIDIA GPU)');
    return [
      ...commonPrefix,
      '-c:v',
      'h264_nvenc',
      '-preset',
      'p4',
      '-cq',
      '24',
      '-b:v',
      '0',
      outputPath,
    ];
  }
  if (preferredEncoder == 'h264_qsv') {
    onStatus('Converting (Intel Quick Sync)');
    return [
      ...commonPrefix,
      '-c:v',
      'h264_qsv',
      '-global_quality',
      '24',
      outputPath,
    ];
  }
  if (preferredEncoder == 'h264_amf') {
    onStatus('Converting (AMD AMF)');
    return [
      ...commonPrefix,
      '-c:v',
      'h264_amf',
      '-quality',
      'balanced',
      '-qp_i',
      '24',
      '-qp_p',
      '26',
      outputPath,
    ];
  }

  onStatus('Converting (CPU mode)');
  return [
    ...commonPrefix,
    '-c:v',
    'libx264',
    '-preset',
    'ultrafast',
    '-crf',
    '24',
    '-tune',
    'fastdecode',
    '-x264-params',
    'rc-lookahead=10:ref=2:bframes=2',
    outputPath,
  ];
}

String? _detectPreferredH264Encoder(String ffmpegExecutable) {
  try {
    final r = Process.runSync(ffmpegExecutable, ['-hide_banner', '-encoders'], runInShell: false);
    if (r.exitCode != 0) {
      return null;
    }
    final encoders = r.stdout.toString();
    if (encoders.contains('h264_nvenc')) {
      return 'h264_nvenc';
    }
    if (encoders.contains('h264_qsv')) {
      return 'h264_qsv';
    }
    if (encoders.contains('h264_amf')) {
      return 'h264_amf';
    }
    return null;
  } catch (_) {
    return null;
  }
}

Future<String?> _resolveFfmpegExecutableManual(String? customPath) async {
  if (customPath != null && customPath.trim().isNotEmpty) {
    final f = File(customPath.trim());
    if (await f.exists()) {
      return f.absolute.path;
    }
  }

  final bundled = p.join(File(Platform.resolvedExecutable).parent.path, 'ffmpeg.exe');
  if (await File(bundled).exists()) {
    return bundled;
  }

  final result = await Process.run('where.exe', ['ffmpeg'], runInShell: false);
  if (result.exitCode == 0) {
    final line = result.stdout.toString().split('\r\n').first.trim();
    if (line.isNotEmpty && await File(line).exists()) {
      return line;
    }
  }
  return null;
}

int _computeFfmpegThreadLimit() {
  final cpus = math.max(1, Platform.numberOfProcessors);
  // Keep RAM/CPU usage predictable on laptops.
  return (cpus / 2).floor().clamp(1, 2);
}
