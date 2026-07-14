import 'dart:async';

import 'package:flutter/foundation.dart';

/// Shared SMS resend countdown used by login and official-cloud auth UIs.
///
/// Exposes [remaining] as a [ValueListenable] so widgets can rebuild without
/// owning timer state. Call [dispose] from the host State.
class SmsCountdown {
  SmsCountdown({this.durationSeconds = 60});

  final int durationSeconds;
  final ValueNotifier<int> remaining = ValueNotifier<int>(0);
  Timer? _timer;

  bool get isActive => remaining.value > 0;

  void start({bool Function()? isMounted}) {
    _timer?.cancel();
    remaining.value = durationSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isMounted != null && !isMounted()) {
        timer.cancel();
        return;
      }
      if (remaining.value <= 1) {
        timer.cancel();
        remaining.value = 0;
      } else {
        remaining.value--;
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    remaining.dispose();
  }
}
