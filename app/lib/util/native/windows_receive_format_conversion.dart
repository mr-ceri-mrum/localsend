import 'dart:io';

import 'package:common/model/file_type.dart';
import 'package:localsend_app/model/state/settings_state.dart';
import 'package:localsend_app/model/windows_video_conversion_mode.dart';
import 'package:localsend_app/util/file_path_helper.dart';
import 'package:localsend_app/util/native/file_saver.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

final _logger = Logger('WindowsReceiveFormatConversion');

/// Result of converting a received file for Windows compatibility.
class WindowsReceiveFormatConversionResult {
  final String path;
  final String fileName;
  final int fileSize;

  const WindowsReceiveFormatConversionResult({
    required this.path,
    required this.fileName,
    required this.fileSize,
  });
}

/// Runs HEIC/HEIF→PNG and optional video remux/transcode when [settings] and file type require it.
///
/// Returns `null` if the file was left unchanged (no conversion or ffmpeg unavailable).
Future<WindowsReceiveFormatConversionResult?> applyWindowsReceiveConversion({
  required String savedFilePath,
  required FileType fileType,
  required SettingsState settings,
  required String destinationDirectory,
  required Set<String> createdDirectories,
}) async {
  if (!Platform.isWindows) {
    return null;
  }

  final ext = savedFilePath.extension.toLowerCase();
  if (!_needsConversionForFile(fileType, ext, settings)) {
    return null;
  }

  final ffmpeg = await _resolveFfmpegExecutable(settings.ffmpegCustomPath);
  if (ffmpeg == null) {
    _logger.warning('FFmpeg not found; skipping Windows format conversion. Install FFmpeg or set a path in settings.');
    return null;
  }

  if (fileType == FileType.image && settings.convertHeicOnReceive && (ext == 'heic' || ext == 'heif')) {
    return _convertHeicToPng(
      savedFilePath: savedFilePath,
      ffmpeg: ffmpeg,
      destinationDirectory: destinationDirectory,
      createdDirectories: createdDirectories,
    );
  }

  // iOS sometimes sends video/quicktime as application/octet-stream or similar → [FileType.other].
  // Still treat known container extensions as video for conversion.
  if (_isWindowsVideoContainer(fileType, ext)) {
    final mode = settings.windowsVideoConversionMode;
    if (mode == WindowsVideoConversionMode.original) {
      return null;
    }
    if (mode == WindowsVideoConversionMode.remuxMp4) {
      if (ext == 'mp4') {
        return null;
      }
      if (ext != 'mov' && ext != 'm4v') {
        return null;
      }
      return _remuxToMp4(
        savedFilePath: savedFilePath,
        ffmpeg: ffmpeg,
        destinationDirectory: destinationDirectory,
        createdDirectories: createdDirectories,
      );
    }
    if (mode == WindowsVideoConversionMode.transcodeH264) {
      if (ext != 'mov' && ext != 'm4v' && ext != 'mp4') {
        return null;
      }
      return _transcodeToH264(
        savedFilePath: savedFilePath,
        ffmpeg: ffmpeg,
        destinationDirectory: destinationDirectory,
        createdDirectories: createdDirectories,
      );
    }
  }

  return null;
}

/// True when this file should be handled by the video conversion pipeline on Windows.
bool _isWindowsVideoContainer(FileType fileType, String extLower) {
  if (fileType == FileType.video) {
    return true;
  }
  // Fallback when MIME was not classified as video (e.g. application/octet-stream).
  return extLower == 'mov' || extLower == 'm4v' || extLower == 'mp4';
}

String _historyRelativeName(String outputPath, String destinationDirectory) {
  final rel = p.relative(outputPath, from: destinationDirectory);
  if (rel.startsWith('..')) {
    return p.basename(outputPath);
  }
  return rel.replaceAll('\\', '/');
}

/// Whether this file might be converted given current settings (before checking ffmpeg availability).
bool _needsConversionForFile(FileType fileType, String extLower, SettingsState settings) {
  if (fileType == FileType.image && settings.convertHeicOnReceive && (extLower == 'heic' || extLower == 'heif')) {
    return true;
  }
  if (_isWindowsVideoContainer(fileType, extLower)) {
    final mode = settings.windowsVideoConversionMode;
    if (mode == WindowsVideoConversionMode.original) {
      return false;
    }
    if (mode == WindowsVideoConversionMode.remuxMp4) {
      return extLower == 'mov' || extLower == 'm4v';
    }
    if (mode == WindowsVideoConversionMode.transcodeH264) {
      return extLower == 'mov' || extLower == 'm4v' || extLower == 'mp4';
    }
  }
  return false;
}

