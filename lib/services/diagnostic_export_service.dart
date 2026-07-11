import 'package:flutter/foundation.dart';

import '../models/official_vehicle.dart';
import 'control_channel_resolver.dart';
import 'display_time_formatter.dart';
import 'log_service.dart';
import 'official_cloud_service.dart';
import 'sensitive_value_masker.dart';
import 'vehicle_store.dart';

class DiagnosticExportService {
  final LogService logService;
  final VehicleStore vehicleStore;
  final OfficialCloudService officialCloudService;
  final DateTime Function()? _clock;

  const DiagnosticExportService({
    required this.logService,
    required this.vehicleStore,
    required this.officialCloudService,
    DateTime Function()? clock,
  }) : _clock = clock;

  String buildReport(List<LogEntry> entries) {
    return [
      _buildHeader(),
      '',
      _buildVehicleSection(),
      '',
      _buildOfficialCloudSection(),
      '',
      _buildLogSectionHeading(entries.length),
      ...entries.map(_formatEntry),
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
      'Phone: ${state.phone.isEmpty ? 'none' : _maskPhone(state.phone)}',
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
    return [
      'Selected key: ${_maskId(vehicle.key)}',
      'Linked local vehicle: ${linkedId == null ? 'none' : _maskId(linkedId)}',
      'Online: ${vehicle.online}',
      'Defence: ${vehicle.defenceLabel}',
      'ACC: ${vehicle.powerLabel}',
      'Official vehicle battery: ${vehicle.electricQuantity?.toString() ?? '--'}%',
      'Official vehicle voltage: ${vehicle.voltage?.toString() ?? '--'}V',
      'ModelType: ${vehicle.modelType?.toString() ?? 'none'}',
      'Command IMEI: ${_maskId(vehicle.commandImei)}',
      'IMEI: ${_maskId(vehicle.imei)}',
      'GPS IMEI: ${_maskId(vehicle.imeiGps)}',
      'BT name: ${vehicle.btname.isEmpty ? 'none' : vehicle.btname}',
      'BT MAC: ${_maskId(vehicle.btmac)}',
      'Location: ${vehicle.latitude.isEmpty || vehicle.longitude.isEmpty ? 'none' : 'present (hidden)'}',
    ];
  }

  List<String> _buildOfficialBatteryLines(OfficialBatteryInfo? batteryInfo) {
    if (batteryInfo == null) return const ['Official battery detail: none'];

    return [
      'Official battery detail: ${batteryInfo.dumpEnergyPercentLabel.isEmpty ? 'none' : batteryInfo.dumpEnergyPercentLabel}',
      'Official battery detail voltage: ${batteryInfo.voltage.isEmpty ? 'none' : '${batteryInfo.voltage}V'}',
      'Official battery detail temperature: ${batteryInfo.temperature.isEmpty ? 'none' : '${batteryInfo.temperature}C'}',
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
      'Default ID: ${_maskId(vehicle.id)}',
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
    final tag = entry.category == LogCategory.connection ? '[CONN]' : '[OP]';
    final level = entry.level.name.toUpperCase();
    final detail = entry.detail;
    return '$t $tag [$level] ${OfficialCloudRedactor.text(entry.message)}'
        '${detail == null ? '' : ' | ${OfficialCloudRedactor.text(detail)}'}';
  }

  String _maskPhone(String phone) {
    return SensitiveValueMasker.phone(phone, shortValue: 'present');
  }

  String _maskId(String value) {
    return SensitiveValueMasker.compact(value, emptyValue: 'none', trim: false);
  }
}
