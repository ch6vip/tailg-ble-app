import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ble/connection_manager.dart';
import '../main.dart';
import '../models/command_types.dart';
import 'log_service.dart';

/// Official TLV battery page "库仑计" (open SOC self-learning).
///
/// BLE-only feature from `BatteryInfoTlvActivity`:
/// - Query: write FBB2 `D0018A00` after powering the vehicle
/// - Response: starts with `D0010A08`, status bit0 of byte at hex[10..12]
/// - On:  `D0018A020500`
/// - Off: `D0018A020600`
/// - Hidden for lithium `bmsTlvType == 208`
class CoulombMeterService {
  CoulombMeterService._();
  static final CoulombMeterService instance = CoulombMeterService._();

  static const queryFrame = 'D0018A00';
  static const turnOnFrame = 'D0018A020500';
  static const turnOffFrame = 'D0018A020600';
  static const responsePrefix = 'D0010A08';

  final _log = LogService();

  /// Lithium packs (official type "208") cannot use coulomb meter.
  static bool isSupported({
    required int? modelType,
    required String bmsTlvType,
  }) {
    final tlv = bmsTlvType.trim();
    if (tlv == '208') return false;
    // Official shows open-SOC on TLV pages; prefer when tlv is present.
    // Also allow known GPS combo / QGJ when BLE is available.
    if (tlv.isNotEmpty) return true;
    if (modelType == 8 || modelType == 283) return true;
    if (modelType == 3 ||
        modelType == 10 ||
        modelType == 14 ||
        modelType == 401 ||
        modelType == 928 ||
        modelType == 1501 ||
        modelType == 1601 ||
        modelType == 1701) {
      return true;
    }
    return false;
  }

  /// Parse official `setSocVisible` response.
  ///
  /// Returns:
  /// - `true` / `false` when switch state is known
  /// - `null` when vehicle must power on first (show refresh button)
  static bool? parseSocVisible(String rawHex) {
    final hex = rawHex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
    if (hex.length < 12 || !hex.startsWith(responsePrefix)) return null;
    final statusByteHex = hex.substring(10, 12);
    final status = int.tryParse(statusByteHex, radix: 16);
    if (status == null) return null;
    // Official: binary bit0 of status byte == "1" means ON.
    return (status & 0x01) == 0x01;
  }

  Future<bool?> queryStatus({
    ConnectionManager? manager,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final cm = manager ?? connectionManager;
    if (!cm.isProtocolLoggedIn) {
      throw StateError('请先连接车辆蓝牙');
    }
    if (cm.fbb2Char == null) {
      throw StateError('当前连接不支持库仑计通道 (FBB2)');
    }

    // Official powers vehicle before reading SOC status.
    try {
      await cm.sendCommand(CommandCode.powerOn);
    } catch (e) {
      _log.operation(
        '库仑计查询前上电失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
    }

    final completer = Completer<String>();
    late final StreamSubscription<String> sub;
    sub = cm.fbb2Stream.listen((hex) {
      final clean = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
      if (clean.startsWith('D001')) {
        if (!completer.isCompleted) completer.complete(clean);
      }
    });

    try {
      await cm.writeFbb2(queryFrame);
      final response = await completer.future.timeout(timeout);
      final on = parseSocVisible(response);
      _log.operation(
        '库仑计状态',
        detail: 'raw=$response on=${on?.toString() ?? "unknown"}',
      );
      return on;
    } on TimeoutException {
      _log.operation('库仑计查询超时', level: LogLevel.warning);
      return null;
    } finally {
      await sub.cancel();
    }
  }

  Future<bool?> setEnabled(
    bool enabled, {
    ConnectionManager? manager,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final cm = manager ?? connectionManager;
    if (!cm.isProtocolLoggedIn) {
      throw StateError('请先连接车辆蓝牙');
    }
    if (cm.fbb2Char == null) {
      throw StateError('当前连接不支持库仑计通道 (FBB2)');
    }

    try {
      await cm.sendCommand(CommandCode.powerOn);
    } catch (e) {
      _log.operation(
        '库仑计设置前上电失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
    }

    final frame = enabled ? turnOnFrame : turnOffFrame;
    final completer = Completer<String>();
    late final StreamSubscription<String> sub;
    sub = cm.fbb2Stream.listen((hex) {
      final clean = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
      if (clean.startsWith('D001')) {
        if (!completer.isCompleted) completer.complete(clean);
      }
    });

    try {
      await cm.writeFbb2(frame);
      final response = await completer.future.timeout(timeout);
      final on = parseSocVisible(response) ?? enabled;
      _log.operation(
        '库仑计设置',
        detail: 'enabled=$enabled raw=$response result=$on',
      );
      return on;
    } on TimeoutException {
      // Some firmwares ack without a parseable status frame.
      _log.operation(
        '库仑计设置超时，采用目标状态',
        detail: 'enabled=$enabled',
        level: LogLevel.warning,
      );
      return enabled;
    } finally {
      await sub.cancel();
    }
  }
}

@visibleForTesting
bool? parseCoulombSocVisibleForTest(String hex) =>
    CoulombMeterService.parseSocVisible(hex);
