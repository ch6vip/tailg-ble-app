import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/pages/cloud_token_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

import 'helpers/platform_mocks.dart';
import 'helpers/storage_mocks.dart';

/// Helper: bypass Flutter's test-binding HTTP 400 stub for our loopback server.
///
/// Flutter's `AutomatedTestWidgetsFlutterBinding` (installed by `flutter test`)
/// sets a global `HttpOverrides` that returns HTTP 400 from every `HttpClient`,
/// defeating a local `HttpServer`. `official_cloud_test.dart` avoids this
/// because it never calls `ensureInitialized` / `testWidgets`, so the automated
/// binding is never installed. This file must call `ensureInitialized` for its
/// clipboard `testWidgets`, so the 400-stub *is* active. We temporarily replace
/// it with a no-op override around the network calls.
class _LiveHttpOverrides extends HttpOverrides {}

Future<T> withLiveHttp<T>(Future<T> Function() body) async {
  final previous = HttpOverrides.current;
  HttpOverrides.global = _LiveHttpOverrides();
  try {
    return await body();
  } finally {
    HttpOverrides.global = previous;
  }
}

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

  test(
    'loginWithToken hydrates verified session and backfills userId',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        if (request.uri.path.endsWith('/app/centralControl/carStatus')) {
          await _ok(request, {'carId': 'car-1', 'carNickName': '我的车'});
        } else if (request.uri.path.endsWith('/app/getUserProfile')) {
          await _ok(request, {'id': 'user-42', 'nickName': '用户'});
        } else {
          request.response.statusCode = 404;
          await request.response.close();
        }
      });
      final apiBase =
          'http://${server.address.host}:${server.port}/v1/api/';

      final service = OfficialCloudService();
      service.resetForTest(
        apiConfig: OfficialCloudApiConfig(
          apiBase: apiBase,
          retryBaseDelay: Duration.zero,
        ),
      );

      await withLiveHttp(
        () => service.loginWithToken('Authorization: Bearer paste-token'),
      );

      expect(service.state.token, 'Bearer paste-token');
      expect(service.state.signedIn, isTrue);
      expect(service.state.userId, 'user-42');
      expect(service.state.vehicles, hasLength(1));
    },
  );

  test(
    'loginWithToken rejects unverifiable token, no fake session left',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        // Vehicles endpoint returns 401 → token dead.
        request.response.statusCode = 401;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'msg': 'token expired'}));
        await request.response.close();
      });
      final apiBase =
          'http://${server.address.host}:${server.port}/v1/api/';

      final service = OfficialCloudService();
      service.resetForTest(
        apiConfig: OfficialCloudApiConfig(
          apiBase: apiBase,
          retryBaseDelay: Duration.zero,
        ),
      );

      await expectLater(
        withLiveHttp(() => service.loginWithToken('Bearer dead-token')),
        throwsA(isA<OfficialCloudApiException>()),
      );

      // Must not leave a fake signed-in state.
      expect(service.state.token, isEmpty);
      expect(service.state.signedIn, isFalse);
      expect(service.state.vehicles, isEmpty);
    },
  );

  testWidgets('copy button writes current token to clipboard', (tester) async {
    mockClipboardWrites();
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'Bearer existing-token',
        phone: '18800001111',
      ),
    );

    // Re-create the page inside testWidgets so we can pump it.
    await tester.pumpWidget(
      MaterialApp(home: CloudTokenPageTestHarness()),
    );
    await tester.pump();

    await tester.tap(find.text('复制 Token'));
    await tester.pump();

    expect(clipboardWrites, contains('Bearer existing-token'));
  });
}

/// Minimal page that hosts CloudTokenPage so it can be tested with testWidgets.
class CloudTokenPageTestHarness extends StatelessWidget {
  const CloudTokenPageTestHarness({super.key});
  @override
  Widget build(BuildContext context) {
    return CloudTokenPage();
  }
}

Future<void> _ok(HttpRequest request, Map<String, Object?> data) async {
  request.response.statusCode = 200;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode({
    'code': '200',
    'msg': 'success',
    'data': data,
  }));
  await request.response.close();
}
