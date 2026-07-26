enum OfficialRidePeriod { day, week, month }

extension OfficialRidePeriodDisplay on OfficialRidePeriod {
  String get wireName => switch (this) {
    OfficialRidePeriod.day => 'days',
    OfficialRidePeriod.week => 'weeks',
    OfficialRidePeriod.month => 'months',
  };

  String get tabLabel => switch (this) {
    OfficialRidePeriod.day => '天',
    OfficialRidePeriod.week => '周',
    OfficialRidePeriod.month => '月',
  };

  String get carbonTitle => switch (this) {
    OfficialRidePeriod.day => '日节碳量',
    OfficialRidePeriod.week => '周节碳量',
    OfficialRidePeriod.month => '月节碳量',
  };

  String get mileageTitle => switch (this) {
    OfficialRidePeriod.day => '今日里程',
    OfficialRidePeriod.week => '本周里程',
    OfficialRidePeriod.month => '本月里程',
  };

  String requestKey(DateTime now) {
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    return switch (this) {
      OfficialRidePeriod.day =>
        '$year$month${now.day.toString().padLeft(2, '0')}',
      OfficialRidePeriod.week =>
        '$year$month${officialIsoWeekNumber(now).toString().padLeft(2, '0')}',
      OfficialRidePeriod.month => '$year$month',
    };
  }
}

/// Official `app/appRiding/getRidingDetail` response payload.
class OfficialRideStatistics {
  const OfficialRideStatistics({
    required this.avgSpeed,
    required this.carbonAbsorption,
    required this.carbonSaving,
    required this.dayMileage,
    required this.maxSpeed,
    required this.monthsMileage,
    required this.ridingCount,
    required this.ridingTime,
    required this.totalMileage,
    required this.weekMileage,
    required this.yearMileage,
  });

  factory OfficialRideStatistics.fromJson(Map<String, dynamic> json) {
    String value(String key) => json[key]?.toString().trim() ?? '';

    return OfficialRideStatistics(
      avgSpeed: value('avgSpeed'),
      carbonAbsorption: value('carbonAbsorption'),
      carbonSaving: value('carbonSaving'),
      dayMileage: value('dayMileage'),
      maxSpeed: value('maxSpeed'),
      monthsMileage: value('monthsMileage'),
      ridingCount: value('ridingCount'),
      ridingTime: value('ridingTime'),
      totalMileage: value('totalMileage'),
      weekMileage: value('weekMileage'),
      yearMileage: value('yearMileage'),
    );
  }

  final String avgSpeed;
  final String carbonAbsorption;
  final String carbonSaving;
  final String dayMileage;
  final String maxSpeed;
  final String monthsMileage;
  final String ridingCount;
  final String ridingTime;
  final String totalMileage;
  final String weekMileage;
  final String yearMileage;

  String mileageFor(OfficialRidePeriod period) => switch (period) {
    OfficialRidePeriod.day => dayMileage,
    OfficialRidePeriod.week => weekMileage,
    OfficialRidePeriod.month => monthsMileage,
  };

  static String displayValue(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? '--' : normalized;
  }

  /// The official binding treats mileage fields as meters, drops the decimal
  /// part, then converts to kilometres with two digits rounded down.
  static String formatMileageKm(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '--';
    final wholeMeters =
        int.tryParse(normalized.split('.').first) ??
        double.tryParse(normalized)?.truncate();
    if (wholeMeters == null) return '--';
    final truncatedHundredths = wholeMeters * 100 ~/ 1000;
    return (truncatedHundredths / 100).toStringAsFixed(2);
  }
}

/// Matches Java Calendar's Monday-first, seven-day minimum first week used by
/// the official app's `TimeUtil.getCurTimeYMW()`.
int officialIsoWeekNumber(DateTime value) {
  final date = DateTime.utc(value.year, value.month, value.day);
  final weekThursday = date.add(Duration(days: 4 - date.weekday));
  final januaryFourth = DateTime.utc(weekThursday.year, 1, 4);
  final firstWeekThursday = januaryFourth.add(
    Duration(days: 4 - januaryFourth.weekday),
  );
  return 1 + weekThursday.difference(firstWeekThursday).inDays ~/ 7;
}
