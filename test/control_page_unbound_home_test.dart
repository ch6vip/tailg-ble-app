import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/control_page.dart';
import 'package:tailg_ble_app/pages/login_page.dart';
import 'package:tailg_ble_app/pages/vehicle_message_page.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/view_size.dart';

void main() {
  Future<void> pumpUnboundHome(WidgetTester tester) async {
    resetMockPreferences();
    VehicleStore().resetForTest();
    await VehicleStore().init();

    applyTestViewSize(tester, const Size(430, 2200));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const TestApp(home: ControlPage()));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('official unbound home shows selector and assets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpUnboundHome(tester);

      expect(find.byKey(const ValueKey('unbound-home')), findsOneWidget);
      expect(find.text('--'), findsOneWidget);
      expect(find.bySemanticsLabel('未绑定车辆'), findsOneWidget);
      expect(find.bySemanticsLabel('绑定设备'), findsOneWidget);
      expect(find.bySemanticsLabel('登录账号'), findsOneWidget);
      expect(find.bySemanticsLabel('消息'), findsOneWidget);
      expect(find.bySemanticsLabel('车辆详情'), findsOneWidget);

      expect(
        find.image(
          const AssetImage('assets/official_tailg/iv_control_evbike.png'),
        ),
        findsOneWidget,
      );
      expect(
        find.image(
          const AssetImage('assets/official_tailg/iv_uncontrol_bg.png'),
        ),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'official action buttons expose semantics and AppPressable feedback',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpUnboundHome(tester);

        for (final label in ['登录账号', '绑定设备']) {
          final semanticAction = find.bySemanticsLabel(label);
          expect(semanticAction, findsOneWidget);
          expect(
            tester.getSemantics(semanticAction),
            matchesSemantics(
              label: label,
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              hasTapAction: true,
            ),
          );
          final pressableAction = find.ancestor(
            of: semanticAction,
            matching: find.byType(AppPressable),
          );
          expect(pressableAction, findsWidgets);
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('bind action opens login page when unsigned', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpUnboundHome(tester);

      const linkLabel = '绑定设备';
      final bindAction = find.bySemanticsLabel(linkLabel);
      expect(bindAction, findsOneWidget);

      tester.semantics.tap(find.semantics.byLabel(linkLabel));
      await tester.pumpAndSettle();

      // Honest path: unsigned default -> LoginPage, no bind method sheet.
      expect(find.text('请选择绑定方式'), findsNothing);
      expect(find.text('4G功能中控'), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('login action opens login page', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpUnboundHome(tester);

      const linkLabel = '登录账号';
      final loginAction = find.bySemanticsLabel(linkLabel);
      expect(loginAction, findsOneWidget);

      tester.semantics.tap(find.semantics.byLabel(linkLabel));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('message icon opens vehicle message page', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpUnboundHome(tester);

      tester.semantics.tap(find.semantics.byLabel('消息'));
      await tester.pumpAndSettle();

      expect(find.byType(VehicleMessagePage), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('vehicle selector toast when no car', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpUnboundHome(tester);

      tester.semantics.tap(find.semantics.byLabel('切换车辆'));
      await tester.pumpAndSettle();

      expect(find.text('暂无车辆！'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
