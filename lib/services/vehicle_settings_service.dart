import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart';
import '../ble/qgj_protocol.dart';
import 'log_service.dart';

class VehicleSettingsException implements Exception {
  final String message;
  const VehicleSettingsException(this.message);

  @override
  String toString() => message;
}

class VehicleSettingsSnapshot {
  final bool? lightSensor;
  final bool? startSound;
  final bool? stopSound;
  final bool? lockSound;
  final bool? unlockSound;
  final bool? speedSound;
  final int? sensitivityValue;

  const VehicleSettingsSnapshot({
    this.lightSensor,
    this.startSound,
    this.stopSound,
    this.lockSound,
    this.unlockSound,
    this.speedSound,
    this.sensitivityValue,
  });

  bool get hasLightState => lightSensor != null;
  bool get hasSoundState =>
      startSound != null ||
      stopSound != null ||
      lockSound != null ||
      unlockSound != null ||
      speedSound != null;
  bool get hasSensitivityState => sensitivityValue != null;
  bool get hasAnyState => hasLightState || hasSoundState || hasSensitivityState;

  VehicleSettingsSnapshot merge(VehicleSettingsSnapshot other) {
    return VehicleSettingsSnapshot(
      lightSensor: other.lightSensor ?? lightSensor,
      startSound: other.startSound ?? startSound,
      stopSound: other.stopSound ?? stopSound,
      lockSound: other.lockSound ?? lockSound,
      unlockSound: other.unlockSound ?? unlockSound,
      speedSound: other.speedSound ?? speedSound,
      sensitivityValue: other.sensitivityValue ?? sensitivityValue,
    );
  }

  static VehicleSettingsSnapshot? parse(List<int> data) {
    return null;
  }

  static VehicleSettingsSnapshot fromLightSensorPayload(List<int> payload) {
    return VehicleSettingsSnapshot(lightSensor: _readSwitch(payload));
  }

  static VehicleSettingsSnapshot fromSensitivityPayload(List<int> payload) {
    if (payload.isEmpty) return const VehicleSettingsSnapshot();
    return VehicleSettingsSnapshot(
      sensitivityValue: normalizeSensitivityValue(payload.first),
    );
  }

  static VehicleSettingsSnapshot fromSoundPayload(List<int> payload) {
    final values = parseSoundAdjustPayload(payload);
    return VehicleSettingsSnapshot(
      lockSound: _soundEnabled(values[QgjSoundIndexes.lock]),
      unlockSound: _soundEnabled(values[QgjSoundIndexes.unlock]),
      startSound: _soundEnabled(values[QgjSoundIndexes.start]),
      stopSound: _soundEnabled(values[QgjSoundIndexes.stop]),
      speedSound: _soundEnabled(values[QgjSoundIndexes.speed]),
    );
  }

  static bool? _readSwitch(List<int> payload) {
    if (payload.isEmpty) return null;
    return payload.first == 1;
  }

  static bool? _soundEnabled(int? volume) {
    if (volume == null) return null;
    return volume == 100;
  }
}

class VehicleAdvancedSettingsSnapshot {
  final bool? autoLockEnabled;
  final int? autoLockTimeSeconds;
  final int? powerOnAutoLockTimeSeconds;
  final bool? proximityEnabled;
  final int? proximityDistance;
  final bool? handlebarLockEnabled;
  final bool? postureDetectionEnabled;
  final int? hidMode;
  final bool? safeLockEnabled;
  final bool? kickstandEnabled;
  final bool? seatSensorEnabled;

  const VehicleAdvancedSettingsSnapshot({
    this.autoLockEnabled,
    this.autoLockTimeSeconds,
    this.powerOnAutoLockTimeSeconds,
    this.proximityEnabled,
    this.proximityDistance,
    this.handlebarLockEnabled,
    this.postureDetectionEnabled,
    this.hidMode,
    this.safeLockEnabled,
    this.kickstandEnabled,
    this.seatSensorEnabled,
  });

