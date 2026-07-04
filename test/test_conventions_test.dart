import 'dart:io';

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
      final source = File(path).readAsStringSync();
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
