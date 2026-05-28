import 'package:flutter/foundation.dart';

import '../ble/connection_manager.dart' as ble;
import 'log_service.dart';
import 'vehicle_store.dart';

class DiagnosticExportService {
  final ble.ConnectionManager connectionManager;
  final LogService logService;
  final VehicleStore vehicleStore;

  const DiagnosticExportService({
    required this.connectionManager,
    required this.logService,
    required this.vehicleStore,
  });

  String buildReport(List<LogEntry> entries) {
    return [
      _buildHeader(),
      '',
      _buildVehicleSection(),
      '',
      _buildBleSection(),
      '',
      '## Logs (${entries.length})',
      ...entries.map(_formatEntry),
    ].join('\n');
  }

  String _buildHeader() {
    return [
      '# Tailg BLE Diagnostic Report',
      'Generated: ${DateTime.now().toIso8601String()}',
      'Platform: ${defaultTargetPlatform.name}',
      'Mode: ${kReleaseMode ? 'release' : 'debug/profile'}',
    ].join('\n');
  }

  String _buildVehicleSection() {
    final vehicle = vehicleStore.defaultVehicle;
    if (vehicle == null) return '## Vehicle\nDefault: none';

    final location = vehicle.lastLocation;
    final lines = [
      '## Vehicle',
      'Default ID: ${vehicle.id}',
      'Name: ${vehicle.displayName}',
      'Protocol: ${vehicle.protocol.label}',
      'Last connected: ${vehicle.lastConnectedAt?.toIso8601String() ?? 'none'}',
    ];
    if (location != null) {
      lines.add('Last location: ${location.coordinateText}');
      lines.add('Location accuracy: ${location.accuracy.toStringAsFixed(1)}m');
      lines.add('Location time: ${location.recordedAt.toIso8601String()}');
    }
    return lines.join('\n');
  }

  String _buildBleSection() {
    final device = connectionManager.device;
    final protocol = connectionManager.protocol;
    final lastKnownProtocol = connectionManager.lastKnownProtocol;
    final protocolText = protocol != ble.ProtocolType.unknown
        ? protocol.name
        : lastKnownProtocol != ble.ProtocolType.unknown
        ? '${lastKnownProtocol.name} (last known)'
        : protocol.name;
    final lines = [
      '## BLE',
      'State: ${connectionManager.state.name}',
      'Protocol: $protocolText',
      'Device: ${device?.platformName ?? 'none'}',
      'Remote ID: ${device?.remoteId.toString() ?? 'none'}',
      'Token: ${connectionManager.token == null ? 'none' : 'present'}',
    ];

    if (device != null) {
      for (final service in device.servicesList) {
        lines.add('Service: ${service.serviceUuid}');
        for (final c in service.characteristics) {
          final props = [
            if (c.properties.read) 'read',
            if (c.properties.write) 'write',
            if (c.properties.writeWithoutResponse) 'writeWithoutResponse',
            if (c.properties.notify) 'notify',
            if (c.properties.indicate) 'indicate',
          ].join(',');
          lines.add('  Char: ${c.characteristicUuid} [$props]');
        }
      }
    }
    return lines.join('\n');
  }

  String _formatEntry(LogEntry entry) {
    final t =
        '${entry.time.hour.toString().padLeft(2, '0')}:'
        '${entry.time.minute.toString().padLeft(2, '0')}:'
        '${entry.time.second.toString().padLeft(2, '0')}';
    final tag = entry.category == LogCategory.ble ? '[BLE]' : '[OP]';
    final level = entry.level.name.toUpperCase();
    return '$t $tag [$level] ${entry.message}'
        '${entry.detail != null ? ' | ${entry.detail}' : ''}';
  }
}
