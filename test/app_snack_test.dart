import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/widgets/app_snack.dart';

void main() {
  testWidgets('AppSnack resolves colors from theme colorScheme', (
    tester,
  ) async {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);

    await _pumpSnack(
      tester,
      scheme: scheme,
      message: 'error',
      icon: Icons.error_outline,
      show: (context) => AppSnack.error(
        context,
        'error',
        actionLabel: 'UNDO',
        onAction: () {},
      ),
      expectedBackground: scheme.error,
      expectedForeground: scheme.onError,
      expectAction: true,
    );

    await _pumpSnack(
      tester,
      scheme: scheme,
      message: 'success',
      icon: Icons.check_circle_outline,
      show: (context) => AppSnack.success(context, 'success'),
      expectedBackground: scheme.primary,
      expectedForeground: scheme.onPrimary,
    );

    await _pumpSnack(
      tester,
      scheme: scheme,
      message: 'info',
      icon: Icons.info_outline,
      show: (context) => AppSnack.info(context, 'info'),
      expectedBackground: scheme.inverseSurface,
      expectedForeground: scheme.onInverseSurface,
    );

    await _pumpSnack(
      tester,
      scheme: scheme,
      message: '导航投屏暂未开放，可先使用官方云端控车',
      icon: Icons.info_outline,
      show: (context) => AppSnack.featureUnavailable(context, '导航投屏'),
      expectedBackground: scheme.inverseSurface,
      expectedForeground: scheme.onInverseSurface,
    );
  });
}

Future<void> _pumpSnack(
  WidgetTester tester, {
  required ColorScheme scheme,
  required String message,
  required IconData icon,
  required void Function(BuildContext context) show,
  required Color expectedBackground,
  required Color expectedForeground,
  bool expectAction = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorScheme: scheme),
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
