import 'dart:async';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../models/command_types.dart';
import '../models/official_vehicle.dart';
import 'log_service.dart';
import 'official_cloud_service.dart';
import 'official_mqtt_config.dart';

/// Official MQTT remote control (ControlFragment.mqttPublish path).
///
/// Connects with the same credentials/topics as the decompiled app and publishes
/// `MqttCmdBean` JSON payloads. HTTP `app/device/cmd/*` remains available as a
/// fallback in [sendCommandPreferMqtt].
class OfficialMqttService {
  static final OfficialMqttService _instance = OfficialMqttService._();
  factory OfficialMqttService() => _instance;
  OfficialMqttService._();

  final _log = LogService();
  MqttServerClient? _client;
  String? _connectedClientId;
  String? _connectedBroker;
  String? _connectedImei;
  bool _disposed = false;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> resetForTest() async {
    await disconnect();
    _disposed = false;
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
  }

  Future<void> disconnect() async {
    final client = _client;
    _client = null;
    _connectedClientId = null;
    _connectedBroker = null;
    _connectedImei = null;
    if (client == null) return;
    try {
      client.disconnect();
    } catch (_) {}
  }

  /// Ensure a live MQTT session for [vehicle] (reconnect when broker/imei change).
  Future<void> ensureConnected({
    required OfficialVehicle vehicle,
    required String userId,
  }) async {
    if (_disposed) {
      throw const OfficialCloudApiException('MQTT 服务已释放');
    }
    final imei = OfficialMqttConfig.commandImei(vehicle);
    if (imei.isEmpty) {
      throw const OfficialCloudApiException('当前车辆缺少 IMEI，无法 MQTT 控车');
    }
    final broker = OfficialMqttConfig.brokerUriFor(vehicle);
    if (isConnected &&
        _connectedBroker == broker &&
        _connectedImei == imei &&
        (_connectedClientId?.contains(imei) ?? false)) {
      return;
    }

    await disconnect();

    final parsed = OfficialMqttConfig.parseBrokerUri(broker);
    final clientId = OfficialMqttConfig.clientIdFor(
      vehicle: vehicle,
      userId: userId,
    );
    final client = MqttServerClient.withPort(
      parsed.host,
      clientId,
      parsed.port,
    );
    client.logging(on: false);
    client.keepAlivePeriod = OfficialMqttConfig.keepAliveSeconds;
    client.connectTimeoutPeriod =
        OfficialMqttConfig.connectTimeout.inMilliseconds;
    client.autoReconnect = false;
    client.resubscribeOnAutoReconnect = false;
    client.setProtocolV311();
    client.secure = parsed.secure;
    if (parsed.secure) {
      // Official MqttUtil installs a trust-all miTM for non-KKS/YJ SSL brokers.
      client.onBadCertificate = (_) => true;
      client.securityContext = SecurityContext.defaultContext;
    }

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(
          OfficialMqttConfig.username,
          OfficialMqttConfig.password,
        )
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
    client.connectionMessage = connMess;

    _log.operation(
      '官方 MQTT 连接中',
      detail: 'broker=$broker clientId=$clientId',
    );

    try {
      final status = await client.connect(
        OfficialMqttConfig.username,
        OfficialMqttConfig.password,
      );
      if (status?.state != MqttConnectionState.connected) {
        client.disconnect();
        throw OfficialCloudApiException(
          '官方 MQTT 连接失败: ${status?.state.name ?? 'unknown'}',
        );
      }
    } on NoConnectionException catch (e) {
      throw OfficialCloudApiException('官方 MQTT 连接失败: $e');
    } on SocketException catch (e) {
      throw OfficialCloudApiException('官方 MQTT 网络失败: $e');
    }

    // Subscribe to status topics like official initMqtt success path.
    for (final topic in OfficialMqttConfig.subscribeTopics(
      vehicle: vehicle,
      imei: imei,
    )) {
      client.subscribe(topic, MqttQos.atMostOnce);
    }

    _client = client;
    _connectedClientId = clientId;
    _connectedBroker = broker;
    _connectedImei = imei;
    _log.operation('官方 MQTT 已连接', detail: clientId);
  }

  /// Publish one official control command over MQTT.
  Future<void> publishCommand({
    required OfficialVehicle vehicle,
    required String userId,
    required String commandApiName,
  }) async {
    await ensureConnected(vehicle: vehicle, userId: userId);
    final client = _client;
    if (client == null || !isConnected) {
      throw const OfficialCloudApiException('官方 MQTT 未连接');
    }
    final imei = OfficialMqttConfig.commandImei(vehicle);
    final topic = OfficialMqttConfig.publishTopic(
      vehicle: vehicle,
      imei: imei,
    );
    final payload = OfficialMqttConfig.commandPayload(
      imei: imei,
      command: commandApiName,
    );

    final builder = MqttClientPayloadBuilder()..addString(payload);
    client.publishMessage(
      topic,
      MqttQos.values[OfficialMqttConfig.qos.clamp(0, 2)],
      builder.payload!,
      retain: false,
    );
    _log.operation(
      '官方 MQTT 已发令: $commandApiName',
      detail: 'topic=$topic payload=$payload',
    );
  }

  /// Prefer MQTT (official remote path); fall back to HTTP cmd API.
  Future<String> sendCommandPreferMqtt({
    required CommandCode command,
    required OfficialCloudService cloud,
  }) async {
    final api = OfficialCloudCommand.fromCommandCode(command);
    if (api == null) {
      throw OfficialCloudApiException('官方云端不支持${command.label}');
    }
    final vehicle = cloud.state.selectedVehicle;
    if (vehicle == null || !cloud.state.signedIn) {
      throw const OfficialCloudApiException(
        OfficialCloudMessages.signInAndSelectVehicleRequired,
      );
    }

    try {
      await publishCommand(
        vehicle: vehicle,
        userId: cloud.state.userId,
        commandApiName: api.apiName,
      );
      // Official also refreshes car state after commands; reuse HTTP refresh.
      unawaited(
        Future(() async {
          try {
            await cloud.refreshVehicles(silent: true, force: true);
          } catch (_) {}
        }),
      );
      return 'success';
    } catch (e) {
      _log.operation(
        '官方 MQTT 发令失败，回退 HTTP',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      return cloud.sendCommand(command);
    }
  }
}
