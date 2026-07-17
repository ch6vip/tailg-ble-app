import 'package:flutter_test/flutter_test.dart';

import 'helpers/source_scan.dart';

void main() {
  group('platform BLE permissions', () {
    test('Android manifest declares modern and legacy BLE permissions', () {
      final manifest = readSource('android/app/src/main/AndroidManifest.xml');

      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.BLUETOOTH" '
          'android:maxSdkVersion="30"/>',
        ),
      );
      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" '
          'android:maxSdkVersion="30"/>',
        ),
      );
      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.BLUETOOTH_SCAN" '
          'android:usesPermissionFlags="neverForLocation"/>',
        ),
      );
      expect(
        manifest,
        contains(
          '<uses-permission '
          'android:name="android.permission.BLUETOOTH_CONNECT"/>',
        ),
      );
      expect(
        manifest,
        contains(
          '<uses-permission '
          'android:name="android.permission.ACCESS_FINE_LOCATION"/>',
        ),
      );
      expect(
        manifest,
        contains(
          '<uses-feature android:name="android.hardware.bluetooth_le" '
          'android:required="true"/>',
        ),
      );
    });

    test('iOS Info.plist declares Bluetooth usage descriptions', () {
      final infoPlist = readSource('ios/Runner/Info.plist');

      expect(
        infoPlist,
        contains('<key>NSBluetoothAlwaysUsageDescription</key>'),
      );
      expect(
        infoPlist,
        contains('<key>NSBluetoothPeripheralUsageDescription</key>'),
      );
      expect(
        infoPlist,
        contains('<key>NSLocationWhenInUseUsageDescription</key>'),
      );
    });
  });
}
