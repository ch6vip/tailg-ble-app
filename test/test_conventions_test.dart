import 'package:flutter_test/flutter_test.dart';

import 'helpers/source_scan.dart';

void main() {
  test('snack icon assertions use snackIcon helper', () {
    final directSnackIconFinder = RegExp(
      r'find\.byIcon\(Icons\.(info_outline|check_circle_outline|error_outline)\)',
    );
    final offenders = patternOffenders(
      dartFilesUnder('test')
          .where((file) => file.path.endsWith('_test.dart'))
          .where((file) => !file.path.endsWith('test_conventions_test.dart')),
      directSnackIconFinder,
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Use snackIcon(...) from test/helpers/snack_finders.dart for '
          'SnackBar icon assertions so tests keep matching AppSnack structure.',
    );
  });

  test('user-visible messages do not expose raw exception text', () {
    final rawExceptionInVisibleText = RegExp(
      r'(AppSnack\.(?:error|info|success)\([^\n;]*(?:\$e|e\.toString\(\))'
      r'|SnackBar\([^\n;]*(?:\$e|e\.toString\(\))'
      r'|Text\([^\n;]*(?:\$e|e\.toString\(\)))',
    );
    final offenders = patternOffenders(
      dartFilesUnder('lib'),
      rawExceptionInVisibleText,
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Use stable user-facing copy for SnackBar/Text messages; keep raw '
          'exception details in LogService where redaction is centralized.',
    );
  });

  test('touch target height assertions use helper', () {
    final directTouchTargetAssertion = RegExp(
      r'tester\.getSize\([^)]+\)\.height,\s*greaterThanOrEqualTo\(44\)',
      multiLine: true,
    );
    final offenders = patternOffenders(
      dartFilesUnder('test')
          .where((file) => file.path.endsWith('_test.dart'))
          .where((file) => !file.path.endsWith('test_conventions_test.dart')),
      directTouchTargetAssertion,
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Use expectMinTouchTargetHeight(...) from '
          'test/helpers/touch_target.dart for 44dp target assertions.',
    );
  });

  test('custom touch target literals use AppTouchTargets token', () {
    final hardcodedTouchTarget = RegExp(
      r'(minWidth:\s*44|minHeight:\s*44|width:\s*44,\s*|height:\s*44,\s*|SizedBox\(height:\s*44)',
    );
    final offenders = patternOffenders(
      dartFilesUnder('lib'),
      hardcodedTouchTarget,
    );

    expect(
      offenders,
      isEmpty,
      reason: 'Use AppTouchTargets.min for compact 44dp custom hit targets.',
    );
  });

  test('pill radius literals use AppRadii token', () {
    final hardcodedPillRadius = RegExp(
      r'(BorderRadius|Radius)\.circular\(\s*999\s*\)',
    );
    final offenders = patternOffenders(
      dartFilesUnder('lib'),
      hardcodedPillRadius,
    );

    expect(
      offenders,
      isEmpty,
      reason: 'Use AppRadii.pill for fully rounded pill shapes.',
    );
  });

  test('common radius literals use AppRadii tokens', () {
    final hardcodedCommonRadius = RegExp(
      r'(BorderRadius|Radius)\.circular\(\s*(6|8|10|12|14|18|20)\s*\)',
    );
    final offenders = patternOffenders(
      dartFilesUnder('lib'),
      hardcodedCommonRadius,
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Use AppRadii.xs/tile/sm/card/md/sheet/lg for common rounded corners.',
    );
  });

  test('known color literals use AppColors tokens', () {
    final knownTokenColor = RegExp(
      r'Color\(0xFF(EFF0F5|E5E5E5|E8ECF1|F6F8FB|1B2230|F5A623)\)',
    );
    final offenders = patternOffenders(
      dartFilesUnder('lib').where(
        (file) => !_normalizedPath(file.path).endsWith('theme/app_colors.dart'),
      ),
      knownTokenColor,
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Use the existing AppColors token for known design-system colors.',
    );
  });

  test('widget tests use view size helpers', () {
    final directViewSizeSet = RegExp(r'tester\.view\.physicalSize\s*=');
    final offenders = patternOffenders(
      dartFilesUnder('test')
          .where((file) => file.path.endsWith('.dart'))
          .where(
            (file) =>
                !_normalizedPath(file.path).endsWith('helpers/view_size.dart'),
          ),
      directViewSizeSet,
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Use setTestViewSize(...) or applyTestViewSize(...) from '
          'test/helpers/view_size.dart so devicePixelRatio stays explicit.',
    );
  });

  test('platform channel mocks use helper', () {
    final directPlatformMock = RegExp(r'\.setMockMethodCallHandler\(');
    final offenders = patternOffenders(
      dartFilesUnder('test')
          .where((file) => file.path.endsWith('.dart'))
          .where(
            (file) => !_normalizedPath(
              file.path,
            ).endsWith('helpers/platform_mocks.dart'),
          ),
      directPlatformMock,
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Use mockClipboardWrites()/clearPlatformChannelMock() from '
          'test/helpers/platform_mocks.dart for platform channel mocks.',
    );
  });

  test('empty storage mocks use reset helpers', () {
    final directEmptyStorageMock = RegExp(
      r'(SharedPreferences|FlutterSecureStorage)'
      r'\.setMockInitialValues\(\s*\{\s*\}\s*\)',
    );
    final offenders = patternOffenders(
      dartFilesUnder('test')
          .where((file) => file.path.endsWith('.dart'))
          .where(
            (file) => !_normalizedPath(
              file.path,
            ).endsWith('helpers/storage_mocks.dart'),
          ),
      directEmptyStorageMock,
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Use resetMockPreferences(), resetMockSecureStorage(), or '
          'resetMockStorage() from test/helpers/storage_mocks.dart for empty '
          'test storage state.',
    );
  });

  test('press feedback scale uses AppMotion token', () {
    final hardcodedPressScale = RegExp(
      r'(pressedScale:\s*0\.\d+|scale:\s*[^,\n]*\?\s*0\.\d+\s*:\s*1)',
    );
    final offenders = patternOffenders(
      dartFilesUnder('lib'),
      hardcodedPressScale,
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Use AppMotion.pressScale for press feedback so interaction motion '
          'stays consistent across widgets.',
    );
  });

  test('pulse animation literals stay in AppMotion', () {
    final hardcodedPulseLiteral = RegExp(
      r'(duration:\s*const Duration\(milliseconds:\s*1200\)|begin:\s*0\.75|end:\s*1\.1)',
    );
    final offenders = patternOffenders(
      dartFilesUnder('lib').where(
        (file) => !_normalizedPath(file.path).endsWith('theme/app_motion.dart'),
      ),
      hardcodedPulseLiteral,
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Use AppMotion.pulsePeriod, AppMotion.pulseMin, and '
          'AppMotion.pulseMax for breathing/pulse animations.',
    );
  });

  test('toast timing literals stay in AppMotion', () {
    final hardcodedToastTiming = RegExp(r'Duration\(milliseconds:\s*1800\)');
    final offenders = patternOffenders(
      dartFilesUnder('lib').where(
        (file) => !_normalizedPath(file.path).endsWith('theme/app_motion.dart'),
      ),
      hardcodedToastTiming,
    );

    expect(
      offenders,
      isEmpty,
      reason: 'Use AppMotion.toastVisible for toast auto-dismiss timing.',
    );
  });

  test('page tab indicator timing stays in AppMotion', () {
    final hardcodedTabIndicatorTiming = RegExp(
      r'duration:\s*const\s+Duration\(milliseconds:\s*200\)',
    );
    final offenders = patternOffenders(
      dartFilesUnder('lib/pages').where((file) {
        final path = _normalizedPath(file.path);
        return path.endsWith('pages/log_page.dart') ||
            path.endsWith('pages/vehicle_message_page.dart');
      }),
      hardcodedTabIndicatorTiming,
    );

    expect(
      offenders,
      isEmpty,
      reason: 'Use AppMotion.tabIndicator for page-level tab indicators.',
    );
  });

  test('InkWell widgets are not nested inside another InkWell', () {
    final offenders = <String>[];

    for (final entity in dartFilesUnder('lib')) {
      final source = entity.readAsStringSync();
      final nestedOffsets = _nestedConstructorOffsets(source, 'InkWell');
      for (final offset in nestedOffsets) {
        final line = lineNumber(source, offset);
        offenders.add('${entity.path}:$line nested InkWell');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Avoid nested InkWell hit regions; use one InkWell boundary or split '
          'outer handling into GestureDetector/AppPressable.',
    );
  });

  test('library code does not use wildcard catch variables', () {
    final wildcardCatch = RegExp(r'\bcatch\s*\(\s*_\s*(?:,\s*_\s*)?\)');
    final offenders = patternOffenders(dartFilesUnder('lib'), wildcardCatch);

    expect(
      offenders,
      isEmpty,
      reason:
          'Use a typed on-clause, log the failure, or document intentional '
          'degradation instead of swallowing catch (_) silently.',
    );
  });

  test('GATT device information reads log best-effort failures', () {
    const pages = [
      'lib/pages/device_info_page.dart',
      'lib/pages/ota_precheck_page.dart',
    ];

    for (final path in pages) {
      final source = readSource(path);
      expect(source, isNot(contains('catch (_)')), reason: path);
      expect(source, contains('GATT 字段读取失败'), reason: path);
      expect(source, contains('LogLevel.debug'), reason: path);
    }
  });
}

List<int> _nestedConstructorOffsets(String source, String constructorName) {
  final nestedOffsets = <int>[];
  final activeConstructorDepths = <int>[];
  var depth = 0;

  for (var index = 0; index < source.length; index++) {
    final skippedTo = _skipCommentOrString(source, index);
    if (skippedTo != null) {
      index = skippedTo;
      continue;
    }

    if (_startsConstructorCall(source, index, constructorName)) {
      final openParen = _nextNonWhitespace(
        source,
        index + constructorName.length,
      );
      if (openParen != null && source.codeUnitAt(openParen) == 0x28) {
        if (activeConstructorDepths.isNotEmpty) nestedOffsets.add(index);
        depth++;
        activeConstructorDepths.add(depth);
        index = openParen;
        continue;
      }
    }

    final codeUnit = source.codeUnitAt(index);
    if (codeUnit == 0x28) {
      depth++;
    } else if (codeUnit == 0x29) {
      while (activeConstructorDepths.isNotEmpty &&
          activeConstructorDepths.last == depth) {
        activeConstructorDepths.removeLast();
      }
      if (depth > 0) depth--;
    }
  }

  return nestedOffsets;
}

int? _skipCommentOrString(String source, int index) {
  if (source.startsWith('//', index)) {
    final newline = source.indexOf('\n', index + 2);
    return newline == -1 ? source.length - 1 : newline;
  }
  if (source.startsWith('/*', index)) {
    final close = source.indexOf('*/', index + 2);
    return close == -1 ? source.length - 1 : close + 1;
  }

  final codeUnit = source.codeUnitAt(index);
  if (codeUnit != 0x22 && codeUnit != 0x27) return null;

  final isTripleQuoted =
      index + 2 < source.length &&
      source.codeUnitAt(index + 1) == codeUnit &&
      source.codeUnitAt(index + 2) == codeUnit;
  if (isTripleQuoted) {
    final quoteChar = String.fromCharCode(codeUnit);
    final quote = '$quoteChar$quoteChar$quoteChar';
    final close = source.indexOf(quote, index + 3);
    return close == -1 ? source.length - 1 : close + 2;
  }

  for (var cursor = index + 1; cursor < source.length; cursor++) {
    final cursorCodeUnit = source.codeUnitAt(cursor);
    if (cursorCodeUnit == 0x5C) {
      cursor++;
      continue;
    }
    if (cursorCodeUnit == codeUnit) return cursor;
  }
  return source.length - 1;
}

bool _startsConstructorCall(String source, int index, String constructorName) {
  if (!source.startsWith(constructorName, index)) return false;

  final before = index == 0 ? null : source.codeUnitAt(index - 1);
  final afterIndex = index + constructorName.length;
  final after = afterIndex >= source.length
      ? null
      : source.codeUnitAt(afterIndex);

  return !_isIdentifierCodeUnit(before) && !_isIdentifierCodeUnit(after);
}

int? _nextNonWhitespace(String source, int start) {
  for (var index = start; index < source.length; index++) {
    final codeUnit = source.codeUnitAt(index);
    if (codeUnit != 0x20 &&
        codeUnit != 0x09 &&
        codeUnit != 0x0A &&
        codeUnit != 0x0D) {
      return index;
    }
  }
  return null;
}

bool _isIdentifierCodeUnit(int? codeUnit) {
  if (codeUnit == null) return false;
  return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
      codeUnit == 0x5F;
}

String _normalizedPath(String path) => path.replaceAll(r'\', '/');
