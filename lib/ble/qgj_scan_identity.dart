import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class QgjScanIdentity {
  final String? identityMac;
  final int bootMode;
  final bool harmony;

  const QgjScanIdentity({
    required this.identityMac,
    required this.bootMode,
    required this.harmony,
  });
}

/// Mirrors the official ScannedDevice manufacturer decoder for ECU devices.
/// FBP manufacturer values intentionally exclude the two-byte company id.
QgjScanIdentity parseQgjScanIdentity(AdvertisementData advertisement) {
  final isHarmony = advertisement.serviceData.keys.any(
    (uuid) => uuid.toString().toLowerCase().contains('fdee'),
  );
  return parseQgjManufacturerPayloads(
    advertisement.manufacturerData.values,
    harmony: isHarmony,
  );
}

QgjScanIdentity parseQgjManufacturerPayloads(
  Iterable<List<int>> payloads, {
  required bool harmony,
}) {
  if (harmony) {
    // The official app obtains Harmony's systemId from its SDK connection
    // view-model. A plain Flutter scan cannot reproduce that value safely.
    return const QgjScanIdentity(identityMac: null, bootMode: 0, harmony: true);
  }

  for (final data in payloads) {
    if (data.length == 8) {
      final bootMode = (data[0] >> 5) & 0x03;
      return QgjScanIdentity(
        identityMac: _compactMac(data.sublist(2, 8)),
        bootMode: bootMode,
        harmony: false,
      );
    }
    if (data.length == 6) {
      return QgjScanIdentity(
        identityMac: _compactMac(data),
        bootMode: 0,
        harmony: false,
      );
    }
  }
  return const QgjScanIdentity(identityMac: null, bootMode: 0, harmony: false);
}

String _compactMac(List<int> bytes) => bytes
    .map((byte) => (byte & 0xFF).toRadixString(16).padLeft(2, '0'))
    .join()
    .toUpperCase();
