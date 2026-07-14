import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/sms_countdown.dart';

void main() {
  test('SmsCountdown starts active and can be restarted after dispose lifecycle', () {
    final countdown = SmsCountdown(durationSeconds: 3);
    addTearDown(countdown.dispose);

    expect(countdown.isActive, isFalse);
    expect(countdown.remaining.value, 0);

    countdown.start();
    expect(countdown.isActive, isTrue);
    expect(countdown.remaining.value, 3);

    // Completing the countdown marks it inactive for the resend button.
    countdown.remaining.value = 0;
    expect(countdown.isActive, isFalse);

    countdown.start(isMounted: () => true);
    expect(countdown.remaining.value, 3);
    expect(countdown.isActive, isTrue);
  });

  test('SmsCountdown restart replaces previous remaining seconds', () {
    final countdown = SmsCountdown(durationSeconds: 60);
    addTearDown(countdown.dispose);

    countdown.start();
    expect(countdown.remaining.value, 60);
    countdown.remaining.value = 12;

    countdown.start();
    expect(countdown.remaining.value, 60);
  });
}
