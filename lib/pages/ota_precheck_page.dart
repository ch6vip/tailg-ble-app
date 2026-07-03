import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/connection_manager.dart' as ble;
import '../main.dart';
import '../services/log_service.dart' as app_log;
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';

class OtaPrecheckPage extends StatefulWidget {
  const OtaPrecheckPage({super.key});

  @override
  State<OtaPrecheckPage> createState() => _OtaPrecheckPageState();
}

class _OtaPrecheckPageState extends State<OtaPrecheckPage> {
  bool _loading = false;
  String? _modelName;
  String? _firmwareVersion;
  String? _manufacturer;
  List<String> _services = const [];

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _runCheck() async {
    if (connectionManager.state == ble.ConnectionState.disconnected) return;
    setState(() => _loading = true);
    try {
      final device = connectionManager.device;
      final services = device?.servicesList ?? const <BluetoothService>[];
      final info = await connectionManager.runGattOperation(
        () => _readDeviceInformation(services),
      );
      if (!mounted) return;
      setState(() {
        _services = services.map((s) => s.serviceUuid.toString()).toList();
        _modelName = info.modelName;
        _firmwareVersion = info.firmwareVersion;
        _manufacturer = info.manufacturer;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<_DeviceInfo> _readDeviceInformation(
    List<BluetoothService> services,
  ) async {
    final infoService = services.where(
      (service) =>
          service.serviceUuid.toString().toLowerCase().contains('180a'),
    );
    if (infoService.isEmpty) return const _DeviceInfo();

    Future<String?> readChar(String uuid) async {
      for (final characteristic in infoService.first.characteristics) {
        if (characteristic.characteristicUuid.toString().toLowerCase().contains(
          uuid,
        )) {
          try {
            final data = await characteristic.read();
            if (data.isEmpty) return null;
            return utf8.decode(data, allowMalformed: true).trim();
          } catch (e) {
            logService.operation(
              'OTA 前置检测 GATT 字段读取失败',
              detail: '$uuid: $e',
              level: app_log.LogLevel.debug,
            );
            return null;
          }
        }
      }
      return null;
    }

    return _DeviceInfo(
      modelName: await readChar('2a24'),
      firmwareVersion: await readChar('2a26'),
      manufacturer: await readChar('2a29'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ble.ConnectionState>(
      stream: connectionManager.stateStream,
      initialData: connectionManager.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? ble.ConnectionState.disconnected;
        final connected = state == ble.ConnectionState.ready;
        final protocol = _protocolLabel(connectionManager.protocol);
        final hasQgj = _services.any((uuid) => uuid.contains('feb0'));
        final hasStandard = _services.any((uuid) => uuid.contains('fee5'));
        final hasFcc0 = _services.any((uuid) => uuid.contains('fcc0'));
        final compatible = connected && (hasQgj || hasStandard);

        return Scaffold(
          backgroundColor: AppColors.pageBg,
          body: SafeArea(
            child: Column(
              children: [
                AppPageHeader(
                  title: 'OTA 前置检测',
                  actions: [
                    IconButton(
                      tooltip: '重新检测',
                      onPressed: _loading ? null : _runCheck,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ],
                ),
                ConnectionStatusBanner(
                  state: state,
                  onScanTap: () => openScanTab(context),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      _StatusCard(
                        compatible: compatible,
                        connected: connected,
                        protocol: protocol,
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        modelName: _modelName,
                        firmwareVersion: _firmwareVersion,
                        manufacturer: _manufacturer,
                        protocol: protocol,
                      ),
                      const SizedBox(height: 12),
                      _CapabilityCard(
                        hasQgj: hasQgj,
                        hasStandard: hasStandard,
                        hasFcc0: hasFcc0,
                      ),
                      const SizedBox(height: 12),
                      const _SafetyCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _protocolLabel(ble.ProtocolType protocol) {
    return switch (protocol) {
      ble.ProtocolType.qgj => 'QGJ (feb0)',
      ble.ProtocolType.standard => 'Standard (fee5)',
      ble.ProtocolType.unknown => '自动识别/未知',
    };
  }
}

class _StatusCard extends StatelessWidget {
  final bool compatible;
  final bool connected;
  final String protocol;
  const _StatusCard({
    required this.compatible,
    required this.connected,
    required this.protocol,
  });

  @override
  Widget build(BuildContext context) {
    final color = compatible ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Row(
        children: [
          Icon(
            compatible ? Icons.verified_outlined : Icons.info_outline,
            color: color,
            size: AppIconSizes.lg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compatible ? '可进行升级前检查' : '等待可检测设备',
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  connected ? '当前协议：$protocol' : '连接车辆后可读取协议和设备信息',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String? modelName;
  final String? firmwareVersion;
  final String? manufacturer;
  final String protocol;

  const _InfoCard({
    required this.modelName,
    required this.firmwareVersion,
    required this.manufacturer,
    required this.protocol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Column(
        children: [
          _InfoRow(label: '协议类型', value: protocol),
          _InfoRow(label: '设备型号', value: modelName ?? '未从 180A 读取到'),
          _InfoRow(label: '固件版本', value: firmwareVersion ?? '未从 2A26 读取到'),
          _InfoRow(label: '制造商', value: manufacturer ?? '未从 2A29 读取到'),
        ],
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  final bool hasQgj;
  final bool hasStandard;
  final bool hasFcc0;

  const _CapabilityCard({
    required this.hasQgj,
    required this.hasStandard,
    required this.hasFcc0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Column(
        children: [
          _InfoRow(label: 'QGJ 服务 feb0', value: hasQgj ? '存在' : '未发现'),
          _InfoRow(label: '标准服务 fee5', value: hasStandard ? '存在' : '未发现'),
          _InfoRow(label: '扩展服务 fcc0', value: hasFcc0 ? '存在' : '未发现'),
        ],
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: AppIconSizes.md,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '当前页面只做升级前检测，不会擦写固件。真正 OTA 需要确认固件来源、分包协议、断点恢复和失败回滚策略后再开放。',
              style: AppTextStyles.bodyMedium,
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
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceInfo {
  final String? modelName;
  final String? firmwareVersion;
  final String? manufacturer;

  const _DeviceInfo({this.modelName, this.firmwareVersion, this.manufacturer});
}
