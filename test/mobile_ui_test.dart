import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/login_page.dart';
import 'package:tailg_ble_app/pages/profile_mine_page.dart';
import 'package:tailg_ble_app/pages/service_hub_page.dart';
import 'package:tailg_ble_app/pages/cyber_vehicle_control_page_v2.dart';
import 'package:tailg_ble_app/services/service_locator.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';
import 'package:tailg_ble_app/theme/app_void.dart';
import 'package:tailg_ble_app/widgets/void_particles.dart';
import 'package:tailg_ble_app/widgets/void_typography.dart';

import 'helpers/storage_mocks.dart';
import 'helpers/view_size.dart';

void main() {
  setUp(() async {
    VoidParticleField.enableAnimation = false;
    KineticType.enableAnimation = false;
    resetMockStorage();
    await AppServices.reset();
  });

  tearDown(() async {
    await AppServices.reset();
    resetMockStorage();
  });

  testWidgets('Token login stays behind the alternate login action', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const LoginPage(),
      ),
    );
    await tester.pump();

    expect(find.text('手机号'), findsOneWidget);
    expect(find.text('粘贴 Token'), findsNothing);
    expect(find.text('使用 Token 登录'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('login-mode-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('粘贴 Token'), findsOneWidget);
    expect(find.text('用 Token 登录'), findsOneWidget);
    expect(find.text('返回手机号登录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'SMS get-code and login enable after typing without mode toggle',
    (tester) async {
      setTestViewSize(tester, const Size(390, 844));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const LoginPage(),
        ),
      );
      await tester.pump();

      final requestCode = find.byKey(const ValueKey('login-request-code'));
      final loginSubmit = find.byKey(const ValueKey('login-sms-submit'));
      expect(requestCode, findsOneWidget);
      expect(tester.widget<OutlinedButton>(requestCode).onPressed, isNull);
      expect(tester.widget<FilledButton>(loginSubmit).onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('login-phone-field')),
        '13800138000',
      );
      await tester.pump();

      // Must enable immediately after typing — not only after Token round-trip.
      expect(tester.widget<OutlinedButton>(requestCode).onPressed, isNotNull);
      expect(tester.widget<FilledButton>(loginSubmit).onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('login-sms-field')),
        '123456',
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(loginSubmit).onPressed, isNotNull);
    },
  );

  testWidgets('main mobile tabs use dark surfaces in system dark mode', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(390, 844));
    // Service + Mine stay VOID dark; Cyber vehicle home is light by design.
    final darkPages = [
      const ServiceHubPage(),
      const ProfileMinePage(),
    ];
    for (final page in darkPages) {
      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: _darkTheme(),
          home: page,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        anyOf(AppColorsDark.instance.pageBg, VoidColors.voidDeep),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        themeMode: ThemeMode.dark,
        darkTheme: _darkTheme(),
        home: const CyberVehicleControlPageV2(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final cyber = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(cyber.backgroundColor, const Color(0xFFF5F5F5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('login page uses dark mobile surface and remains stable', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColorsDark.instance.pageBg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColorsDark.instance.primary,
            brightness: Brightness.dark,
          ),
        ),
        home: const LoginPage(),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColorsDark.instance.pageBg);
    expect(find.text('手机号'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ThemeData _darkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColorsDark.instance.pageBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColorsDark.instance.primary,
      brightness: Brightness.dark,
    ),
  );
}
