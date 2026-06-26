import 'dart:typed_data';
import 'aes.dart';
import 'constants.dart';
import 'hex.dart';

sealed class ParsedResponse {
  final String raw;
  const ParsedResponse(this.raw);
}

class TokenResponse extends ParsedResponse {
  final String token;
  const TokenResponse(super.raw, this.token);
}

class VoltageResponse extends ParsedResponse {
  final double voltage;
  const VoltageResponse(super.raw, this.voltage);
}

class StateResponse extends ParsedResponse {
  final bool success;
  final BikeState? bikeState;
  const StateResponse(super.raw, {required this.success, this.bikeState});
}

class CommandResponse extends ParsedResponse {
  final String commandType;
  final String statusCode;
  final bool success;
  const CommandResponse(
    super.raw, {
    required this.commandType,
    required this.statusCode,
    required this.success,
  });
}

class UnknownResponse extends ParsedResponse {
  const UnknownResponse(super.raw);
}

const _tokenPrefix = '78000000';
const _voltagePrefix = '780EB310';

ParsedResponse parseResponse(String keyHex, Uint8List raw) {
  try {
    return _parseResponse(keyHex, raw);
  } on FormatException catch (_) {
    // Malformed/garbled frames (wrong length, undecryptable, too short to slice)
    // must never throw out of the notification listener and crash the app.
    return UnknownResponse(bytesToHex(raw));
  } on RangeError catch (_) {
    return UnknownResponse(bytesToHex(raw));
  } on ArgumentError catch (_) {
    // aesEcbDecrypt throws ArgumentError for empty or non-block-aligned data.
    return UnknownResponse(bytesToHex(raw));
  }
}

ParsedResponse _parseResponse(String keyHex, Uint8List raw) {
  final hex = aesEcbDecrypt(keyHex, raw);

  if (hex.length < 10) {
    return UnknownResponse(hex);
  }

  if (hex.startsWith(_tokenPrefix)) {
    // Token frame is at least 8 bytes (16 hex chars): 4-byte prefix + 4-byte
    // token. Reject short frames explicitly instead of relying on the outer
    // try/catch to swallow the RangeError from substring.
    if (hex.length < 16) {
      return UnknownResponse(hex);
    }
    final token = hex.substring(8, 16);
    return TokenResponse(hex, token);
  }

  if (hex.startsWith(_voltagePrefix) && raw.length == 16) {
    final highByte = int.parse(hex.substring(8, 10), radix: 16);
    final lowByte = int.parse(hex.substring(10, 12), radix: 16);
    final voltage = ((highByte << 8) | lowByte) / 100.0;
    return VoltageResponse(hex, voltage);
  }

  // Validate frame starts with expected header before parsing as command response
  if (!hex.startsWith('78')) {
    return UnknownResponse(hex);
  }

  final controlCode = hex.substring(6, 10);
  final commandType = controlCode.substring(0, 2);
  final statusCode = controlCode.substring(2, 4);

  if (commandType == '0C') {
    if (statusCode == 'FF') {
      return StateResponse(hex, success: false);
    }
    final stateNum = int.parse(statusCode, radix: 16);
    return StateResponse(
      hex,
      success: true,
      bikeState: BikeState(
        isLocked: stateNum == 1,
        isPowerOn: stateNum == 3 || stateNum == 4,
      ),
    );
  }

  return CommandResponse(
    hex,
    commandType: commandType,
    statusCode: statusCode,
    success: statusCode != 'FF',
  );
}
