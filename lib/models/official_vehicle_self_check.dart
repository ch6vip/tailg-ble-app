import 'persistence_value.dart';

class OfficialVehicleSelfCheck {
  final Map<String, dynamic> raw;
  final int? code;
  final String message;
  final Object? data;

  const OfficialVehicleSelfCheck({
    required this.raw,
    required this.code,
    required this.message,
    required this.data,
  });

  factory OfficialVehicleSelfCheck.fromResponse(Map<String, dynamic> json) {
    return OfficialVehicleSelfCheck(
      raw: _stringKeyedMap(json),
      code: parsePersistedInt(json['code']),
      message: json['msg']?.toString() ?? '',
      data: json['data'],
    );
  }

  bool get hasData => data != null;

  Map<String, dynamic> get dataMap => _dataMap(data);

  String get displayMessage {
    final text = message.trim();
    if (text.isNotEmpty) return text;
    if (code != null) return 'code=$code';
    return '自检已返回';
  }
}

Map<String, dynamic> _dataMap(Object? value) {
  if (value is Map<Object?, Object?>) return _stringKeyedMap(value);
  return const {};
}

Map<String, dynamic> _stringKeyedMap(Map<Object?, Object?> value) {
  return Map<String, dynamic>.unmodifiable(parsePersistedMap(value)!);
}
