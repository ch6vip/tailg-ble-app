import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/widgets/app_toast.dart';

void main() {
  tearDown(AppToast.dismiss);

  testWidgets('toast dismiss keeps a 44dp touch target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppToast.navigatorKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    AppToast.show('测试 Toast');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final dismiss = find.byKey(const ValueKey('app-toast-dismiss'));
    expect(dismiss, findsOneWidget);
    expect(tester.getSize(dismiss).height, greaterThanOrEqualTo(44));

    await tester.tap(dismiss);
    await tester.pump();

    expect(find.text('测试 Toast'), findsNothing);
  });
}
