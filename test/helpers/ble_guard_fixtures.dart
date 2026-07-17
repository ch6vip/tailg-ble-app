import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';

const testBleDeviceId = 'bike-1';

class BleGuardFixture {
  BleGuardFixture()
    : manager = ConnectionManager(),
      device = BluetoothDevice(
        remoteId: const DeviceIdentifier(testBleDeviceId),
      );

  final ConnectionManager manager;
  final BluetoothDevice device;
}
