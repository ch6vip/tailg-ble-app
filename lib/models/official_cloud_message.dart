class OfficialCloudMessage {
  final String id;
  final String title;
  final String content;
  final DateTime time;
  final OfficialCloudMessageCategory category;
  final String messageCode;
  final String carId;
  final String? url;

  const OfficialCloudMessage({
    required this.id,
    required this.title,
    required this.content,
    required this.time,
    required this.category,
    this.messageCode = '',
    this.carId = '',
    this.url,
  });

  factory OfficialCloudMessage.vehicle(Map<String, dynamic> json) {
    final id = _firstNonEmpty([
      json['msgId'],
      json['carProblemMessageRecordId'],
      json['carProblemMessageInfoId'],
    ]);
    return OfficialCloudMessage(
      id: id.isEmpty ? _fallbackId(json, 'vehicle') : 'vehicle:$id',
      title: _clean(json['title']) ?? '车辆消息',
      content: _clean(json['content']) ?? '',
      time: _parseMessageTime(json['sendTime']),
      category: OfficialCloudMessageCategory.vehicle,
      messageCode: _clean(json['messageCode']) ?? '',
      carId: _clean(json['carId']) ?? '',
    );
  }

  factory OfficialCloudMessage.system(Map<String, dynamic> json) {
    final id = _firstNonEmpty([
      json['sysMessageRecordId'],
      json['sysMessageInfoId'],
      json['messageCode'],
    ]);
    return OfficialCloudMessage(
      id: id.isEmpty ? _fallbackId(json, 'system') : 'system:$id',
      title: _clean(json['title']) ?? '系统消息',
      content: _clean(json['content'] ?? json['description']) ?? '',
      time: _parseMessageTime(json['sendTime']),
      category: OfficialCloudMessageCategory.system,
      messageCode: _clean(json['messageCode']) ?? '',
      url: _clean(json['url']),
    );
  }

  static String _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = _clean(value);
      if (text != null && text.isNotEmpty) return text;
    }
    return '';
  }

  static String _fallbackId(Map<String, dynamic> json, String prefix) {
    final title = _clean(json['title']) ?? '';
    final content = _clean(json['content']) ?? '';
    final sendTime = _clean(json['sendTime']) ?? '';
    return '$prefix:${title.hashCode}_${content.hashCode}_$sendTime';
  }
}

enum OfficialCloudMessageCategory {
  vehicle('设备消息'),
  system('系统消息');

  final String label;
  const OfficialCloudMessageCategory(this.label);
}

String? _clean(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text == '--' || text.toLowerCase() == 'null') {
    return null;
  }
  return text;
}

DateTime _parseMessageTime(Object? value) {
  final text = _clean(value);
  if (text == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
  return parsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
