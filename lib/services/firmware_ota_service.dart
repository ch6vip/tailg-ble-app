import 'dart:async';
import 'dart:typed_data';

import '../ble/connection_manager.dart';
import '../models/official_vehicle.dart';
import 'log_service.dart';
import 'official_cloud_service.dart';

enum FirmwareOtaPhase {
  idle,
  querying,
  downloading,
  transferring,
  completed,
  failed,
}

class FirmwareOtaProgress {
  final FirmwareOtaPhase phase;
  final double fraction;
  final String message;

  const FirmwareOtaProgress({
    required this.phase,
    required this.fraction,
    required this.message,
  });
}

/// P3-5 end-to-end OTA: query firm version → download → BLE order/file chunks.
class FirmwareOtaService {
  final OfficialCloudService cloud;
  final ConnectionManager connectionManager;
  final LogService _log;

  Future<Uint8List> Function(String url)? downloadOverride;
  Future<bool> Function(List<int> order)? writeOrderOverride;
  Future<bool> Function(List<int> chunk)? writeChunkOverride;

  static const defaultChunkSize = 180;

  FirmwareOtaService({
    required this.cloud,
    required this.connectionManager,
    LogService? logService,
  }) : _log = logService ?? LogService();

  Stream<FirmwareOtaProgress> run({
    OfficialVehicle? vehicle,
    int chunkSize = defaultChunkSize,
    Uint8List? firmwareBytes,
  }) async* {
    final selected = vehicle ?? cloud.state.selectedVehicle;
    if (selected == null) {
      yield const FirmwareOtaProgress(
        phase: FirmwareOtaPhase.failed,
        fraction: 0,
        message: '未选择车辆',
      );
      return;
    }
    final imei = selected.commandImei;
    if (imei.isEmpty) {
      yield const FirmwareOtaProgress(
        phase: FirmwareOtaPhase.failed,
        fraction: 0,
        message: '车辆缺少 IMEI',
      );
      return;
    }

    yield const FirmwareOtaProgress(
      phase: FirmwareOtaPhase.querying,
      fraction: 0.05,
      message: '查询官方固件版本…',
    );

    Map<String, dynamic> firmInfo;
    try {
      firmInfo = await cloud.getFirmVersion(imei: imei);
    } catch (e) {
      yield FirmwareOtaProgress(
        phase: FirmwareOtaPhase.failed,
        fraction: 0.05,
        message: '固件查询失败: $e',
      );
      return;
    }

    final url =
        (firmInfo['url'] ?? firmInfo['fileUrl'] ?? firmInfo['downUrl'] ?? '')
            .toString()
            .trim();

    late final Uint8List bytes;
    if (firmwareBytes != null) {
      bytes = firmwareBytes;
      yield const FirmwareOtaProgress(
        phase: FirmwareOtaPhase.downloading,
        fraction: 0.2,
        message: '使用注入固件包…',
      );
    } else if (url.isNotEmpty) {
      yield const FirmwareOtaProgress(
        phase: FirmwareOtaPhase.downloading,
        fraction: 0.15,
        message: '下载固件…',
      );
      try {
        bytes = await _download(url);
      } catch (e) {
        yield FirmwareOtaProgress(
          phase: FirmwareOtaPhase.failed,
          fraction: 0.15,
          message: '固件下载失败: $e',
        );
        return;
      }
    } else {
      yield FirmwareOtaProgress(
        phase: FirmwareOtaPhase.failed,
        fraction: 0.1,
        message:
            '未查到可下载固件（version=${firmInfo['version'] ?? firmInfo['firmVersion'] ?? '-'}）',
      );
      return;
    }

    if (!connectionManager.isProtocolLoggedIn) {
      yield const FirmwareOtaProgress(
        phase: FirmwareOtaPhase.failed,
        fraction: 0.25,
        message: '请先 BLE 协议登录后再传输固件',
      );
      return;
    }

    yield FirmwareOtaProgress(
      phase: FirmwareOtaPhase.transferring,
      fraction: 0.3,
      message: '开始 BLE 分片传输 (${bytes.length} bytes)…',
    );

    final order = <int>[0x01, (bytes.length >> 8) & 0xFF, bytes.length & 0xFF];
    final orderOk = writeOrderOverride != null
        ? await writeOrderOverride!(order)
        : await connectionManager.writeOtaOrder(order);
    if (!orderOk) {
      yield const FirmwareOtaProgress(
        phase: FirmwareOtaPhase.failed,
        fraction: 0.3,
        message: 'OTA order 写入失败（7000 特征不可用？）',
      );
      return;
    }

    final total = bytes.length;
    var offset = 0;
    var index = 0;
    while (offset < total) {
      final end = (offset + chunkSize > total) ? total : offset + chunkSize;
      final chunk = bytes.sublist(offset, end);
      final ok = writeChunkOverride != null
          ? await writeChunkOverride!(chunk)
          : await connectionManager.writeOtaFileChunk(chunk);
      if (!ok) {
        yield FirmwareOtaProgress(
          phase: FirmwareOtaPhase.failed,
          fraction: 0.3 + 0.65 * (offset / total),
          message: 'OTA 分片 $index 写入失败',
        );
        return;
      }
      offset = end;
      index += 1;
      yield FirmwareOtaProgress(
        phase: FirmwareOtaPhase.transferring,
        fraction: 0.3 + 0.65 * (offset / total),
        message: '已传输 $offset / $total',
      );
    }

    _log.operation('OTA 分片传输完成', detail: 'chunks=$index bytes=$total');
    yield const FirmwareOtaProgress(
      phase: FirmwareOtaPhase.completed,
      fraction: 1,
      message: 'OTA 传输完成，请等待车辆重启/校验',
    );
  }

  Future<Uint8List> _download(String url) {
    final override = downloadOverride;
    if (override != null) return override(url);
    throw UnsupportedError('未配置 downloadOverride，拒绝在此环境拉真实固件: $url');
  }
}
