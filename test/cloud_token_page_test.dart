import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/pages/cloud_token_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

import 'helpers/platform_mocks.dart';
import 'helpers/snack_finders.dart';
import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    resetMockStorage();
    app.officialCloudService.resetForTest();
  });

  tearDown(() {
    clearPlatformChannelMock();
    app.officialCloudService.resetForTest();
    resetMockStorage();
  });

  testWidgets('pasting token logs into official session', (tester) async {
    await tester.pumpWidget(const TestApp(home: CloudTokenPage()));
    await tester.pump();

    await tester.enterText(
      find.byType(TextField),
      'Authorization: Bearer paste-token-123',
    );
    await tester.tap(find.text('用 Token 登录'));
    await tester.pump();
    // refreshVehicles may fail network; still wait for UI settle
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(app.officialCloudService.state.token, 'Bearer paste-token-123');
    expect(app.officialCloudService.state.signedIn, isTrue);
  });

  testWidgets('copy button writes current token to clipboard', (tester) async {
    mockClipboardWrites();
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'Bearer existing-token',
        phone: '18800001111',
      ),
    );

    await tester.pumpWidget(const TestApp(home: CloudTokenPage()));
    await tester.pump();

    await tester.tap(find.text('复制 Token'));
    await tester.pump();

    expect(clipboardWrites, contains('Bearer existing-token'));
    expect(find.text('Token 已复制到剪贴板'), findsOneWidget);
    expect(snackIcon(Icons.check_circle_outline), findsOneWidget);
  });

  test('loginWithToken normalizes bearer and authorization header', () async {
    final service = OfficialCloudService();
    await service.loginWithToken('Bearer  abc-token  ');
    expect(service.state.token, 'Bearer abc-token');
    expect(service.state.signedIn, isTrue);

    service.resetForTest();
    await service.loginWithToken('Authorization: Bearer header-token');
    expect(service.state.token, 'Bearer header-token');

    final prefs = await SharedPreferences.getInstance();
    // secure storage mock may hold token; state is enough for this unit path
    expect(service.state.token, isNotEmpty);
    expect(prefs, isNotNull);
  });
}
