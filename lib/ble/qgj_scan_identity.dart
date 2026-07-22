import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class QgjScanIdentity {
  final String? identityMac;
  final int bootMode;
  final bool harmony;

  /// When true, identityMac came from the radio address fallback
  /// (official ScannedDevice.getIdentityMac() does the same).
  final bool fromRadioAddress;

  const QgjScanIdentity({
    required this.identityMac,
    required this.bootMode,
    required this.harmony,
    this.fromRadioAddress = false,
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

/// Official ScannedDevice.getIdentityMac() fallback: when manufacturer data
/// has no identity MAC, use the BLE radio address (without colons, uppercase).
QgjScanIdentity identityWithRadioFallback({
  required QgjScanIdentity parsed,
  required String radioAddress,
}) {
  if (parsed.identityMac != null && parsed.identityMac!.isNotEmpty) {
    return parsed;
  }
  final compact = radioAddress
      .replaceAll(RegExp(r'[^0-9a-fA-F]'), '')
      .toUpperCase();
  if (compact.isEmpty) return parsed;
  return QgjScanIdentity(
    identityMac: compact,
    bootMode: parsed.bootMode,
    harmony: parsed.harmony,
    fromRadioAddress: true,
  );
}

String _compactMac(List<int> bytes) => bytes
    .map((byte) => (byte & 0xFF).toRadixString(16).padLeft(2, '0'))
    .join()
    .toUpperCase();
