import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;

import '../ble/connection_manager.dart' as ble;
import 'log_service.dart';

class VehicleSettingsException implements Exception {
  final String message;
  const VehicleSettingsException(this.message);

  @override
  String toString() => message;
}

class VehicleSettingsSnapshot {
  final bool? headlight;
  final bool? turnSignal;
  final bool? startupSound;
  final bool? lockSound;
  final bool? unlockSound;
  final bool? powerOnSound;
  final int? buzzerVolume;

  const VehicleSettingsSnapshot({
    this.headlight,
    this.turnSignal,
    this.startupSound,
    this.lockSound,
    this.unlockSound,
    this.powerOnSound,
    this.buzzerVolume,
  });

  bool get hasLightState => headlight != null || turnSignal != null;
  bool get hasSoundState =>
      startupSound != null ||
      lockSound != null ||
      unlockSound != null ||
      powerOnSound != null ||
      buzzerVolume != null;

  static VehicleSettingsSnapshot? parse(List<int> data) {
    if (data.length >= 11 && data[0] == 0x85) {
      return VehicleSettingsSnapshot(
        powerOnSound: data[5] != 0,
        startupSound: data[6] != 0,
        unlockSound: data[7] != 0,
        lockSound: data[8] != 0,
        buzzerVolume: data[10].clamp(0, 5),
      );
    }

    return null;
  }
}

class VehicleSettingsService {
  final ble.ConnectionManager connectionManager;
  final LogService _log;

  VehicleSettingsService({
    required this.connectionManager,
    LogService? logService,
  }) : _log = logService ?? LogService();

  Future<VehicleSettingsSnapshot?> refresh() async {
    final char = _requireFcc1();
    return connectionManager.runGattOperation(() => _readBackState(char));
  }

  Future<VehicleSettingsSnapshot?> writeLight({
    required bool headlight,
    required bool turnSignal,
  }) {
    throw const VehicleSettingsException('灯光设置尚未按官方 QGJ 协议实现，已禁用写入');
  }

  Future<VehicleSettingsSnapshot?> writeSound({
    required bool powerOnSound,
    required bool startupSound,
    required bool unlockSound,
    required bool lockSound,
    required int buzzerVolume,
  }) {
    throw const VehicleSettingsException('声音设置尚未按官方 QGJ 协议实现，已禁用写入');
  }

  Future<VehicleSettingsSnapshot?> writeSensitivity(int level) {
    throw const VehicleSettingsException('震动灵敏度尚未按官方 QGJ 协议实现，已禁用写入');
  }

  BluetoothCharacteristic _requireFcc1() {
    if (connectionManager.state != ble.ConnectionState.ready) {
      throw const VehicleSettingsException('未连接车辆');
    }
    final device = connectionManager.device;
    if (device == null) {
      throw const VehicleSettingsException('未连接车辆');
    }
    final cachedFcc1 = connectionManager.fcc1Char;
    if (cachedFcc1 != null) return cachedFcc1;

    for (final service in device.servicesList) {
      if (service.serviceUuid.toString().contains('fcc0')) {
        for (final char in service.characteristics) {
          if (char.characteristicUuid.toString().contains('fcc1')) {
            return char;
          }
        }
      }
    }
    throw const VehicleSettingsException('fcc1 特征未找到');
  }

  Future<VehicleSettingsSnapshot?> _readBackState(
    BluetoothCharacteristic char,
  ) async {
    try {
      final response = await char.read();
      if (response.isEmpty) return null;
      _log.operation(
        'fcc1 读回',
        detail: response
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' '),
      );
      return VehicleSettingsSnapshot.parse(List<int>.from(response));
    } catch (e) {
      _log.operation('fcc1 读取失败', detail: e.toString(), level: LogLevel.debug);
      return null;
    }
  }
}
