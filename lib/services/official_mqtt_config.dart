import 'dart:convert';
import 'dart:math';

import '../models/official_vehicle.dart';

/// Official MQTT endpoints and topic/payload helpers from decompiled
/// `TailgHost` + `TailgMqttUtil` + `ControlFragment.mqttPublish`.
class OfficialMqttConfig {
  /// Production KKS/YJ broker (`TailgHost.MQTT_HOST_URL_LINE_KKS_YJ`).
  static const kksYjHostUri = 'tcp://www.tailgdd.com:1883';

  /// Production C18/QGJ/GPS broker (`TailgHost.MQTT_HOST_URL_LINE_C18`).
  static const c18HostUri = 'ssl://www.tailgdd.com:6668';

  /// Official hardcoded MQTT credentials (`MqttUtil.userName/passWord`).
  static const username = 'client_app';
  static const password = '123456';

  /// Official ControlFragment uses qos = 0.
  static const qos = 0;

  static const connectTimeout = Duration(seconds: 10);
  static const keepAliveSeconds = 60;

  /// Whether this model uses the plain TCP KKS/YJ broker (no SSL).
  static bool usesKksYjBroker(int? modelType) =>
      modelType == 1 || modelType == 2;

  /// Resolve broker URI for [vehicle].
  ///
  /// Official: KKS/YJ always use fixed tcp host; others prefer vehicle
  /// `mqHost:mqPort` when present, else C18 ssl host.
  static String brokerUriFor(OfficialVehicle vehicle) {
    if (usesKksYjBroker(vehicle.modelType)) {
      return kksYjHostUri;
    }
    final host = vehicle.mqHost.trim();
    final port = vehicle.mqPort.trim();
    if (host.isNotEmpty && port.isNotEmpty) {
      // Official builds "ssl://{mqHost}:{mqPort}" for non-KKS/YJ.
      return 'ssl://$host:$port';
    }
    return c18HostUri;
  }

  /// Official clientId:
  /// - KKS/YJ: `app_{imei}{random3}`
  /// - others: `app_{imeiGpsOrImei}_{uid}_android_{random3}`
  static String clientIdFor({
    required OfficialVehicle vehicle,
    required String userId,
    Random? random,
  }) {
    final rng = random ?? Random();
    final suffix = List.generate(3, (_) => rng.nextInt(10)).join();
    if (usesKksYjBroker(vehicle.modelType)) {
      final imei = _kksImei(vehicle);
      return 'app_$imei$suffix';
    }
    final imei = vehicle.commandImei.isNotEmpty
        ? vehicle.commandImei
        : vehicle.imei;
    final uid = userId.trim().isEmpty ? '0' : userId.trim();
    return 'app_${imei}_${uid}_android_$suffix';
  }

  /// Publish topic matching ControlFragment.mqttPublish.
  static String publishTopic({
    required OfficialVehicle vehicle,
    required String imei,
  }) {
    if (usesKksYjBroker(vehicle.modelType)) {
      final name = vehicle.modelType == 2 ? 'yunjia' : 'kks';
      return 'app-update-$name/$imei';
    }
    return 'APP_S/CMD/$imei';
  }

  /// Status subscribe topics (subset used after official connect).
  static List<String> subscribeTopics({
    required OfficialVehicle vehicle,
    required String imei,
  }) {
    if (usesKksYjBroker(vehicle.modelType)) {
      final name = vehicle.modelType == 2 ? 'yunjia' : 'kks';
      return ['$name-get-$imei'];
    }
    return [
      'S_APP/STATUS/$imei',
      'S_APP/OTA/$imei',
      'S_APP/CHARGER/$imei',
      'S_APP/CHECK/$imei',
    ];
  }

  /// Official `MqttCmdBean` JSON: `{"imei":"...","command":"lock"}`.
  static String commandPayload({
    required String imei,
    required String command,
  }) {
    return jsonEncode({'imei': imei, 'command': command});
  }

  /// IMEI used in topic/payload for this vehicle (official `this.imei`).
  static String commandImei(OfficialVehicle vehicle) {
    if (usesKksYjBroker(vehicle.modelType)) {
      return _kksImei(vehicle);
    }
    // QGJ/C18/GPS paths typically bind MQTT on imeiGps when present.
    if (vehicle.imeiGps.isNotEmpty) return vehicle.imeiGps;
    return vehicle.commandImei.isNotEmpty ? vehicle.commandImei : vehicle.imei;
  }

  static String _kksImei(OfficialVehicle vehicle) {
    if (vehicle.imei.isNotEmpty) return vehicle.imei;
    return vehicle.commandImei;
  }

  /// Parse `tcp://host:port` / `ssl://host:port` into parts.
  static ({bool secure, String host, int port}) parseBrokerUri(String uri) {
    final raw = uri.trim();
    final secure = raw.startsWith('ssl://') || raw.startsWith('wss://');
    final withoutScheme = raw
        .replaceFirst(RegExp(r'^(tcp|ssl|ws|wss)://'), '')
        .trim();
    final parts = withoutScheme.split(':');
    final host = parts.first;
    final port = parts.length > 1
        ? int.tryParse(parts[1]) ?? (secure ? 8883 : 1883)
        : (secure ? 8883 : 1883);
    return (secure: secure, host: host, port: port);
  }
}
