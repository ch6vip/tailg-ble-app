import 'package:flutter_test/flutter_test.dart';

void expectMinTouchTargetHeight(
  WidgetTester tester,
  Finder finder, {
  double minHeight = 44,
}) {
  expect(tester.getSize(finder).height, greaterThanOrEqualTo(minHeight));
}
