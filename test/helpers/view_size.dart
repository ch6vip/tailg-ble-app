import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void setTestViewSize(WidgetTester tester, Size size) {
  applyTestViewSize(tester, size);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void applyTestViewSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
}
