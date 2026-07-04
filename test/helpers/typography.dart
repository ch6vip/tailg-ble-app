import 'package:flutter_test/flutter_test.dart';

final Matcher nonNegativeLetterSpacing = anyOf(isNull, greaterThanOrEqualTo(0));
