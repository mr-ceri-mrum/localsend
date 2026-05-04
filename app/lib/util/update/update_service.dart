import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

final _logger = Logger('UpdateService');

class UpdateReleaseInfo {
  final String remoteVersion;
  final String installerUrl;

  const UpdateReleaseInfo({
    required this.remoteVersion,
    required this.installerUrl,
  });
}

enum UpdateCheckErrorType {
  notWindows,
  noInternet,
  apiUnavailable,
  invalidResponse,
  noAssets,
}

class UpdateCheckResult {
  final bool isUpdateAvailable;
  final UpdateReleaseInfo? releaseInfo;
  final UpdateCheckErrorType? errorType;
  final String? details;

  const UpdateCheckResult._({
    required this.isUpdateAvailable,
    this.releaseInfo,
    this.errorType,
    this.details,
  });

  const UpdateCheckResult.noUpdate() : this._(isUpdateAvailable: false);

  const UpdateCheckResult.updateAvailable(UpdateReleaseInfo info)
      : this._(
          isUpdateAvailable: true,
          releaseInfo: info,
        );

  const UpdateCheckResult.error(UpdateCheckErrorType type, {String? details})
      : this._(
          isUpdateAvailable: false,
          errorType: type,
          details: details,
        );
}

enum InstallUpdateErrorType {
  notWindows,
  downloadFailed,
  processStartFailed,
}

class InstallUpdateResult {
  final bool isSuccess;
  final InstallUpdateErrorType? errorType;
  final String? details;

  const InstallUpdateResult._({
    required this.isSuccess,
    this.errorType,
    this.details,
  });

  const InstallUpdateResult.success() : this._(isSuccess: true);

  const InstallUpdateResult.error(InstallUpdateErrorType type, {String? details})
      : this._(
          isSuccess: false,
          errorType: type,
          details: details,
        );
}

class UpdateService {
  static const String _latestReleaseUrl = 'https://api.github.com/repos/mr-ceri-mrum/localsend/releases/latest';
  static const Duration _requestTimeout = Duration(seconds: 12);

  const UpdateService();

  Future<UpdateCheckResult> checkForUpdates() async {
    if (!Platform.isWindows) {
      return const UpdateCheckResult.error(UpdateCheckErrorType.notWindows);
    }

    final localVersion = await PackageInfo.fromPlatform().then((v) => v.version);

    final HttpClient client = HttpClient();
    client.connectionTimeout = _requestTimeout;

    try {
      final request = await client.getUrl(Uri.parse(_latestReleaseUrl)).timeout(_requestTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'Windrop-Updater');
      final response = await request.close().timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return UpdateCheckResult.error(
          UpdateCheckErrorType.apiUnavailable,
          details: 'Status code: ${response.statusCode}',
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final dynamic jsonBody = jsonDecode(body);
      if (jsonBody is! Map<String, dynamic>) {
        return const UpdateCheckResult.error(UpdateCheckErrorType.invalidResponse);
      }

      final tagName = jsonBody['tag_name'] as String?;
      final assets = jsonBody['assets'];
      if (tagName == null || tagName.trim().isEmpty) {
        return const UpdateCheckResult.error(UpdateCheckErrorType.invalidResponse, details: 'Missing tag_name');
      }
      if (assets is! List || assets.isEmpty) {
        return const UpdateCheckResult.error(UpdateCheckErrorType.noAssets);
      }

      final remoteVersion = _normalizeVersion(tagName);
      final normalizedLocalVersion = _normalizeVersion(localVersion);
      if (!_isValidSemver(remoteVersion) || !_isValidSemver(normalizedLocalVersion)) {
        return UpdateCheckResult.error(
          UpdateCheckErrorType.invalidResponse,
          details: 'Invalid semver local="$normalizedLocalVersion" remote="$remoteVersion"',
        );
      }

      final installerUrl = _pickInstallerUrl(
        assets: assets,
        remoteVersion: remoteVersion,
      );
      if (installerUrl == null) {
        return const UpdateCheckResult.error(
          UpdateCheckErrorType.noAssets,
          details: 'No downloadable Windows installer (.exe) found in release assets',
        );
      }

      if (_compareSemver(remoteVersion, normalizedLocalVersion) > 0) {
        return UpdateCheckResult.updateAvailable(
          UpdateReleaseInfo(
            remoteVersion: remoteVersion,
            installerUrl: installerUrl,
          ),
        );
      }

      return const UpdateCheckResult.noUpdate();
    } on SocketException catch (e) {
      return UpdateCheckResult.error(UpdateCheckErrorType.noInternet, details: e.message);
    } on HandshakeException catch (e) {
      return UpdateCheckResult.error(UpdateCheckErrorType.apiUnavailable, details: e.message);
    } on HttpException catch (e) {
      return UpdateCheckResult.error(UpdateCheckErrorType.apiUnavailable, details: e.message);
    } on FormatException catch (e) {
      return UpdateCheckResult.error(UpdateCheckErrorType.invalidResponse, details: e.message);
    } on TimeoutException catch (e) {
      return UpdateCheckResult.error(UpdateCheckErrorType.apiUnavailable, details: e.message);
    } catch (e, stackTrace) {
      _logger.warning('Unknown update check error', e, stackTrace);
      return UpdateCheckResult.error(UpdateCheckErrorType.apiUnavailable, details: e.toString());
    } finally {
      client.close(force: true);
    }
  }

  String? _pickInstallerUrl({
    required List assets,
    required String remoteVersion,
  }) {
    Map<String, dynamic>? fallback;
    final normalizedVersion = remoteVersion.toLowerCase();

    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) {
        continue;
      }

      final name = (asset['name'] as String?)?.toLowerCase() ?? '';
      final url = (asset['browser_download_url'] as String?)?.trim() ?? '';
      if (url.isEmpty || (!url.toLowerCase().endsWith('.exe') && !name.endsWith('.exe'))) {
        continue;
      }

      fallback ??= asset;

      if (name.contains(normalizedVersion) || url.toLowerCase().contains(normalizedVersion)) {
        return url;
      }
    }

