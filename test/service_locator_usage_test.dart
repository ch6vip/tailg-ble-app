import 'package:flutter_test/flutter_test.dart';

import 'helpers/source_scan.dart';

const _sourceRoots = ['lib/pages', 'lib/widgets'];

void main() {
  test(
    'pages and widgets use service locator getters instead of constructors',
    () {
      final directServiceConstructor = RegExp(
        r'\b[A-Z][A-Za-z0-9]+Service\(\)',
      );
      final offenders = patternOffenders(
        _sourceRoots.expand(dartFilesUnder),
        directServiceConstructor,
      );

      expect(
        offenders,
        isEmpty,
        reason:
            'Use top-level getters from main.dart so AppServices.override '
            'can swap the service graph in tests.',
      );
    },
  );

  test('pages and widgets route snack messages through AppSnack', () {
    final rawSnackUsage = RegExp(
      r'ScaffoldMessenger|showSnackBar\s*\(|\bSnackBar\s*\(',
    );
    final offenders = patternOffenders(
      _sourceRoots
          .expand(dartFilesUnder)
          .where((file) => !file.path.endsWith('app_snack.dart')),
      rawSnackUsage,
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Use AppSnack so snack styling, icons, and theme colors stay '
          'centralized.',
    );
  });
}
