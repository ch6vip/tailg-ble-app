import '../models/official_vehicle.dart';
import 'constants.dart';

enum OfficialBleStack { kks, tlink, qgj, unsupported }

/// Runtime-only BLE inputs copied from the official vehicle response.
///
/// Passwords and uid are deliberately not serialised. The official app keeps
/// them in its active vehicle/session object while connecting the selected car.
class OfficialBleConnectionContext {
  final OfficialBleStack stack;
  final int modelType;
  final ModelType? cipherModel;
  final String identityMac;
  final String advertisedName;
  final String userId;
  final int? mainPassword;
  final List<int> childPasswords;
  final bool shared;

  const OfficialBleConnectionContext({
    required this.stack,
    required this.modelType,
    required this.cipherModel,
    required this.identityMac,
    required this.advertisedName,
    required this.userId,
    required this.mainPassword,
    required this.childPasswords,
    required this.shared,
  });

  factory OfficialBleConnectionContext.fromVehicle(
    OfficialVehicle vehicle, {
    required String userId,
  }) {
    final modelType = vehicle.modelType ?? -1;
    final stack = stackForModelType(modelType);
    return OfficialBleConnectionContext(
      stack: stack,
      modelType: modelType,
      cipherModel: cipherModelForModelType(modelType),
      identityMac: vehicle.bleIdentityMac,
      advertisedName: vehicle.btname.trim(),
      userId: userId.trim(),
      mainPassword: vehicle.mainBlePassword,
      childPasswords: vehicle.childBlePasswords,
      shared: vehicle.shareCarFlag,
    );
  }

  static OfficialBleStack stackForModelType(int modelType) {
    if (modelType == 1) return OfficialBleStack.kks;
    if ({
      3,
      10,
      14,
      401,
      928,
      1501,
      1601,
      1701,
      2103,
      2201,
    }.contains(modelType)) {
      return OfficialBleStack.tlink;
    }
    if ({8, 283}.contains(modelType)) return OfficialBleStack.qgj;
    return OfficialBleStack.unsupported;
  }

  /// The official TLink implementation uses a fixed key per model family.
  static ModelType? cipherModelForModelType(int modelType) {
    return switch (modelType) {
      1 => ModelType.KKS,
      3 || 401 => ModelType.BB,
      10 || 14 || 928 => ModelType.JW,
      1501 => ModelType.JD,
      1601 => ModelType.AX,
      1701 => ModelType.HJ,
      2103 => ModelType.XL,
      2201 => ModelType.YY,
      _ => null,
    };
  }

  bool get hasTLinkCredentials =>
      stack == OfficialBleStack.tlink &&
      userIdValue != null &&
      selectedPassword != null;

  bool get hasQgjCredentials =>
      stack == OfficialBleStack.qgj &&
      userIdValue != null &&
      selectedPassword != null;

  int? get userIdValue => int.tryParse(userId);

  int? get selectedPassword {
    if (shared) {
      return childPasswords.isEmpty ? null : childPasswords.first;
    }
    return mainPassword;
  }

  String get targetMacCompact =>
      identityMac.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
}