  bool get hasAnyState =>
      autoLockEnabled != null ||
      autoLockTimeSeconds != null ||
      powerOnAutoLockTimeSeconds != null ||
      proximityEnabled != null ||
      proximityDistance != null ||
      handlebarLockEnabled != null ||
      postureDetectionEnabled != null ||
      hidMode != null ||
      safeLockEnabled != null ||
      kickstandEnabled != null ||
      seatSensorEnabled != null;

  VehicleAdvancedSettingsSnapshot merge(VehicleAdvancedSettingsSnapshot other) {
    return VehicleAdvancedSettingsSnapshot(
      autoLockEnabled: other.autoLockEnabled ?? autoLockEnabled,
      autoLockTimeSeconds: other.autoLockTimeSeconds ?? autoLockTimeSeconds,
      powerOnAutoLockTimeSeconds:
          other.powerOnAutoLockTimeSeconds ?? powerOnAutoLockTimeSeconds,
      proximityEnabled: other.proximityEnabled ?? proximityEnabled,
      proximityDistance: other.proximityDistance ?? proximityDistance,
      handlebarLockEnabled: other.handlebarLockEnabled ?? handlebarLockEnabled,
      postureDetectionEnabled:
          other.postureDetectionEnabled ?? postureDetectionEnabled,
      hidMode: other.hidMode ?? hidMode,
      safeLockEnabled: other.safeLockEnabled ?? safeLockEnabled,
      kickstandEnabled: other.kickstandEnabled ?? kickstandEnabled,
      seatSensorEnabled: other.seatSensorEnabled ?? seatSensorEnabled,
    );
  }

  static VehicleAdvancedSettingsSnapshot fromAutoLockPayload(
    List<int> payload,
  ) {
    final value = _readUInt16(payload);
    return VehicleAdvancedSettingsSnapshot(
      autoLockEnabled: value == null ? null : value > 0,
      autoLockTimeSeconds: value,
    );
  }

  static VehicleAdvancedSettingsSnapshot fromPowerOnAutoLockPayload(
    List<int> payload,
  ) {
    return VehicleAdvancedSettingsSnapshot(
      powerOnAutoLockTimeSeconds: _readUInt16(payload),
    );
  }

  static VehicleAdvancedSettingsSnapshot fromProximityStatusPayload(
    List<int> payload,
  ) {
    return VehicleAdvancedSettingsSnapshot(
      proximityEnabled: _readSwitch(payload),
    );
  }

  static VehicleAdvancedSettingsSnapshot fromProximityDistancePayload(
    List<int> payload,
  ) {
    return VehicleAdvancedSettingsSnapshot(
      proximityDistance: _readUInt8(payload),
    );
  }

  static VehicleAdvancedSettingsSnapshot fromHandlebarLockPayload(
    List<int> payload,
  ) {
    return VehicleAdvancedSettingsSnapshot(
      handlebarLockEnabled: _readSwitch(payload),
    );
  }

  static VehicleAdvancedSettingsSnapshot fromPostureDetectionPayload(
    List<int> payload,
  ) {
    return VehicleAdvancedSettingsSnapshot(
      postureDetectionEnabled: _readSwitch(payload),
    );
  }

  static VehicleAdvancedSettingsSnapshot fromHidPayload(List<int> payload) {
    return VehicleAdvancedSettingsSnapshot(hidMode: _readUInt8(payload));
  }

  static VehicleAdvancedSettingsSnapshot fromSafeLockPayload(
    List<int> payload,
  ) {
    return VehicleAdvancedSettingsSnapshot(
      safeLockEnabled: _readSwitch(payload),
    );
  }

  static VehicleAdvancedSettingsSnapshot fromKickstandPayload(
    List<int> payload,
  ) {
    return VehicleAdvancedSettingsSnapshot(
      kickstandEnabled: _readSwitch(payload),
    );
  }

  static VehicleAdvancedSettingsSnapshot fromSeatSensorPayload(
    List<int> payload,
  ) {
    return VehicleAdvancedSettingsSnapshot(
      seatSensorEnabled: _readSwitch(payload),
    );
  }

  static int? _readUInt8(List<int> payload) {
    if (payload.isEmpty) return null;
    return payload.first & 0xFF;
  }

  static int? _readUInt16(List<int> payload) {
    if (payload.length < 2) return null;
    return ((payload[0] & 0xFF) << 8) | (payload[1] & 0xFF);
  }

