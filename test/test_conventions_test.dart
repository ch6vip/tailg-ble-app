import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('snack icon assertions use snackIcon helper', () {
    final directSnackIconFinder = RegExp(
      r'find\.byIcon\(Icons\.(info_outline|check_circle_outline|error_outline)\)',
    );
    final offenders = <String>[];

    for (final entity in Directory('test').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
      if (entity.path.endsWith('test_conventions_test.dart')) continue;
      final source = entity.readAsStringSync();
      final matches = directSnackIconFinder.allMatches(source);
      for (final match in matches) {
        final line = _lineNumber(source, match.start);
        offenders.add('${entity.path}:$line ${match.group(0)}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use snackIcon(...) from test/helpers/snack_finders.dart for '
          'SnackBar icon assertions so tests keep matching AppSnack structure.',
    );
  });

  test('press feedback scale uses AppMotion token', () {
    final hardcodedPressScale = RegExp(
      r'(pressedScale:\s*0\.\d+|scale:\s*[^,\n]*\?\s*0\.\d+\s*:\s*1)',
    );
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      final matches = hardcodedPressScale.allMatches(source);
      for (final match in matches) {
        final line = _lineNumber(source, match.start);
        offenders.add('${entity.path}:$line ${match.group(0)}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use AppMotion.pressScale for press feedback so interaction motion '
          'stays consistent across widgets.',
    );
  });
}

int _lineNumber(String source, int offset) {
  return '\n'.allMatches(source.substring(0, offset)).length + 1;
}
