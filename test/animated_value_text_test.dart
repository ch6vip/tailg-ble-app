import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/widgets/animated_value_text.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('value refresh cross-fades without dropping the text slot', (
    tester,
  ) async {
    var value = '18.6';
    late StateSetter update;
    await tester.pumpWidget(
      TestApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Center(
              child: AnimatedValueText(
                value,
                style: const TextStyle(fontSize: 24),
                unit: ' km',
                unitStyle: const TextStyle(fontSize: 12),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('18.6 km', findRichText: true), findsOneWidget);
    update(() => value = '21.4');
    await tester.pump();

    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.text('18.6 km', findRichText: true), findsOneWidget);
    expect(find.text('21.4 km', findRichText: true), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('18.6 km', findRichText: true), findsNothing);
    expect(find.text('21.4 km', findRichText: true), findsOneWidget);
  });

  testWidgets('system reduced motion replaces the value immediately', (
    tester,
  ) async {
    var value = '45%';
    late StateSetter update;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return AnimatedValueText(
                  value,
                  style: const TextStyle(fontSize: 20),
                );
              },
            ),
          ),
        ),
      ),
    );

    update(() => value = '46%');
    await tester.pump();

    expect(find.text('45%'), findsNothing);
    expect(find.text('46%'), findsOneWidget);
  });
}
