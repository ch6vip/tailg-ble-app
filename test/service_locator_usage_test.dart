import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pages and widgets use service locator getters instead of constructors',
    () {
      final directServiceConstructor = RegExp(
        r'\b[A-Z][A-Za-z0-9]+Service\(\)',
      );
      final offenders = <String>[];

      for (final root in [Directory('lib/pages'), Directory('lib/widgets')]) {
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final source = entity.readAsStringSync();
          final matches = directServiceConstructor.allMatches(source);
          for (final match in matches) {
            final line = _lineNumber(source, match.start);
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

    for (final root in [Directory('lib/pages'), Directory('lib/widgets')]) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('app_snack.dart')) continue;
        final source = entity.readAsStringSync();
        final matches = rawSnackUsage.allMatches(source);
        for (final match in matches) {
          final line = _lineNumber(source, match.start);
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

int _lineNumber(String source, int offset) {
  return '\n'.allMatches(source.substring(0, offset)).length + 1;
}
