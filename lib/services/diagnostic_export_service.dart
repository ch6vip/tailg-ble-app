import 'package:flutter/foundation.dart';

import '../ble/connection_manager.dart' as ble;
import 'log_service.dart';
import 'official_cloud_service.dart';
import 'vehicle_store.dart';

class DiagnosticExportService {
  final ble.ConnectionManager connectionManager;
  final LogService logService;
  final VehicleStore vehicleStore;
  final OfficialCloudService officialCloudService;

  const DiagnosticExportService({
    required this.connectionManager,
    required this.logService,
    required this.vehicleStore,
    required this.officialCloudService,
  });

  String buildReport(List<LogEntry> entries) {
    return [
      _buildHeader(),
      '',
      _buildVehicleSection(),
      '',
      _buildOfficialCloudSection(),
      '',
      _buildBleSection(),
      '',
      '## Logs (${entries.length})',
      ...entries.map(_formatEntry),
    ].join('\n');
  }

  String _buildOfficialCloudSection() {
    final state = officialCloudService.state;
    final vehicle = state.selectedVehicle;
    final lines = [
      '## Official Cloud',
      'Initialized: ${state.initialized}',
      'Signed in: ${state.signedIn}',
      'Phone: ${state.phone.isEmpty ? 'none' : _maskPhone(state.phone)}',
      'Token: ${state.token.isEmpty ? 'none' : 'present'}',
      'Vehicles: ${state.vehicles.length}',
      'Control channel: ${state.controlChannel.label}',
      'Selected vehicle: ${vehicle?.displayName ?? 'none'}',
    ];

    if (vehicle != null) {
      final linkedId = state.linkedLocalVehicleId(vehicle.key);
      lines.add('Selected key: ${_maskId(vehicle.key)}');
      lines.add(
        'Linked local vehicle: ${linkedId == null ? 'none' : _maskId(linkedId)}',
      );
      lines.add('Online: ${vehicle.online}');
      lines.add('Defence: ${vehicle.defenceLabel}');
      lines.add('ACC: ${vehicle.powerLabel}');
      lines.add('Battery: ${vehicle.electricQuantity?.toString() ?? '--'}%');
      lines.add('Voltage: ${vehicle.voltage?.toString() ?? '--'}V');
      lines.add('ModelType: ${vehicle.modelType?.toString() ?? 'none'}');
      lines.add('Command IMEI: ${_maskId(vehicle.commandImei)}');
      lines.add('IMEI: ${_maskId(vehicle.imei)}');
      lines.add('GPS IMEI: ${_maskId(vehicle.imeiGps)}');
      lines.add('BT name: ${vehicle.btname.isEmpty ? 'none' : vehicle.btname}');
      lines.add('BT MAC: ${_maskId(vehicle.btmac)}');
      lines.add(
        'Location: ${vehicle.latitude.isEmpty || vehicle.longitude.isEmpty ? 'none' : '${vehicle.latitude}, ${vehicle.longitude}'}',
      );
    }

    if (state.error != null) {
      lines.add('Error: ${state.error}');
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
      'QGJ credentials: ${vehicle.hasQgjCredentials ? 'custom' : 'default'}',
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
      'QGJ login: password=${connectionManager.qgjLoginPassword == 0 ? 'default' : 'custom'}, userId=${connectionManager.qgjUserId == 0 ? 'default' : 'custom'}',
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

  String _maskPhone(String phone) {
    if (phone.length < 7) return 'present';
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }

  String _maskId(String value) {
    if (value.isEmpty) return 'none';
    if (value.length <= 6) return '***';
    return '${value.substring(0, 3)}***${value.substring(value.length - 3)}';
  }
}
