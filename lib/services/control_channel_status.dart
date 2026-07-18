import '../ble/connection_manager.dart';
import 'control_channel_resolver.dart';
import 'official_mqtt_service.dart';

/// Canonical top-bar channel copy for 爱车 (README / PLAN P0-C3).
///
/// Four primary states:
/// - `BLE 直连` — will use BLE after LOGIN
/// - `MQTT 远程` — MQTT session live for remote control
/// - `MQTT 连接中` — MQTT preconnect/ensure in flight
/// - `云端待命` — cloud path available, MQTT not yet live
///
/// Extra diagnostics (still single source): `MQTT 待重连` · `蓝牙连接中` · `不可用`.
enum ControlTopBarChannelKind {
  bleDirect,
  bleConnecting,
  mqttRemote,
  mqttConnecting,
  mqttRetry,
  cloudStandby,
  unavailable,
}

class ControlTopBarChannel {
  final ControlTopBarChannelKind kind;
  final String label;

  const ControlTopBarChannel({required this.kind, required this.label});

  bool get isActive =>
      kind == ControlTopBarChannelKind.bleDirect ||
      kind == ControlTopBarChannelKind.mqttRemote;

  /// Single truth source for 爱车 top-bar channel text + activity.
  static ControlTopBarChannel resolve({
    required ControlChannelAvailability availability,
    required ConnectionState bleState,
    required bool bleProtocolLoggedIn,
    required OfficialMqttLinkState mqttLinkState,
    required bool mqttPreconnectInFlight,
    String? mqttLastPreconnectError,
  }) {
    // BLE LOGIN path wins when resolver will actually send BLE.
    if (availability.willUseBle && bleProtocolLoggedIn) {
      return const ControlTopBarChannel(
        kind: ControlTopBarChannelKind.bleDirect,
        label: 'BLE 直连',
      );
    }

    // GATT up / handshake — not LOGIN yet (P0-A3: do not claim ready).
    if (bleState == ConnectionState.connecting ||
        bleState == ConnectionState.connected ||
        bleState == ConnectionState.reconnecting) {
      // If cloud is actively usable we still prefer showing remote readiness,
      // but while intentionally near-field linking, surface BLE progress.
      if (!availability.canUseCloud ||
          availability.channel == OfficialControlChannel.ble) {
        return const ControlTopBarChannel(
          kind: ControlTopBarChannelKind.bleConnecting,
          label: '蓝牙连接中',
        );
      }
    }

    final mqttConnected = mqttLinkState == OfficialMqttLinkState.connected;
    if (mqttConnected) {
      return const ControlTopBarChannel(
        kind: ControlTopBarChannelKind.mqttRemote,
        label: 'MQTT 远程',
      );
    }

    if (mqttLinkState == OfficialMqttLinkState.connecting ||
        mqttPreconnectInFlight) {
      return const ControlTopBarChannel(
        kind: ControlTopBarChannelKind.mqttConnecting,
        label: 'MQTT 连接中',
      );
    }

    final preErr = mqttLastPreconnectError?.trim() ?? '';
    if (preErr.isNotEmpty && availability.canUseCloud) {
      return const ControlTopBarChannel(
        kind: ControlTopBarChannelKind.mqttRetry,
        label: 'MQTT 待重连',
      );
    }

    if (availability.canUseCloud) {
      return const ControlTopBarChannel(
        kind: ControlTopBarChannelKind.cloudStandby,
        label: '云端待命',
      );
    }

    // Fall back to resolver disabled/effective label — never invent a fifth primary.
    final disabled = availability.disabledReason.trim();
    if (disabled.isNotEmpty) {
      return ControlTopBarChannel(
        kind: ControlTopBarChannelKind.unavailable,
        label: disabled,
      );
    }
    final effective = availability.effectiveChannelLabel.trim();
    return ControlTopBarChannel(
      kind: ControlTopBarChannelKind.unavailable,
      label: effective.isEmpty ? '不可用' : effective,
    );
  }
}
