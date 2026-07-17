import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../models/command_types.dart';
import '../models/official_vehicle.dart';
import 'log_service.dart';
import 'official_cloud_service.dart';
import 'official_mqtt_config.dart';
import 'official_mqtt_payload.dart';

/// Observable MQTT link state for control UI.
enum OfficialMqttLinkState {
  disconnected,
  connecting,
  connected,
}

/// Official MQTT remote control (ControlFragment.mqttPublish path).
///
/// Connects with the same credentials/topics as the decompiled app, publishes
/// `MqttCmdBean` JSON payloads, and applies status replies to
/// [OfficialCloudService.applyMqttVehicleStatus].
class OfficialMqttService {
  static final OfficialMqttService _instance = OfficialMqttService._();
  factory OfficialMqttService() => _instance;
  OfficialMqttService._();

  final _log = LogService();
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSub;
  StreamSubscription<OfficialCloudState>? _cloudSub;
  OfficialCloudService? _boundCloud;
  String? _connectedClientId;
  String? _connectedBroker;
  String? _connectedImei;
  String? _pendingCommandApiName;
  bool _disposed = false;
  bool _preconnectInFlight = false;
  OfficialMqttLinkState _linkState = OfficialMqttLinkState.disconnected;
  StreamController<OfficialMqttLinkState> _linkController =
      StreamController<OfficialMqttLinkState>.broadcast();

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  OfficialMqttLinkState get linkState => _linkState;

  Stream<OfficialMqttLinkState> get linkStateStream => _linkController.stream;

  String? get pendingCommandApiName => _pendingCommandApiName;

  String get linkStateLabel => switch (_linkState) {
    OfficialMqttLinkState.connected => 'MQTT 已连接',
    OfficialMqttLinkState.connecting => 'MQTT 连接中',
    OfficialMqttLinkState.disconnected => 'MQTT 未连接',
  };

  void _setLinkState(OfficialMqttLinkState next) {
    if (_linkState == next) return;
    _linkState = next;
    if (!_linkController.isClosed) {
      _linkController.add(next);
    }
  }

  Future<void> resetForTest() async {
    await _cloudSub?.cancel();
    _cloudSub = null;
    _boundCloud = null;
    _pendingCommandApiName = null;
    await disconnect();
    _disposed = false;
    _preconnectInFlight = false;
    if (_linkController.isClosed) {
      _linkController = StreamController<OfficialMqttLinkState>.broadcast();
    }
    _setLinkState(OfficialMqttLinkState.disconnected);
  }

  Future<void> dispose() async {
    _disposed = true;
    await _cloudSub?.cancel();
    _cloudSub = null;
    _boundCloud = null;
    await disconnect();
    if (!_linkController.isClosed) {
      await _linkController.close();
    }
  }

  /// Bind to cloud state and pre-connect whenever a vehicle is selected.
  void attachToCloud(OfficialCloudService cloud) {
    if (identical(_boundCloud, cloud) && _cloudSub != null) return;
    _boundCloud = cloud;
    unawaited(_cloudSub?.cancel());
    _cloudSub = cloud.stateStream.listen((state) {
      unawaited(_onCloudState(state));
    });
    // Kick once with current state (stateStream is broadcast, may miss last).
    unawaited(_onCloudState(cloud.state));
  }

  Future<void> _onCloudState(OfficialCloudState state) async {
    if (_disposed) return;
    final vehicle = state.selectedVehicle;
    if (!state.signedIn || vehicle == null) {
      await disconnect();
      return;
    }
    await preconnect(
      vehicle: vehicle,
      userId: state.userId,
    );
  }

