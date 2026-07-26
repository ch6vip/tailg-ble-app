class OfficialSmartServiceStatus {
  static const expiredCode = '9';
  static const cancelledCode = '7';

  final String code;

  const OfficialSmartServiceStatus({required this.code});

  factory OfficialSmartServiceStatus.fromPayload(Object? payload) {
    if (payload is! Map) {
      return const OfficialSmartServiceStatus(code: '');
    }
    return OfficialSmartServiceStatus(
      code: payload['code']?.toString().trim() ?? '',
    );
  }

  String? get remoteControlBlockReason => switch (code) {
    expiredCode => 'VIP智能服务已到期',
    cancelledCode => '当前智能云盒已销号',
    _ => null,
  };

  OfficialSmartServiceControlDecision decisionForModelType(int? modelType) {
    final message = remoteControlBlockReason;
    if (message == null) {
      return const OfficialSmartServiceControlDecision.available();
    }
    return switch (modelType) {
      // ControlFragment's BB/default branch returns after the notice.
      3 => OfficialSmartServiceControlDecision(
        message: message,
        blocksControl: true,
      ),
      // These explicit switch branches show the notice, then still publish.
      8 ||
      10 ||
      14 ||
      283 ||
      401 ||
      928 ||
      2103 ||
      2201 => OfficialSmartServiceControlDecision(
        message: message,
        blocksControl: false,
      ),
      // KKS/YJ do not consult simQueryDetail in their control branches.
      _ => const OfficialSmartServiceControlDecision.available(),
    };
  }
}

class OfficialSmartServiceControlDecision {
  final String? message;
  final bool blocksControl;

  const OfficialSmartServiceControlDecision({
    required this.message,
    required this.blocksControl,
  });

  const OfficialSmartServiceControlDecision.available()
    : message = null,
      blocksControl = false;
}
