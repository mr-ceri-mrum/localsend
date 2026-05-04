import 'package:common/model/device.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'nearby_devices_state.mapper.dart';

@MappableClass()
class NearbyDevicesState with NearbyDevicesStateMappable {
  final bool runningFavoriteScan;
  final Set<String> runningIps; // list of local ips
  final Map<String, Device> devices; // ip -> device

  /// Devices that are discovered via signaling server.
  /// The key is the fingerprint of the device.
  /// We do not trust the fingerprint, so we allow multiple devices with the same fingerprint.
  final Map<String, Set<Device>> signalingDevices;

  const NearbyDevicesState({
    required this.runningFavoriteScan,
    required this.runningIps,
    required this.devices,
    required this.signalingDevices,
  });

  /// Unified list for the UI: one row per logical device.
  ///
  /// [devices] is keyed by IP, while signaling entries share the same [Device.fingerprint]
  /// as LAN discovery. Merging must look up by fingerprint, not by map key, otherwise the
  /// same physical device appears twice (LAN + WebRTC) and taps on WebRTC-only rows fail
  /// when HTTP needs [Device.ip].
  Map<String, Device> get allDevices {
    final Map<String, Device> merged = {};

    String primaryKey(Device device) =>
        device.fingerprint.isNotEmpty ? device.fingerprint : '__nfp__::${device.alias}::${device.ip ?? device.signalingId ?? ""}';

    void putOrMerge(Device device) {
      final key = primaryKey(device);
      final existing = merged[key];
      if (existing == null) {
        merged[key] = device;
        return;
      }
      if (existing.alias == device.alias) {
        merged[key] = existing.merge(device);
      } else {
        // Same fingerprint but different alias: do not trust fingerprint alone.
        merged['$key::${device.alias}'] = device;
      }
    }

    for (final device in devices.values) {
      putOrMerge(device);
    }
    for (final signalingList in signalingDevices.values) {
      for (final device in signalingList) {
        putOrMerge(device);
      }
    }

    // Signaling clients may rotate keys on each connect (see signaling TODO), so the same
    // machine can appear with different fingerprints. Collapse rows that share display
    // identity and either one LAN endpoint or all signaling-only.
    final collapsed = _collapseDuplicateAliases(merged.values);
    return {for (var i = 0; i < collapsed.length; i++) 'd_$i': collapsed[i]};
  }
}

/// LAN-capable device (has address for HTTP discovery / send).
bool _hasConnectableIp(Device d) => d.ip != null && d.ip!.isNotEmpty;

String _displayIdentityKey(Device d) => '${d.alias}\x00${d.deviceType.name}\x00${d.deviceModel ?? ''}';

/// Merges [group] (same alias + type + model) into one row when they are clearly one host
/// (single IP-bearing discovery + signaling clones, or multiple signaling-only duplicates).
List<Device> _collapseDuplicateAliases(Iterable<Device> devices) {
  final byIdentity = <String, List<Device>>{};
  for (final d in devices) {
    byIdentity.putIfAbsent(_displayIdentityKey(d), () => []).add(d);
  }

  final out = <Device>[];
  for (final group in byIdentity.values) {
    if (group.length == 1) {
      out.add(group.single);
      continue;
    }

    final withIp = group.where(_hasConnectableIp).toList();
    if (withIp.length >= 2) {
      // Same friendly name on multiple machines (different IPs).
      out.addAll(group);
      continue;
    }
    if (withIp.length == 1) {
      var canonical = withIp.single;
      for (final d in group) {
        if (identical(d, canonical)) {
          continue;
        }
        canonical = canonical.merge(d);
      }
      out.add(canonical);
      continue;
    }

    // Only signaling / no IP: same visible device, different session tokens.
    var acc = group.first;
    for (final d in group.skip(1)) {
      acc = acc.merge(d);
    }
    out.add(acc);
  }
  return out;
}

extension on Device {
  Device merge(Device other) {
    return Device(
      signalingId: signalingId ?? other.signalingId,
      ip: ip ?? other.ip,
      version: version,
      port: port,
      https: https,
      fingerprint: fingerprint,
      alias: alias,
      deviceModel: deviceModel,
      deviceType: deviceType,
      download: download,
      discoveryMethods: {
        ...discoveryMethods,
        ...other.discoveryMethods,
      },
    );
  }
}
