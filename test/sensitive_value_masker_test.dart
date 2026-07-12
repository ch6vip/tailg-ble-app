import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/sensitive_value_masker.dart';

void main() {
  test(
    'compact masks long identifiers and preserves configurable fallbacks',
    () {
      expect(SensitiveValueMasker.compact('860123456789377'), '860***377');
      expect(SensitiveValueMasker.compact(' abcdef123456 '), 'abc***456');
      expect(SensitiveValueMasker.compact(''), '***');
      expect(SensitiveValueMasker.compact('', emptyValue: 'none'), 'none');
      expect(SensitiveValueMasker.compact('  ', emptyValue: 'none'), 'none');
      expect(
        SensitiveValueMasker.compact('  ', emptyValue: 'none', trim: false),
        '***',
      );
    },
  );

  test(
    'phone masks display values while keeping caller-controlled short text',
    () {
      expect(SensitiveValueMasker.phone('18812345678'), '188****5678');
      expect(
        SensitiveValueMasker.phone('123456', shortValue: 'present'),
        'present',
      );
      expect(
        SensitiveValueMasker.phone('1234567890', minMaskLength: 11),
        '1234567890',
      );
    },
  );

  test('text redactor masks structured and standalone sensitive values', () {
    expect(
      SensitiveTextRedactor.redact(
        'phone=18886120851 token=abcdef123456 '
        'authorization=raw-secret-token Bearer bearer-secret-token '
        'AA:BB:CC:DD:EE:FF aabbccddeeff',
      ),
      'phone=188***851 token=abc***456 '
      'authorization=raw***ken Bearer bea***ken '
      'AA:***:FF aab***eff',
    );
  });
}
