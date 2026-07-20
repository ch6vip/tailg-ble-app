import 'dart:convert';

import 'control_command_policy.dart';

/// Parsed subset of official `MqttPayloadBean` used for control UI refresh.
class OfficialMqttStatusPayload {
  final String? acc;
  final String? defenceStatus;
  final String? imei;
  final int? muteStatus;
  final int? accErrorStatus;
  final int? defenceErrorStatus;
  final int? bikeSetSourceValue;

  const OfficialMqttStatusPayload({
    this.acc,
    this.defenceStatus,
    this.imei,
    this.muteStatus,
    this.accErrorStatus,
    this.defenceErrorStatus,
    this.bikeSetSourceValue,
  });

  bool get isMoving => accErrorStatus == 4 || defenceErrorStatus == 2;
  bool get isKeyStarted => accErrorStatus == 8;
  bool get isNotPoweredOff {
    if (defenceErrorStatus != 3) return false;
    return !const {0, 2, 5, 6}.contains(bikeSetSourceValue);
  }

  int? get accInt {
    final text = acc?.trim();
    if (text == null || text.isEmpty) return null;
    return int.tryParse(text);
  }

  int? get defenceStatusInt {
    final text = defenceStatus?.trim();
    if (text == null || text.isEmpty) return null;
    return int.tryParse(text);
  }

  bool get hasVehicleState => accInt != null || defenceStatusInt != null;

  /// Parse official status JSON. Returns null when payload is not a JSON object.
  static OfficialMqttStatusPayload? tryParse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      return OfficialMqttStatusPayload(
        acc: _asString(map['ACC'] ?? map['acc']),
        defenceStatus: _asString(
          map['defenceStatus'] ?? map['DefenseStatus'] ?? map['defenseStatus'],
        ),
        imei: _asString(map['imei']),
        muteStatus: _asInt(map['muteStatus']),
        accErrorStatus: _asInt(map['accErrorStatus']),
        defenceErrorStatus: _asInt(map['defenceErrorStatus']),
        bikeSetSourceValue: _asInt(map['bikeSetSourceValue']),
      );
    } on Object {
      // Malformed status payload — treat as no update.
      return null;
    }
  }

  /// Apply official ControlFragment-style confirmation against pending command.
  ///
  /// Returns true when the payload confirms [pendingCommandApiName], or when no
  /// pending command is set but vehicle state fields are present.
  bool confirmsCommand(String? pendingCommandApiName) {
    final pending = pendingCommandApiName?.trim() ?? '';
    if (pending.isEmpty) return hasVehicleState;

    return switch (pending) {
      'start' => acc == '1',
      'stop' => acc == '0',
      'lock' => defenceStatus == '1',
      'unlock' => defenceStatus == '0',
      // find / openCushion: official still refreshes ACC/defence opportunistically
      _ => hasVehicleState,
    };
  }

  String? controlErrorMessage(String? pendingCommandApiName) {
    if (isMoving) return ControlCommandPolicy.vehicleMovingDisabledReason;
    if (isKeyStarted) return ControlCommandPolicy.keyStartedDisabledReason;
    if (isNotPoweredOff) {
      return ControlCommandPolicy.notPoweredOffDisabledReason;
    }
    if (const {5, 6, 7, 20}.contains(accErrorStatus)) {
      return switch (pendingCommandApiName) {
        'start' => '车辆当前状态不支持启动',
        'stop' => '车辆当前状态不支持熄火',
        _ => '车辆当前状态不支持此操作',
      };
    }
    return null;
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