  static bool? _readSwitch(List<int> payload) {
    final value = _readUInt8(payload);
    return switch (value) {
      0 => false,
      1 => true,
      _ => null,
    };
  }
}

class QgjSoundAdjust {
  final int index;
  final int volume;

  const QgjSoundAdjust(this.index, this.volume);
}

List<int> buildSoundAdjustGetPayload([List<int> indexes = const []]) {
  final targetIndexes = indexes.isEmpty ? const [QgjSoundIndexes.all] : indexes;
  return targetIndexes.map((index) => index & 0xFF).toList(growable: false);
}

List<int> buildSoundAdjustSetPayload(List<QgjSoundAdjust> items) {
  final payload = <int>[];
  for (final item in items) {
    payload
      ..add(item.index & 0xFF)
      ..add(item.volume.clamp(0, 100).toInt());
  }
  return payload;
}

Map<int, int> parseSoundAdjustPayload(List<int> payload) {
  final values = <int, int>{};
  for (var i = 0; i + 1 < payload.length; i += 2) {
    values[payload[i]] = payload[i + 1];
  }
  return values;
}

int sensitivityLevelToValue(int level) {
  return switch (level) {
    <= 1 => 0,
    2 => 15,
    3 => 50,
    _ => 85,
  };
}

int sensitivityValueToLevel(int value) {
  if (value == 0) return 1;
  if (value <= 30) return 2;
  if (value <= 70) return 3;
  return 4;
}

int normalizeSensitivityValue(int value) {
  return sensitivityLevelToValue(sensitivityValueToLevel(value));
}

class VehicleSettingsService {
  final ble.ConnectionManager connectionManager;
  final LogService _log;

  VehicleSettingsService({
    required this.connectionManager,
    LogService? logService,
  }) : _log = logService ?? LogService();

  Future<VehicleSettingsSnapshot?> refresh() async {
    _requireReady();
    VehicleSettingsSnapshot? snapshot;

    final light = await _send(QgjCommandIds.lightSensorGet);
    if (light != null && light.success) {
      snapshot = (snapshot ?? const VehicleSettingsSnapshot()).merge(
        VehicleSettingsSnapshot.fromLightSensorPayload(light.payload),
      );
    }

    final sound = await _send(
      QgjCommandIds.soundAdjustGet,
      buildSoundAdjustGetPayload(),
    );
    if (sound != null && sound.success) {
      snapshot = (snapshot ?? const VehicleSettingsSnapshot()).merge(
        VehicleSettingsSnapshot.fromSoundPayload(sound.payload),
      );
    }

    final sensitivity = await _send(QgjCommandIds.vibrateSensitivityGet);
    if (sensitivity != null && sensitivity.success) {
      snapshot = (snapshot ?? const VehicleSettingsSnapshot()).merge(
        VehicleSettingsSnapshot.fromSensitivityPayload(sensitivity.payload),
      );
    }

    return snapshot?.hasAnyState == true ? snapshot : null;
  }

  Future<VehicleAdvancedSettingsSnapshot?> refreshAdvancedReadOnly() async {
    _requireReady();
    VehicleAdvancedSettingsSnapshot? snapshot;

    Future<void> read(
      int cmdId,
      VehicleAdvancedSettingsSnapshot Function(List<int> payload) parse, [
      List<int> payload = const [],
    ]) async {
      final response = await _send(cmdId, payload);
      if (response != null && response.success) {
        snapshot = (snapshot ?? const VehicleAdvancedSettingsSnapshot()).merge(
          parse(response.payload),
        );
      }
    }

    await read(
      QgjCommandIds.autoLockTimeGet,
      VehicleAdvancedSettingsSnapshot.fromAutoLockPayload,
    );
    await read(
      QgjCommandIds.powerOnAutoLockTimeGet,
      VehicleAdvancedSettingsSnapshot.fromPowerOnAutoLockPayload,
    );
    await read(
      QgjCommandIds.proximityStatusGet,
      VehicleAdvancedSettingsSnapshot.fromProximityStatusPayload,
    );
    await read(
      QgjCommandIds.proximityDistanceGet,
      VehicleAdvancedSettingsSnapshot.fromProximityDistancePayload,
    );
    await read(
      QgjCommandIds.handlebarLockGet,
      VehicleAdvancedSettingsSnapshot.fromHandlebarLockPayload,
    );
    await read(
      QgjCommandIds.postureDetectionGet,
      VehicleAdvancedSettingsSnapshot.fromPostureDetectionPayload,
    );
    await read(
      QgjCommandIds.hidStatusGet,
      VehicleAdvancedSettingsSnapshot.fromHidPayload,
    );
    await read(
      QgjCommandIds.safeLockGet,
      VehicleAdvancedSettingsSnapshot.fromSafeLockPayload,
    );
    await read(
      QgjCommandIds.kickstandGet,
      VehicleAdvancedSettingsSnapshot.fromKickstandPayload,
    );
    await read(
      QgjCommandIds.seatSensorGet,
      VehicleAdvancedSettingsSnapshot.fromSeatSensorPayload,
    );

    return snapshot?.hasAnyState == true ? snapshot : null;
  }

