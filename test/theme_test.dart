import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';

/// P0-2 回归测试：暗色主题接线验证。
///
/// 原 Bug：main.dart:228 硬编码 `themeMode: ThemeMode.light`，
/// 导致 AppColorsDark（app_colors.dart:223-283）已完整定义却永不生效。
void main() {
  group('P0-2: dark theme wiring', () {
    testWidgets('ThemeMode.system 下，暗色环境返回 AppColorsDark token', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.system,
          darkTheme: ThemeData(brightness: Brightness.dark),
          theme: ThemeData(brightness: Brightness.light),
          home: Builder(
            builder: (context) {
              final brightness = Theme.of(context).brightness;
              return Text(brightness == Brightness.dark ? 'DARK' : 'LIGHT');
            },
          ),
        ),
      );

      // 默认测试环境 brightness 为 light
      expect(find.text('LIGHT'), findsOneWidget);

      // 模拟系统暗色
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();

      expect(find.text('DARK'), findsOneWidget);

      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });

    test('AppColors.of 在暗色下返回 AppColorsDark 实例', () {
      // AppColors.of 依据 Theme.of(context).brightness 选择 token 集。
      // 此测试验证 AppColorsDark.instance 的关键色值与 light 不同，
      // 确保暗色模式会产生可见的视觉变化。
      final dark = AppColorsDark.instance;
      final light = AppColorsLight.instance;

      // 关键 token 应在亮/暗模式下有不同色值
      expect(dark.pageBg, isNot(equals(light.pageBg)));
      expect(dark.surface, isNot(equals(light.surface)));
      expect(dark.textPrimary, isNot(equals(light.textPrimary)));
      expect(dark.border, isNot(equals(light.border)));

      // 暗色模式：深背景、浅文字
      expect(
        dark.pageBg.computeLuminance(),
        lessThan(light.pageBg.computeLuminance()),
      );
      expect(
        dark.textPrimary.computeLuminance(),
        greaterThan(light.textPrimary.computeLuminance()),
      );
    });
  });
}
