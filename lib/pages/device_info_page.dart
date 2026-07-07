import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/connection_manager.dart' as ble;
import '../main.dart';
import '../models/official_vehicle.dart';
import '../models/vehicle_profile.dart';
import '../services/display_time_formatter.dart';
import '../services/log_service.dart' as app_log;
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';

class DeviceInfoPage extends StatefulWidget {
  const DeviceInfoPage({super.key});

  @override
  State<DeviceInfoPage> createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends State<DeviceInfoPage> {
  bool _loading = false;
  _GattDeviceInfo _deviceInfo = const _GattDeviceInfo();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (connectionManager.state != ble.ConnectionState.ready) {
      if (!mounted) return;
      setState(() => _deviceInfo = const _GattDeviceInfo());
      return;
    }
    final device = connectionManager.device;
    final services = device?.servicesList ?? const <BluetoothService>[];
    if (services.isEmpty) {
      if (!mounted) return;
      setState(() => _deviceInfo = const _GattDeviceInfo());
      return;
    }

    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final info = await connectionManager.runGattOperation(
        () => _readGattDeviceInfo(services),
      );
      if (!mounted) return;
      setState(() => _deviceInfo = info);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_GattDeviceInfo> _readGattDeviceInfo(
    List<BluetoothService> services,
  ) async {
    final infoService = services.where(
      (service) =>
          service.serviceUuid.toString().toLowerCase().contains('180a'),
    );
    if (infoService.isEmpty) {
      return _GattDeviceInfo(services: _mapServices(services));
    }

    Future<String?> readChar(String uuid) async {
      for (final characteristic in infoService.first.characteristics) {
        final charUuid = characteristic.characteristicUuid
            .toString()
            .toLowerCase();
        if (!charUuid.contains(uuid)) continue;
        try {
          final data = await characteristic.read();
          if (data.isEmpty) return null;
          return utf8.decode(data, allowMalformed: true).trim();
        } catch (e) {
          logService.operation(
            '设备信息 GATT 字段读取失败',
            detail: '$uuid: $e',
            level: app_log.LogLevel.debug,
          );
          return null;
        }
      }
      return null;
    }

    return _GattDeviceInfo(
      manufacturer: await readChar('2a29'),
      modelNumber: await readChar('2a24'),
      serialNumber: await readChar('2a25'),
      hardwareRevision: await readChar('2a27'),
      firmwareRevision: await readChar('2a26'),
      softwareRevision: await readChar('2a28'),
      services: _mapServices(services),
    );
  }

  List<_GattServiceInfo> _mapServices(List<BluetoothService> services) {
    return services
        .map(
          (service) => _GattServiceInfo(
            uuid: service.serviceUuid.toString(),
            characteristics: service.characteristics
                .map(
                  (characteristic) => _GattCharacteristicInfo(
                    uuid: characteristic.characteristicUuid.toString(),
                    properties: _propertiesLabel(characteristic.properties),
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  String _propertiesLabel(CharacteristicProperties properties) {
    final items = <String>[
      if (properties.read) 'read',
      if (properties.write) 'write',
      if (properties.writeWithoutResponse) 'writeWithoutResponse',
      if (properties.notify) 'notify',
      if (properties.indicate) 'indicate',
      if (properties.broadcast) 'broadcast',
    ];
    return items.isEmpty ? 'none' : items.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ble.ConnectionState>(
      stream: connectionManager.stateStream,
      initialData: connectionManager.state,
      builder: (context, snapshot) {
        final connState = snapshot.data ?? ble.ConnectionState.disconnected;
        final device = connectionManager.device;
        return StreamBuilder<List<VehicleProfile>>(
          stream: vehicleStore.vehiclesStream,
          initialData: vehicleStore.vehicles,
          builder: (context, vehicleSnapshot) {
            final vehicle = vehicleStore.defaultVehicle;
            return StreamBuilder<OfficialCloudState>(
              stream: officialCloudService.stateStream,
              initialData: officialCloudService.state,
              builder: (context, cloudSnapshot) {
                final cloudState =
                    cloudSnapshot.data ?? officialCloudService.state;
                final cloudVehicle = cloudState.signedIn
                    ? cloudState.selectedVehicle
                    : null;
                return Scaffold(
                  backgroundColor: AppColors.pageBg,
                  body: SafeArea(
                    child: Column(
                      children: [
                        AppPageHeader(
                          title: '车辆信息',
                          actions: [
                            IconButton(
                              tooltip: '刷新',
                              onPressed: _loading ? null : _refresh,
                              icon: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                        ConnectionStatusBanner(
                          state: connState,
                          onScanTap: () => openScanTab(context),
                        ),
                        Expanded(
                          child: ListView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 24),
                            children: [
                              const AppSectionLabel('车辆档案'),
                              _VehicleProfileCard(
                                vehicle: vehicle,
                                officialVehicle: cloudVehicle,
                              ),
                              const AppSectionLabel('蓝牙设备'),
                              _BleDeviceCard(
                                device: device,
                                state: connState,
                                protocol: connectionManager.protocol,
                                lastKnownProtocol:
                                    connectionManager.lastKnownProtocol,
                                token: connectionManager.token,
                              ),
                              const AppSectionLabel('设备信息服务'),
                              _DeviceInfoCard(info: _deviceInfo),
                              const AppSectionLabel('服务与特征'),
                              if (_deviceInfo.services.isEmpty)
                                const _EmptyInfoCard(
                                  icon: Icons.bluetooth_disabled,
                                  title: '暂无 GATT 服务',
                                  subtitle: '连接车辆并完成服务发现后，可查看服务 UUID 和特征属性。',
                                )
                              else
                                _GattServiceList(
                                  services: _deviceInfo.services,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _VehicleProfileCard extends StatelessWidget {
  final VehicleProfile? vehicle;
  final OfficialVehicle? officialVehicle;

  const _VehicleProfileCard({
    required this.vehicle,
    required this.officialVehicle,
  });

  @override
  Widget build(BuildContext context) {
    final location = vehicle?.lastLocation;
    final officialVehicle = this.officialVehicle;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _InfoRow(
            label: '车辆名称',
            value:
                vehicle?.displayName ?? officialVehicle?.displayName ?? '未绑定车辆',
          ),
          const _InsetDivider(),
          _InfoRow(
            label: '车辆 ID',
            value: vehicle?.id ?? officialVehicle?.carId ?? '--',
          ),
          const _InsetDivider(),
          _InfoRow(label: '协议偏好', value: vehicle?.protocol.label ?? '自动识别'),
          if (officialVehicle != null) ...[
            const _InsetDivider(),
            _InfoRow(label: '官方在线', value: officialVehicle.onlineLabel),
            const _InsetDivider(),
            _InfoRow(
              label: '官方电量',
              value: officialVehicle.electricQuantity == null
                  ? '--'
                  : '${officialVehicle.electricQuantity}%',
            ),
          ],
          const _InsetDivider(),
          _InfoRow(
            label: '最后连接',
            value: _formatNullableDateTime(vehicle?.lastConnectedAt),
          ),
          const _InsetDivider(),
          _InfoRow(
            label: '最后位置',
            value: location == null
                ? '--'
                : '${location.coordinateText} (${location.accuracy.toStringAsFixed(1)}m)',
          ),
          const _InsetDivider(),
          _InfoRow(
            label: 'QGJ 参数',
            value: vehicle?.hasQgjCredentials == true ? '已保存' : '未保存',
          ),
        ],
      ),
    );
  }
}

class _BleDeviceCard extends StatelessWidget {
  final BluetoothDevice? device;
  final ble.ConnectionState state;
  final ble.ProtocolType protocol;
  final ble.ProtocolType lastKnownProtocol;
  final String? token;

  const _BleDeviceCard({
    required this.device,
    required this.state,
    required this.protocol,
    required this.lastKnownProtocol,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _InfoRow(label: '连接状态', value: _stateLabel(state)),
          const _InsetDivider(),
          _InfoRow(label: '设备名称', value: _deviceName(device)),
          const _InsetDivider(),
          _InfoRow(
            label: 'Remote ID',
            value: device?.remoteId.toString() ?? '--',
          ),
          const _InsetDivider(),
          _InfoRow(label: '当前协议', value: _protocolLabel(protocol)),
          const _InsetDivider(),
          _InfoRow(label: '最近协议', value: _protocolLabel(lastKnownProtocol)),
          const _InsetDivider(),
          _InfoRow(label: '登录状态', value: token == null ? '未就绪' : '已就绪'),
        ],
      ),
    );
  }

  String _deviceName(BluetoothDevice? device) {
    if (device == null) return '--';
    final name = device.platformName.trim();
    return name.isEmpty ? '未命名 BLE 设备' : name;
  }

  String _stateLabel(ble.ConnectionState state) {
    return state.label;
  }
}

class _DeviceInfoCard extends StatelessWidget {
  final _GattDeviceInfo info;

  const _DeviceInfoCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final hasInfo = [
      info.manufacturer,
      info.modelNumber,
      info.serialNumber,
      info.hardwareRevision,
      info.firmwareRevision,
      info.softwareRevision,
    ].any((value) => value != null && value.trim().isNotEmpty);

    if (!hasInfo) {
      return const _EmptyInfoCard(
        icon: Icons.info_outline,
        title: '未读取到 180A 信息',
        subtitle: '部分车辆不开放设备信息服务，或需要先保持车辆连接。',
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _InfoRow(label: '制造商', value: _value(info.manufacturer)),
          const _InsetDivider(),
          _InfoRow(label: '设备型号', value: _value(info.modelNumber)),
          const _InsetDivider(),
          _InfoRow(label: '序列号', value: _value(info.serialNumber)),
          const _InsetDivider(),
          _InfoRow(label: '硬件版本', value: _value(info.hardwareRevision)),
          const _InsetDivider(),
          _InfoRow(label: '固件版本', value: _value(info.firmwareRevision)),
          const _InsetDivider(),
          _InfoRow(label: '软件版本', value: _value(info.softwareRevision)),
        ],
      ),
    );
  }
}

class _GattServiceList extends StatelessWidget {
  final List<_GattServiceInfo> services;

  const _GattServiceList({required this.services});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < services.length; i++) ...[
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              title: Text(
                services[i].uuid,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLarge,
              ),
              subtitle: Text(
                '${services[i].characteristics.length} 个特征',
                style: AppTextStyles.smallText,
              ),
              children: services[i].characteristics
                  .map((characteristic) => _CharacteristicRow(characteristic))
                  .toList(growable: false),
            ),
            if (i != services.length - 1) const _InsetDivider(),
          ],
        ],
      ),
    );
  }
}

class _CharacteristicRow extends StatelessWidget {
  final _GattCharacteristicInfo characteristic;

  const _CharacteristicRow(this.characteristic);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            characteristic.uuid,
            style: AppTextStyles.smallText.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            characteristic.properties,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.valueText,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.textTertiary,
              size: AppIconSizes.md,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyLarge),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.smallText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsetDivider extends StatelessWidget {
  const _InsetDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.border,
    );
  }
}

class _GattDeviceInfo {
  final String? manufacturer;
  final String? modelNumber;
  final String? serialNumber;
  final String? hardwareRevision;
  final String? firmwareRevision;
  final String? softwareRevision;
  final List<_GattServiceInfo> services;

  const _GattDeviceInfo({
    this.manufacturer,
    this.modelNumber,
    this.serialNumber,
    this.hardwareRevision,
    this.firmwareRevision,
    this.softwareRevision,
    this.services = const [],
  });
}

class _GattServiceInfo {
  final String uuid;
  final List<_GattCharacteristicInfo> characteristics;

  const _GattServiceInfo({required this.uuid, required this.characteristics});
}

class _GattCharacteristicInfo {
  final String uuid;
  final String properties;

  const _GattCharacteristicInfo({required this.uuid, required this.properties});
}

String _value(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return '--';
  return text;
}

String _protocolLabel(ble.ProtocolType protocol) {
  return switch (protocol) {
    ble.ProtocolType.qgj => 'QGJ (feb0)',
    ble.ProtocolType.standard => 'Standard (fee5)',
    ble.ProtocolType.unknown => '自动识别/未知',
  };
}

String _formatNullableDateTime(DateTime? time) {
  if (time == null) return '--';
  return formatDateMinuteText(time);
}
