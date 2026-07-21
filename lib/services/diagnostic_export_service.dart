import 'package:flutter/foundation.dart';

import '../ble/official_ble_connection_context.dart';
import '../models/official_vehicle.dart';
import '../models/persistence_value.dart';
import 'control_channel_resolver.dart';
import 'display_time_formatter.dart';
import 'log_service.dart';
import 'official_cloud_service.dart';
import 'official_mqtt_config.dart';
import 'official_mqtt_service.dart';
import 'sensitive_value_masker.dart';
import 'vehicle_store.dart';

class DiagnosticExportService {
  final LogService logService;
  final VehicleStore vehicleStore;
  final OfficialCloudService officialCloudService;
  final OfficialMqttService officialMqttService;
  final DateTime Function()? _clock;

  DiagnosticExportService({
    required this.logService,
    required this.vehicleStore,
    required this.officialCloudService,
    OfficialMqttService? officialMqttService,
    DateTime Function()? clock,
  }) : officialMqttService = officialMqttService ?? OfficialMqttService(),
       _clock = clock;

  String buildReport(List<LogEntry> entries) {
    return [
      _buildHeader(),
      '',
      _buildVehicleSection(),
      '',
      _buildOfficialCloudSection(),
      '',
      _buildMqttSection(),
      '',
      _buildLogSectionHeading(entries.length),
      ...entries.map(_formatEntry),
    ].join('\n');
  }

  String _buildMqttSection() {
    final mqtt = officialMqttService;
    final vehicle = officialCloudService.state.selectedVehicle;
    final broker = vehicle == null
        ? 'none'
        : OfficialMqttConfig.brokerUriFor(vehicle);
    final mqUser = vehicle == null
        ? 'none'
        : (vehicle.mqUsername.trim().isEmpty
              ? 'missing'
              : SensitiveValueMasker.compact(vehicle.mqUsername));
    final mqPass = vehicle == null
        ? 'none'
        : (vehicle.mqPassword.trim().isEmpty ? 'missing' : 'present');
    return [
      '## Official MQTT',
      'Link state: ${mqtt.linkState.name}',
      'Link label: ${mqtt.linkStateLabel}',
      'Connected: ${mqtt.isConnected}',
      'Preconnect in flight: ${mqtt.preconnectInFlight}',
      'Broker: $broker',
      'Vehicle mqUsername: $mqUser',
      'Vehicle mqPassword: $mqPass',
      'Last user error: ${mqtt.lastPreconnectError ?? 'none'}',
      'Last raw error: ${mqtt.lastPreconnectRawError ?? 'none'}',
      'Last send path: ${mqtt.lastSendPath?.name ?? 'none'}',
    ].join('\n');
  }

  String _buildLogSectionHeading(int entryCount) {
    final evictedCount = logService.evictedCount;
    final evictedSuffix = evictedCount > 0
        ? ' [$evictedCount older entries evicted]'
        : '';
    return '## Logs ($entryCount)$evictedSuffix';
  }

  String _buildOfficialCloudSection() {
    final state = officialCloudService.state;
    final vehicle = state.selectedVehicle;
    final availability = ControlChannelResolver.resolve(cloudState: state);
    final lines = [
      '## Official Cloud',
      'Initialized: ${state.initialized}',
      'Signed in: ${state.signedIn}',
      'Phone: ${state.phone.isEmpty ? 'none' : SensitiveValueMasker.phone(state.phone, shortValue: 'present')}',
      'Token: ${state.token.isEmpty ? 'none' : 'present'}',
      'Vehicles: ${state.vehicles.length}',
      'Control channel: 官方云端',
      'Effective control channel: ${availability.effectiveChannelLabel}',
      'Cloud control available: ${availability.canUseCloud}',
      'Cloud unavailable reason: ${availability.cloudUnavailableReason.isEmpty ? 'none' : availability.cloudUnavailableReason}',
      'Selected vehicle: ${vehicle?.displayName ?? 'none'}',
    ];

    lines.addAll(_buildSelectedVehicleLines(state));
    lines.addAll(_buildOfficialBatteryLines(state.batteryInfo));

    if (state.error != null) {
      lines.add('Error: ${OfficialCloudRedactor.text(state.error!)}');
    }
    final lastRequest = officialCloudService.lastRequest;
    if (lastRequest != null) {
      lines.add('Last request: ${lastRequest.method} ${lastRequest.path}');
      lines.add(
        'Last request status: ${lastRequest.statusCode?.toString() ?? 'none'}',
      );
      lines.add('Last request code: ${lastRequest.code ?? 'none'}');
      lines.add(
        'Last request elapsed: ${lastRequest.elapsed.inMilliseconds}ms',
      );
      lines.add('Last request success: ${lastRequest.success}');
      lines.add('Last request message: ${lastRequest.message ?? 'none'}');
      lines.add('Last request time: ${lastRequest.at.toIso8601String()}');
    }
    return lines.join('\n');
  }

