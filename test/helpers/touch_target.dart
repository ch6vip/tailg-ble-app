import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';

void expectMinTouchTargetHeight(
  WidgetTester tester,
  Finder finder, {
  double minHeight = AppTouchTargets.min,
}) {
  expect(tester.getSize(finder).height, greaterThanOrEqualTo(minHeight));
}