Future<String?> _resolveFfmpegExecutable(String? customPath) async {
  if (customPath != null && customPath.trim().isNotEmpty) {
    final f = File(customPath.trim());
    if (await f.exists()) {
      return f.absolute.path;
    }
    _logger.warning('Custom FFmpeg path does not exist: $customPath');
  }

  final bundled = p.join(File(Platform.resolvedExecutable).parent.path, 'ffmpeg.exe');
  if (await File(bundled).exists()) {
    return bundled;
  }

  final r = await Process.run('where.exe', ['ffmpeg'], runInShell: false);
  if (r.exitCode == 0) {
    final line = r.stdout.toString().split('\r\n').first.trim();
    if (line.isNotEmpty && await File(line).exists()) {
      return line;
    }
  }
  return null;
}

Future<WindowsReceiveFormatConversionResult?> _convertHeicToPng({
  required String savedFilePath,
  required String ffmpeg,
  required String destinationDirectory,
  required Set<String> createdDirectories,
}) async {
  final base = p.basenameWithoutExtension(p.basename(savedFilePath));
  final pngFileName = '$base.png';
  final (outPath, _, _) = await digestFilePathAndPrepareDirectory(
    parentDirectory: p.dirname(savedFilePath),
    fileName: pngFileName,
    createdDirectories: createdDirectories,
  );

  final code = await _runFfmpeg(ffmpeg, [
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-i',
    savedFilePath,
    outPath,
  ]);
  if (code != 0) {
    _logger.warning('HEIC→PNG conversion failed');
    try {
      await File(outPath).delete();
    } catch (_) {}
    return null;
  }

  try {
    await File(savedFilePath).delete();
  } catch (e) {
    _logger.warning('Could not delete source HEIC after conversion', e);
  }

  final size = await File(outPath).length();
  return WindowsReceiveFormatConversionResult(
    path: outPath,
    fileName: _historyRelativeName(outPath, destinationDirectory),
    fileSize: size,
  );
}

Future<WindowsReceiveFormatConversionResult?> _remuxToMp4({
  required String savedFilePath,
  required String ffmpeg,
  required String destinationDirectory,
  required Set<String> createdDirectories,
}) async {
  final base = p.basenameWithoutExtension(p.basename(savedFilePath));
  final mp4FileName = '$base.mp4';
  final (outPath, _, _) = await digestFilePathAndPrepareDirectory(
    parentDirectory: p.dirname(savedFilePath),
    fileName: mp4FileName,
    createdDirectories: createdDirectories,
  );

  final code = await _runFfmpeg(ffmpeg, [
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-i',
    savedFilePath,
    '-c',
    'copy',
    '-movflags',
    '+faststart',
    outPath,
  ]);
  if (code != 0) {
    _logger.warning('Video remux failed');
    try {
      await File(outPath).delete();
    } catch (_) {}
    return null;
  }

  try {
    await File(savedFilePath).delete();
  } catch (e) {
    _logger.warning('Could not delete source video after remux', e);
  }

  final size = await File(outPath).length();
  return WindowsReceiveFormatConversionResult(
    path: outPath,
    fileName: _historyRelativeName(outPath, destinationDirectory),
    fileSize: size,
  );
}

Future<WindowsReceiveFormatConversionResult?> _transcodeToH264({
  required String savedFilePath,
  required String ffmpeg,
  required String destinationDirectory,
  required Set<String> createdDirectories,
}) async {
  final base = p.basenameWithoutExtension(p.basename(savedFilePath));
  final mp4FileName = '$base.mp4';
  final (outPath, _, _) = await digestFilePathAndPrepareDirectory(
    parentDirectory: p.dirname(savedFilePath),
    fileName: mp4FileName,
    createdDirectories: createdDirectories,
  );

  final code = await _runFfmpeg(ffmpeg, [
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-i',
    savedFilePath,
    '-c:v',
    'libx264',
    '-crf',
    '18',
    '-preset',
    'medium',
    '-c:a',
    'aac',
    '-b:a',
    '192k',
    '-movflags',
    '+faststart',
    outPath,
  ]);
  if (code != 0) {
    _logger.warning('Video transcode failed');
    try {
      await File(outPath).delete();
    } catch (_) {}
    return null;
  }

  try {
    await File(savedFilePath).delete();
  } catch (e) {
    _logger.warning('Could not delete source video after transcode', e);
  }

  final size = await File(outPath).length();
  return WindowsReceiveFormatConversionResult(
    path: outPath,
    fileName: _historyRelativeName(outPath, destinationDirectory),
    fileSize: size,
  );
}

Future<int> _runFfmpeg(String executable, List<String> args) async {
  final r = await Process.run(executable, args, runInShell: false);
  if (r.exitCode != 0) {
    _logger.warning('ffmpeg stderr: ${r.stderr}');
  }
  return r.exitCode;
}
