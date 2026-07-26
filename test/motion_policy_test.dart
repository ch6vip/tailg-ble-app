import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/theme/motion_policy.dart';

void main() {
  testWidgets('motion policy combines accessibility and ticker visibility', (
    tester,
  ) async {
    bool? reducedLoops;
    Duration? reducedDuration;
    bool? hiddenLoops;
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(
                builder: (context) {
                  reducedLoops = MotionPolicy.loopsEnabled(context);
                  reducedDuration = MotionPolicy.duration(
                    context,
                    const Duration(milliseconds: 240),
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
            TickerMode(
              enabled: false,
              child: Builder(
                builder: (context) {
                  hiddenLoops = MotionPolicy.loopsEnabled(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );

    expect(reducedLoops, isFalse);
    expect(reducedDuration, Duration.zero);
    expect(hiddenLoops, isFalse);
  });
}