  Future<VehicleSettingsSnapshot?> writeLightSensor(bool enabled) async {
    _requireReady();
    final response = await _send(QgjCommandIds.lightSensorSet, [
      enabled ? 1 : 0,
    ]);
    if (!_isCommonOk(response)) {
      throw const VehicleSettingsException('光感开关设置失败');
    }
    return refresh();
  }

  Future<VehicleSettingsSnapshot?> writeSound({
    bool? startSound,
    bool? stopSound,
    bool? lockSound,
    bool? unlockSound,
    bool? speedSound,
  }) async {
    _requireReady();
    final items = <QgjSoundAdjust>[
      if (lockSound != null)
        QgjSoundAdjust(QgjSoundIndexes.lock, _soundVolume(lockSound)),
      if (unlockSound != null)
        QgjSoundAdjust(QgjSoundIndexes.unlock, _soundVolume(unlockSound)),
      if (startSound != null)
        QgjSoundAdjust(QgjSoundIndexes.start, _soundVolume(startSound)),
      if (stopSound != null)
        QgjSoundAdjust(QgjSoundIndexes.stop, _soundVolume(stopSound)),
      if (speedSound != null)
        QgjSoundAdjust(QgjSoundIndexes.speed, _soundVolume(speedSound)),
    ];
    if (items.isEmpty) return refresh();

    final response = await _send(
      QgjCommandIds.soundAdjustSet,
      buildSoundAdjustSetPayload(items),
    );
    if (!_isCommonOk(response)) {
      throw const VehicleSettingsException('声音设置失败');
    }
    return refresh();
  }

  Future<VehicleSettingsSnapshot?> writeSensitivityLevel(int level) async {
    _requireReady();
    final value = sensitivityLevelToValue(level);
    final response = await _send(QgjCommandIds.vibrateSensitivitySet, [value]);
    if (!_isCommonOk(response)) {
      throw const VehicleSettingsException('震动灵敏度设置失败');
    }
    return refresh();
  }

  void _requireReady() {
    if (connectionManager.state != ble.ConnectionState.ready) {
      throw const VehicleSettingsException('未连接车辆');
    }
    if (connectionManager.protocol != ble.ProtocolType.qgj &&
        connectionManager.lastKnownProtocol != ble.ProtocolType.qgj) {
      throw const VehicleSettingsException('当前车辆不是 QGJ 协议');
    }
  }

  Future<QgjResponse?> _send(int cmdId, [List<int> payload = const []]) async {
    _log.operation(
      'QGJ 设置命令',
      detail:
          'cmd=0x${cmdId.toRadixString(16)}, payload=${payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      level: LogLevel.debug,
    );
    try {
      return await connectionManager.sendQgjCommand(cmdId, payload);
    } catch (e) {
      _log.operation('QGJ 设置命令失败', detail: e.toString(), level: LogLevel.debug);
      return null;
    }
  }

  static int _soundVolume(bool enabled) => enabled ? 100 : 0;

  static bool _isCommonOk(QgjResponse? response) {
    if (response == null || !response.success) return false;
    return response.payload.isEmpty || response.payload.first == 0;
  }
}
