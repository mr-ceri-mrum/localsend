import 'package:dart_mappable/dart_mappable.dart';

part 'windows_video_conversion_mode.mapper.dart';

@MappableEnum()
enum WindowsVideoConversionMode {
  /// Keep the received file unchanged (e.g. for editing in CapCut, Adobe).
  original,

  /// Remux to MP4 with stream copy (no re-encoding; codecs unchanged).
  remuxMp4,

  /// Transcode to H.264/AAC for broad Windows playback (may reduce quality).
  transcodeH264,
}
