import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/theme/app_void.dart';
import 'package:tailg_ble_app/widgets/app_snack.dart';
import 'package:tailg_ble_app/widgets/lucide_icon.dart';

void main() {
  testWidgets('AppSnack uses VOID energy palette', (tester) async {
    await _pumpSnack(
      tester,
      message: 'error',
      icon: Lucide.alertCircle,
      show: (context) => AppSnack.error(
        context,
        'error',
        actionLabel: 'UNDO',
        onAction: () {},
      ),
      expectedBackground: VoidColors.energyRed,
      expectedForeground: Colors.white,
      expectAction: true,
    );

    await _pumpSnack(
      tester,
      message: 'success',
      icon: Lucide.checkCircle,
      show: (context) => AppSnack.success(context, 'success'),
      expectedBackground: VoidColors.energy,
      expectedForeground: Colors.black,
    );

    await _pumpSnack(
      tester,
      message: 'info',
      icon: Lucide.info,
      show: (context) => AppSnack.info(context, 'info'),
      expectedBackground: VoidColors.voidPanelHi,
      expectedForeground: VoidColors.ink,
    );

    await _pumpSnack(
      tester,
      message: '导航投屏暂未开放，可先使用官方云端控车',
      icon: Lucide.info,
      show: (context) => AppSnack.featureUnavailable(context, '导航投屏'),
      expectedBackground: VoidColors.voidPanelHi,
      expectedForeground: VoidColors.ink,
    );

    await _pumpSnack(
      tester,
      message: '用户协议暂未开放',
      icon: Lucide.info,
      show: (context) => AppSnack.notYetOpen(context, '用户协议'),
      expectedBackground: VoidColors.voidPanelHi,
      expectedForeground: VoidColors.ink,
    );
  });
}

Future<void> _pumpSnack(
  WidgetTester tester, {
  required String message,
  required IconData icon,
  required void Function(BuildContext context) show,
  required Color expectedBackground,
  required Color expectedForeground,
  bool expectAction = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => show(context),
              child: const Text('show'),
            );
          },
        ),
      ),
    ),
  );

  await tester.tap(find.text('show'));
  await tester.pump();

  final snack = tester.widget<SnackBar>(find.byType(SnackBar));
  expect(snack.backgroundColor, expectedBackground);

  final snackIcon = tester.widget<Icon>(find.byIcon(icon));
  expect(snackIcon.color, expectedForeground);

  final snackText = tester.widget<Text>(find.text(message));
  expect(snackText.style?.color, expectedForeground);

  if (expectAction) {
    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    expect(action.textColor, expectedForeground);
  }
}