    return (fallback?['browser_download_url'] as String?)?.trim();
  }

  Future<InstallUpdateResult> downloadAndInstall({
    required String installerUrl,
  }) async {
    if (!Platform.isWindows) {
      return const InstallUpdateResult.error(InstallUpdateErrorType.notWindows);
    }

    final HttpClient client = HttpClient();
    client.connectionTimeout = _requestTimeout;

    try {
      final request = await client.getUrl(Uri.parse(installerUrl)).timeout(_requestTimeout);
      request.headers.set(HttpHeaders.userAgentHeader, 'Windrop-Updater');
      final response = await request.close().timeout(const Duration(minutes: 2));
      if (response.statusCode != 200) {
        return InstallUpdateResult.error(
          InstallUpdateErrorType.downloadFailed,
          details: 'Download status code: ${response.statusCode}',
        );
      }

      final tempDir = await Directory.systemTemp.createTemp('windrop_update_');
      final installerPath = '${tempDir.path}${Platform.pathSeparator}Windrop-Update-Installer.exe';
      final installerFile = File(installerPath);
      await response.pipe(installerFile.openWrite());

      await Process.start(
        installerPath,
        <String>[],
        mode: ProcessStartMode.detached,
      );

      return const InstallUpdateResult.success();
    } on SocketException catch (e) {
      return InstallUpdateResult.error(InstallUpdateErrorType.downloadFailed, details: e.message);
    } on HttpException catch (e) {
      return InstallUpdateResult.error(InstallUpdateErrorType.downloadFailed, details: e.message);
    } on TimeoutException catch (e) {
      return InstallUpdateResult.error(InstallUpdateErrorType.downloadFailed, details: e.message);
    } on ProcessException catch (e) {
      return InstallUpdateResult.error(InstallUpdateErrorType.processStartFailed, details: e.message);
    } catch (e, stackTrace) {
      _logger.warning('Unknown update install error', e, stackTrace);
      return InstallUpdateResult.error(InstallUpdateErrorType.downloadFailed, details: e.toString());
    } finally {
      client.close(force: true);
    }
  }

  String _normalizeVersion(String version) {
    var v = version.trim();
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }
    if (v.contains('+')) {
      v = v.split('+').first;
    }
    return v;
  }

  bool _isValidSemver(String version) {
    final regex = RegExp(r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$');
    return regex.hasMatch(version);
  }

  int _compareSemver(String a, String b) {
    final aParts = _splitSemver(a);
    final bParts = _splitSemver(b);

    for (var i = 0; i < 3; i++) {
      final cmp = aParts.core[i].compareTo(bParts.core[i]);
      if (cmp != 0) {
        return cmp;
      }
    }

    final aPre = aParts.preRelease;
    final bPre = bParts.preRelease;
    if (aPre == null && bPre == null) {
      return 0;
    }
    if (aPre == null) {
      return 1;
    }
    if (bPre == null) {
      return -1;
    }

    return aPre.compareTo(bPre);
  }

  _SemverParts _splitSemver(String version) {
    final split = version.split('-');
    final core = split.first.split('.').map(int.parse).toList(growable: false);
    final preRelease = split.length > 1 ? split.sublist(1).join('-') : null;
    return _SemverParts(core: core, preRelease: preRelease);
  }
}

class _SemverParts {
  final List<int> core;
  final String? preRelease;

  const _SemverParts({
    required this.core,
    required this.preRelease,
  });
}
