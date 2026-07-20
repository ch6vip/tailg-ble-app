import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/qgj_scan_identity.dart';
import 'package:tailg_ble_app/services/auto_connect_service.dart';

void main() {
  test('QGJ manufacturer data exposes identity MAC and normal boot mode', () {
    final identity = parseQgjManufacturerPayloads([
      [0x00, 0x10, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF],
    ], harmony: false);

    expect(identity.identityMac, 'AABBCCDDEEFF');
    expect(identity.bootMode, 0);
    expect(
      AutoConnectService.matchesQgjIdentity(
        targetMac: 'AA:BB:CC:DD:EE:FF',
        observedMac: identity.identityMac,
        bootMode: identity.bootMode,
        harmony: identity.harmony,
      ),
      isTrue,
    );
  });

  test('QGJ binding/OTA and Harmony advertisements are not auto-connected', () {
    final binding = parseQgjManufacturerPayloads([
      [0x20, 0x00, 1, 2, 3, 4, 5, 6],
    ], harmony: false);
    expect(binding.bootMode, 1);
    expect(
      AutoConnectService.matchesQgjIdentity(
        targetMac: '010203040506',
        observedMac: binding.identityMac,
        bootMode: binding.bootMode,
        harmony: false,
      ),
      isFalse,
    );

    final harmony = parseQgjManufacturerPayloads(const [], harmony: true);
    expect(harmony.identityMac, isNull);
    expect(harmony.harmony, isTrue);
  });
}
