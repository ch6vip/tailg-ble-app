import '../ble/connection_manager.dart';
import '../ble/nfc_ble_frames.dart';
import 'log_service.dart';

/// P3-6 true NFC path: official BLE writeData frames after LOGIN.
class BleNfcService {
  final ConnectionManager connectionManager;
  final LogService _log;

  BleNfcService({required this.connectionManager, LogService? logService})
    : _log = logService ?? LogService();

  bool get canWriteOfficialNfc =>
      connectionManager.isProtocolLoggedIn &&
      (connectionManager.protocol == ProtocolType.kks ||
          connectionManager.protocol == ProtocolType.tlink);

  Future<bool> addUserKey({required int keyType, required String type}) {
    final hex = OfficialNfcBleFrames.addUserKeyHex(
      keyType: keyType,
      type: type,
    );
    return _write(hex, label: 'addUserKey');
  }

  Future<bool> addCard(String index) {
    return _write(OfficialNfcBleFrames.addCardHex(index), label: 'addCard');
  }

  Future<bool> checkNfc(String index) {
    return _write(OfficialNfcBleFrames.checkNfcHex(index), label: 'checkNfc');
  }

  Future<bool> delNfc(String index) {
    return _write(OfficialNfcBleFrames.delNfcHex(index), label: 'delNfc');
  }

  Future<bool> _write(String hex, {required String label}) async {
    if (!canWriteOfficialNfc) {
      _log.operation(
        '官方 NFC 写入跳过（需 standard LOGIN）',
        detail: label,
        level: LogLevel.warning,
      );
      return false;
    }
    final ok = await connectionManager.writeStandardHex(hex);
    _log.operation(
      ok ? '官方 NFC 指令已发送: $label' : '官方 NFC 指令失败: $label',
      detail: hex,
      level: ok ? LogLevel.info : LogLevel.warning,
    );
    return ok;
  }
}