  /// Best-effort pre-connect used on vehicle select / home enter.
  Future<void> preconnect({
    required OfficialVehicle vehicle,
    required String userId,
  }) async {
    if (_disposed || _preconnectInFlight) return;
    _preconnectInFlight = true;
    try {
      await ensureConnected(vehicle: vehicle, userId: userId);
    } catch (e) {
      _setLinkState(OfficialMqttLinkState.disconnected);
      _log.operation(
        '官方 MQTT 预连接失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
    } finally {
      _preconnectInFlight = false;
    }
  }

  Future<void> preconnectForCloud(OfficialCloudService cloud) async {
    attachToCloud(cloud);
    final vehicle = cloud.state.selectedVehicle;
    if (!cloud.state.signedIn || vehicle == null) return;
    await preconnect(vehicle: vehicle, userId: cloud.state.userId);
  }

  Future<void> disconnect() async {
    await _updatesSub?.cancel();
    _updatesSub = null;
    final client = _client;
    _client = null;
    _connectedClientId = null;
    _connectedBroker = null;
    _connectedImei = null;
    _pendingCommandApiName = null;
    if (client != null) {
      try {
        client.disconnect();
      } catch (_) {}
    }
    _setLinkState(OfficialMqttLinkState.disconnected);
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
      _setLinkState(OfficialMqttLinkState.connected);
      return;
    }

    await disconnect();
    _setLinkState(OfficialMqttLinkState.connecting);

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
        _setLinkState(OfficialMqttLinkState.disconnected);
        throw OfficialCloudApiException(
          '官方 MQTT 连接失败: ${status?.state.name ?? 'unknown'}',
        );
      }
    } on NoConnectionException catch (e) {
      _setLinkState(OfficialMqttLinkState.disconnected);
      throw OfficialCloudApiException('官方 MQTT 连接失败: $e');
    } on SocketException catch (e) {
      _setLinkState(OfficialMqttLinkState.disconnected);
      throw OfficialCloudApiException('官方 MQTT 网络失败: $e');
    }

    for (final topic in OfficialMqttConfig.subscribeTopics(
      vehicle: vehicle,
      imei: imei,
    )) {
      client.subscribe(topic, MqttQos.atMostOnce);
    }

    await _updatesSub?.cancel();
    _updatesSub = client.updates?.listen(
      _onMqttUpdates,
      onError: (Object e) {
        _log.operation(
          '官方 MQTT 收包错误',
          detail: e.toString(),
          level: LogLevel.warning,
        );
      },
    );

    _client = client;
    _connectedClientId = clientId;
    _connectedBroker = broker;
    _connectedImei = imei;
    _setLinkState(OfficialMqttLinkState.connected);
    _log.operation('官方 MQTT 已连接', detail: clientId);
  }

  void _onMqttUpdates(List<MqttReceivedMessage<MqttMessage?>> messages) {
    for (final received in messages) {
      final message = received.payload;
      if (message is! MqttPublishMessage) continue;
      final bytes = message.payload.message;
      final raw = utf8.decode(bytes);
      handleStatusPayload(raw);
    }
  }

  /// Parse status JSON and push ACC/defence into cloud vehicle state.
  ///
  /// Exposed for unit tests; used by the live updates listener.
  void handleStatusPayload(String raw) {
    final payload = OfficialMqttStatusPayload.tryParse(raw);
    if (payload == null) return;

    final pending = _pendingCommandApiName;
    if (pending != null && payload.confirmsCommand(pending)) {
      _pendingCommandApiName = null;
      _log.operation('官方 MQTT 指令已确认: $pending');
    }

    // Official also applies ACC/defence fields opportunistically on any status.
    final cloud = _boundCloud ?? OfficialCloudService();
    if (!payload.hasVehicleState) return;
    cloud.applyMqttVehicleStatus(
      acc: payload.accInt,
      defenceStatus: payload.defenceStatusInt,
    );
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

    _pendingCommandApiName = commandApiName;
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
    attachToCloud(cloud);
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
      // Keep a light HTTP refresh as secondary consistency (official uses MQTT
      // status first; we still poll list state shortly after).
      unawaited(
        Future(() async {
          try {
            await Future<void>.delayed(const Duration(seconds: 2));
            await cloud.refreshVehicles(silent: true, force: true);
          } catch (_) {}
        }),
      );
      return 'success';
    } catch (e) {
      _pendingCommandApiName = null;
      _log.operation(
        '官方 MQTT 发令失败，回退 HTTP',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      return cloud.sendCommand(command);
    }
  }
}
