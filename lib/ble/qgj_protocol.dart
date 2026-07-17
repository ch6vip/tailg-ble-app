import 'dart:typed_data';
import 'constants.dart';

Uint8List buildQgjLoginFrame({int password = 0, int userId = 0}) {
  final payload = Uint8List(8);
  final view = ByteData.sublistView(payload);
  view.setUint32(0, password & 0xFFFFFFFF, Endian.big);
  view.setUint32(4, userId & 0xFFFFFFFF, Endian.big);

  return buildQgjCommand(QgjCommandIds.login, payload);
}

Uint8List buildQgjCommand(int cmdId, [Uint8List? payload]) {
  payload ??= Uint8List(0);
  final length = payload.length + 2;
  final frame = Uint8List(4 + 2 + payload.length);
  frame[0] = 0xA7;
  frame[1] = 0x00;
  frame[2] = (length >> 8) & 0xFF;
  frame[3] = length & 0xFF;
  frame[4] = (cmdId >> 8) & 0xFF;
  frame[5] = cmdId & 0xFF;
  frame.setRange(6, frame.length, payload);
  return frame;
}

Uint8List buildQgjUInt8Payload(int value) {
  return Uint8List.fromList([value & 0xFF]);
}

Uint8List buildQgjUInt16Payload(int value) {
  final payload = Uint8List(2);
  ByteData.sublistView(payload).setUint16(0, value & 0xFFFF, Endian.big);
  return payload;
}

Uint8List buildQgjSwitchPayload(bool enabled) {
  return Uint8List.fromList([enabled ? 1 : 0]);
}

Uint8List buildQgjAutoLockPayload(bool enabled) {
  return buildQgjUInt16Payload(enabled ? 45 : 0);
}

Uint8List buildQgjHidPayload(int mode) {
  return buildQgjUInt8Payload(mode);
}

Uint8List? buildQgjControlFrame(CommandCode cmd) {
  final opCode = QgjControlOpCodes.byCommandCode[cmd.code];
  if (opCode == null) return null;
  return buildQgjCommand(QgjCommandIds.setStatus, Uint8List.fromList([opCode]));
}

class QgjResponse {
  final int cmdId;
  final Uint8List payload;
  final bool success;

  const QgjResponse({
    required this.cmdId,
    required this.payload,
    required this.success,
  });
}

QgjResponse? parseQgjResponse(Uint8List data) {
  if (data.length < 6 || data[0] != 0xA7) return null;
  final length = (data[2] << 8) | data[3];
  if (length != data.length - 4) return null;
  final cmdId = (data[4] << 8) | data[5];
  final payload = data.sublist(6);
  final statusNibble = (data[1] >> 4) & 0x0F;
  return QgjResponse(
    cmdId: cmdId,
    payload: payload,
    success: statusNibble == 0,
  );
}