  List<String> _buildSelectedVehicleLines(OfficialCloudState state) {
    final vehicle = state.selectedVehicle;
    if (vehicle == null) return const <String>[];

    final linkedId = state.linkedLocalVehicleId(vehicle.key);
    final rawMac = parsePersistedString(vehicle.raw['mac']);
    final bleContext = OfficialBleConnectionContext.fromVehicle(
      vehicle,
      userId: state.userId,
    );
    final passwordInfo = parsePersistedMap(vehicle.raw['passwordInfo']);
    final passwordMap = parsePersistedMap(vehicle.raw['password']);
    final mainFromInfo = passwordInfo == null
        ? null
        : parsePersistedInt(passwordInfo['main']);
    final mainFromPassword = passwordMap == null
        ? null
        : parsePersistedInt(passwordMap['main']);
    final childrenSource =
        passwordInfo?['children'] ??
        passwordMap?['children'] ??
        vehicle.raw['childrenPassword'] ??
        vehicle.raw['children'];
    final childrenCount = childrenSource is Iterable
        ? childrenSource.length
        : 0;
    final hasPasswordInfoKey = vehicle.raw.containsKey('passwordInfo');
    final hasPasswordKey = vehicle.raw.containsKey('password');
    final hasMacKey = vehicle.raw.containsKey('mac');
    final hasBtmacKey = vehicle.raw.containsKey('btmac');

    return [
      'Selected key: ${SensitiveValueMasker.compact(vehicle.key, emptyValue: 'none', trim: false)}',
      'Linked local vehicle: ${linkedId == null ? 'none' : SensitiveValueMasker.compact(linkedId, emptyValue: 'none', trim: false)}',
      'Online: ${vehicle.online}',
      'Defence: ${vehicle.defenceLabel}',
      'ACC: ${vehicle.powerLabel}',
      'Official vehicle battery: ${vehicle.electricQuantity?.toString() ?? '--'}%',
      'Official vehicle voltage: ${vehicle.voltage?.toString() ?? '--'}V',
      'ModelType: ${vehicle.modelType?.toString() ?? 'none'}',
      'Command IMEI: ${SensitiveValueMasker.compact(vehicle.commandImei, emptyValue: 'none', trim: false)}',
      'IMEI: ${SensitiveValueMasker.compact(vehicle.imei, emptyValue: 'none', trim: false)}',
      'GPS IMEI: ${SensitiveValueMasker.compact(vehicle.imeiGps, emptyValue: 'none', trim: false)}',
      'BT name: ${vehicle.btname.isEmpty ? 'none' : vehicle.btname}',
      'BT MAC: ${SensitiveValueMasker.compact(vehicle.btmac, emptyValue: 'none', trim: false)}',
      // Official ControlFragment QGJ uses CarControlInfoBean.mac as identity.
      'Raw mac field: ${rawMac.isEmpty ? (hasMacKey ? 'empty' : 'missing') : SensitiveValueMasker.compact(rawMac, emptyValue: 'none', trim: false)}',
      'Raw btmac field: ${vehicle.btmac.isEmpty ? (hasBtmacKey ? 'empty' : 'missing') : SensitiveValueMasker.compact(vehicle.btmac, emptyValue: 'none', trim: false)}',
      'BLE identity MAC: ${SensitiveValueMasker.compact(vehicle.bleIdentityMac, emptyValue: 'none', trim: false)}',
      'BLE stack: ${bleContext.stack.name}',
      'BLE target MAC compact: ${SensitiveValueMasker.compact(bleContext.targetMacCompact, emptyValue: 'none', trim: false)}',
      'passwordInfo key: ${hasPasswordInfoKey ? 'present' : 'missing'}',
      'password key: ${hasPasswordKey ? 'present' : 'missing'}',
      'passwordInfo.main: ${mainFromInfo == null ? 'missing' : 'present'}',
      'password.main: ${mainFromPassword == null ? 'missing' : 'present'}',
      'mainBlePassword: ${vehicle.mainBlePassword == null ? 'missing' : 'present'}',
      'childBlePasswords: $childrenCount',
      'shareCarFlag: ${vehicle.shareCarFlag}',
      'BLE uid present: ${bleContext.userId.isNotEmpty}',
      'BLE credentials ready: ${switch (bleContext.stack) {
        OfficialBleStack.tlink => bleContext.hasTLinkCredentials,
        OfficialBleStack.qgj => bleContext.hasQgjCredentials,
        OfficialBleStack.kks => bleContext.targetMacCompact.isNotEmpty,
        OfficialBleStack.unsupported => false,
      }}',
      'Location: ${vehicle.latitude.isEmpty || vehicle.longitude.isEmpty ? 'none' : 'present (hidden)'}',
    ];
  }

  List<String> _buildOfficialBatteryLines(OfficialBatteryInfo? batteryInfo) {
    if (batteryInfo == null) return const ['Official battery detail: none'];

    String metric(String value, {String unit = ''}) {
      final text = value.trim();
      if (text.isEmpty) return 'missing';
      if (unit.isEmpty) return text;
      return text.endsWith(unit) ? text : '$text$unit';
    }

    return [
      'Official battery detail: ${batteryInfo.dumpEnergyPercentLabel.isEmpty ? 'none' : batteryInfo.dumpEnergyPercentLabel}',
      'Official battery detail voltage: ${metric(batteryInfo.voltage, unit: 'V')}',
      'Official battery detail temperature: ${metric(batteryInfo.temperature, unit: 'C')}',
      'Official battery consumePowerPercent: ${metric(batteryInfo.consumePowerPercent, unit: '%')}',
      'Official battery loopCount: ${metric(batteryInfo.loopCount)}',
      'Official battery capacitance: ${metric(batteryInfo.capacitance)}',
      'Official battery score: ${metric(batteryInfo.batteryScore)}',
      'Official battery raw keys: ${batteryInfo.raw.keys.take(20).join(',')}',
    ];
  }

  String _buildHeader() {
    return [
      '# Tailg Diagnostic Report',
      'Generated: ${_now().toIso8601String()}',
      'Platform: ${defaultTargetPlatform.name}',
      'Mode: ${kReleaseMode ? 'release' : 'debug/profile'}',
    ].join('\n');
  }

  DateTime _now() {
    return (_clock ?? DateTime.now)();
  }

  String _buildVehicleSection() {
    final vehicle = vehicleStore.defaultVehicle;
    if (vehicle == null) return '## Vehicle\nDefault: none';

    final location = vehicle.lastLocation;
    final lines = [
      '## Vehicle',
      'Default ID: ${SensitiveValueMasker.compact(vehicle.id, emptyValue: 'none', trim: false)}',
      'Name: ${vehicle.displayName}',
      'Protocol: ${vehicle.protocol.label}',
      'Last connected: ${vehicle.lastConnectedAt?.toIso8601String() ?? 'none'}',
    ];
    if (location != null) {
      lines.add('Last location: present (hidden)');
    }
    return lines.join('\n');
  }

  String _formatEntry(LogEntry entry) {
    final t = formatLogClockTime(entry.time);
    final level = entry.level.name.toUpperCase();
    final detail = entry.detail;
    return '$t [OP] [$level] ${OfficialCloudRedactor.text(entry.message)}'
        '${detail == null ? '' : ' | ${OfficialCloudRedactor.text(detail)}'}';
  }
}
