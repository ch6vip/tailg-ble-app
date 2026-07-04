import 'package:flutter_test/flutter_test.dart';

import 'helpers/source_scan.dart';

void main() {
  test(
    'pages and widgets use service locator getters instead of constructors',
    () {
      final directServiceConstructor = RegExp(
        r'\b[A-Z][A-Za-z0-9]+Service\(\)',
      );
      final offenders = <String>[];

      for (final root in const ['lib/pages', 'lib/widgets']) {
        for (final entity in dartFilesUnder(root)) {
          final source = entity.readAsStringSync();
          final matches = directServiceConstructor.allMatches(source);
          for (final match in matches) {
            final line = lineNumber(source, match.start);
            offenders.add('${entity.path}:$line ${match.group(0)}');
          }
        }
      }

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
    final offenders = <String>[];

    for (final root in const ['lib/pages', 'lib/widgets']) {
      for (final entity in dartFilesUnder(root)) {
        if (entity.path.endsWith('app_snack.dart')) continue;
        final source = entity.readAsStringSync();
        final matches = rawSnackUsage.allMatches(source);
        for (final match in matches) {
          final line = lineNumber(source, match.start);
          offenders.add('${entity.path}:$line ${match.group(0)}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use AppSnack so snack styling, icons, and theme colors stay '
          'centralized.',
    );
  });
}
