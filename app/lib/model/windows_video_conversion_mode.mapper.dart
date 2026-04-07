// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'windows_video_conversion_mode.dart';

class WindowsVideoConversionModeMapper
    extends EnumMapper<WindowsVideoConversionMode> {
  WindowsVideoConversionModeMapper._();

  static WindowsVideoConversionModeMapper? _instance;
  static WindowsVideoConversionModeMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(
        _instance = WindowsVideoConversionModeMapper._(),
      );
    }
    return _instance!;
  }

  static WindowsVideoConversionMode fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  WindowsVideoConversionMode decode(dynamic value) {
    switch (value) {
      case r'original':
        return WindowsVideoConversionMode.original;
      case r'remuxMp4':
        return WindowsVideoConversionMode.remuxMp4;
      case r'transcodeH264':
        return WindowsVideoConversionMode.transcodeH264;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(WindowsVideoConversionMode self) {
    switch (self) {
      case WindowsVideoConversionMode.original:
        return r'original';
      case WindowsVideoConversionMode.remuxMp4:
        return r'remuxMp4';
      case WindowsVideoConversionMode.transcodeH264:
        return r'transcodeH264';
    }
  }
}

extension WindowsVideoConversionModeMapperExtension
    on WindowsVideoConversionMode {
  String toValue() {
    WindowsVideoConversionModeMapper.ensureInitialized();
    return MapperContainer.globals.toValue<WindowsVideoConversionMode>(this)
        as String;
  }
}

