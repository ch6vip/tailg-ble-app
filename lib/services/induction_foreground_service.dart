import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the Android process eligible for BLE work while RSSI induction is on.
///
/// The BLE protocol stays in Dart's existing [ConnectionManager]. The native
/// service supplies the required visible foreground-service notification.
class InductionForegroundService {
  const InductionForegroundService();

  static const _channel = MethodChannel(
    'de.tttq.tailg_ble_app/induction_service',
  );

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get supportsBackgroundRssi => _supported;

  Future<bool> start({String? vehicleLabel}) async {
    if (!_supported) return true;
    try {
      await _channel.invokeMethod<void>('start', {
        'vehicleLabel': vehicleLabel ?? '',
      });
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> stop() async {
    if (!_supported) return true;
    try {
      await _channel.invokeMethod<void>('stop');
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
