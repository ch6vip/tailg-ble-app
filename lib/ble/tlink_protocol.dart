import 'dart:typed_data';

import 'aes.dart';
import 'hex.dart';
import '../models/command_types.dart';

const _tlinkTokenPlaintext = '850000002EC97FA3518DBFE04A6F5B12';

Uint8List buildTLinkTokenRequest(String keyHex) {
  return aesEcbEncrypt(keyHex, _tlinkTokenPlaintext);
}

Uint8List buildTLinkLoginFrame({
  required String keyHex,
  required int password,
  required int userId,
  required String token,
}) {
  final frame = '850A4A11${_uint32Hex(password)}${_uint32Hex(userId)}$token';
  return aesEcbEncrypt(keyHex, frame);
}

Uint8List buildTLinkCommand({
  required String keyHex,
  required CommandCode command,
  required String token,
}) {
  final header = switch (command) {
    CommandCode.lock => '85034A20',
    CommandCode.unlock => '85034A21',
    CommandCode.powerOn => '85034A22',
    CommandCode.powerOff => '85034A23',
    CommandCode.openSeat => '85034A24',
    CommandCode.find => '85034A25',
    _ => throw ArgumentError('Unsupported TLink command: ${command.name}'),
  };
  // Official writeData fills the command to one 16-byte block before adding
  // the 4-byte token: `85034Axx00 123456789ABCDE` + token.
  return aesEcbEncrypt(
    keyHex,
    '$header'
    '00123456789ABCDE$token',
  );
}

// ---------------------------------------------------------------------------
// Induction / proximity mode (official TLinkBleManager openMode/closeMode)
//
// All plaintexts are 24 hex chars (12 bytes). ConnectionManager.writeStandardHex
// appends the 4-byte session token → 16-byte AES block, matching official
// writeData("8505…ABCDE") after LOGIN.
// ---------------------------------------------------------------------------

/// Query induction switch + distance: `checkMode()`.
const tlinkInductionCheckPlain = '85034A3301123456789ABCDE';

/// Open induction: `openMode()` → ECU then system BLE bond.
const tlinkInductionOpenPlain = '85054A3302010056789ABCDE';

/// Close induction: `closeMode()` → ECU then remove bond.
const tlinkInductionClosePlain = '85054A3302020056789ABCDE';

/// After bond success official also writes HID open (`pairingDevice` BOND_BONDED).
const tlinkHidOpenAfterBondPlain = '85044A3402003456789ABCDE';

/// Set proximity distance level (official `setModeDistance`, 1–30).
String buildTLinkInductionDistancePlain(int progress) {
  final level = progress.clamp(0, 30);
  final hex = level.toRadixString(16).padLeft(2, '0').toUpperCase();
  return '85044A3303${hex}3456789ABCDE';
}

sealed class TLinkResponse {
  final String raw;
  const TLinkResponse(this.raw);
}

class TLinkTokenResponse extends TLinkResponse {
  final String token;
  const TLinkTokenResponse(super.raw, this.token);
}

class TLinkLoginResponse extends TLinkResponse {
  final bool success;
  const TLinkLoginResponse(super.raw, this.success);
}

class TLinkCommandResponse extends TLinkResponse {
  final String commandType;
  final String statusCode;
  final bool success;
  const TLinkCommandResponse(
    super.raw, {
    required this.commandType,
    required this.statusCode,
    required this.success,
  });
}

/// `HEADER_RECEIVE_INDUCTION_STATUS` = `8506B53301`
/// switch @ [10,12): `02`=closed else open; distance @ [12,14) hex 1–30.
class TLinkInductionStatusResponse extends TLinkResponse {
  final bool enabled;
  final int? distance;
  const TLinkInductionStatusResponse(
    super.raw, {
    required this.enabled,
    required this.distance,
  });
}

/// `HEADER_RECEIVE_SET_INDUCTION_STATUS` = `8504B53302`
class TLinkInductionSetResponse extends TLinkResponse {
  final bool success;
  const TLinkInductionSetResponse(super.raw, {required this.success});
}

/// `HEADER_RECEIVE_PROXIMITYDISTANCE_SET` = `8504B53303`
class TLinkProximityDistanceSetResponse extends TLinkResponse {
  final bool success;
  const TLinkProximityDistanceSetResponse(super.raw, {required this.success});
}

class TLinkUnknownResponse extends TLinkResponse {
  const TLinkUnknownResponse(super.raw);
}

TLinkResponse parseTLinkResponse(String keyHex, Uint8List encrypted) {
  try {
    final hex = aesEcbDecrypt(keyHex, encrypted);
    if (hex.startsWith('85000000') && hex.length >= 16) {
      return TLinkTokenResponse(hex, hex.substring(8, 16));
    }
    if (hex.startsWith('8503B511') && hex.length >= 10) {
      return TLinkLoginResponse(hex, hex.substring(8, 10) == '01');
    }
    // Induction status query reply (official HEADER_RECEIVE_INDUCTION_STATUS).
    if (hex.startsWith('8506B53301') && hex.length >= 14) {
      final switchByte = hex.substring(10, 12).toUpperCase();
      final distByte = hex.substring(12, 14);
      final enabled = switchByte != '02';
      final dist = int.tryParse(distByte, radix: 16);
      final distance = (dist != null && dist > 0 && dist < 31) ? dist : null;
      return TLinkInductionStatusResponse(
        hex,
        enabled: enabled,
        distance: distance,
      );
    }
    // Induction open/close set reply.
    if (hex.startsWith('8504B53302') && hex.length >= 12) {
      return TLinkInductionSetResponse(
        hex,
        success: hex.substring(10, 12) == '01',
      );
    }
    // Proximity distance set reply.
    if (hex.startsWith('8504B53303') && hex.length >= 12) {
      return TLinkProximityDistanceSetResponse(
        hex,
        success: hex.substring(10, 12) == '01',
      );
    }
    if (hex.startsWith('8503B5') && hex.length >= 10) {
      final commandType = hex.substring(6, 8);
      final statusCode = hex.substring(8, 10);
      return TLinkCommandResponse(
        hex,
        commandType: commandType,
        statusCode: statusCode,
        success: statusCode == '01',
      );
    }
    return TLinkUnknownResponse(hex);
  } on FormatException {
    return TLinkUnknownResponse(bytesToHex(encrypted));
  } on RangeError {
    return TLinkUnknownResponse(bytesToHex(encrypted));
  } on ArgumentError {
    return TLinkUnknownResponse(bytesToHex(encrypted));
  }
}

String _uint32Hex(int value) =>
    (value & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase();
