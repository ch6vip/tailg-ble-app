import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/command_types.dart';
import 'package:tailg_ble_app/models/official_smart_service_status.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/services/official_car_operator_policy.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

void main() {
  OfficialVehicle vehicle({
    int modelType = 8,
    bool shared = false,
    bool withSim = true,
  }) {
    return OfficialVehicle.fromJson({
      'carId': 'car-1',
      'imei': '860000000000001',
      'modelType': modelType,
      'shareCarFlag': shared,
      if (withSim) 'simNo': 'sim-1',
      if (withSim) 'iccId': 'icc-1',
    });
  }

  OfficialCloudService signedIn(OfficialVehicle selected) {
    final cloud = OfficialCloudService();
    cloud.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        userId: 'user-1',
        vehicles: [selected],
        selectedVehicleKey: selected.key,
      ),
    );
    return cloud;
  }

  setUp(() {
    OfficialCloudService().resetForTest();
  });

  tearDown(() {
    OfficialCloudService().resetForTest();
  });

  group('official smart-service remote gate', () {
    test('maps official service codes without confusing API response code', () {
      expect(
        OfficialSmartServiceStatus.fromPayload({
          'code': '9',
        }).remoteControlBlockReason,
        'VIP智能服务已到期',
      );
      expect(
        OfficialSmartServiceStatus.fromPayload({
          'code': '7',
        }).remoteControlBlockReason,
        '当前智能云盒已销号',
      );
      expect(
        OfficialSmartServiceStatus.fromPayload({
          'code': '1',
        }).remoteControlBlockReason,
        isNull,
      );
    });

    test('model 3 loads once and blocks a known expired service', () async {
      final cloud = signedIn(vehicle(modelType: 3));
      var calls = 0;
      cloud.refreshSmartServiceStatusOverride = (_) async {
        calls++;
        return const OfficialSmartServiceStatus(code: '9');
      };

      final first = await cloud.resolveSelectedRemoteControlServiceDecision();
      final second = await cloud.resolveSelectedRemoteControlServiceDecision();

      expect(first.message, 'VIP智能服务已到期');
      expect(first.blocksControl, isTrue);
      expect(second.message, 'VIP智能服务已到期');
      expect(second.blocksControl, isTrue);
      expect(calls, 1);
    });

    test('model 8 warns about expiry but continues control', () async {
      final cloud = signedIn(vehicle(modelType: 8));
      cloud.refreshSmartServiceStatusOverride = (_) async {
        return const OfficialSmartServiceStatus(code: '9');
      };

      final decision = await cloud
          .resolveSelectedRemoteControlServiceDecision();

      expect(decision.message, 'VIP智能服务已到期');
      expect(decision.blocksControl, isFalse);
    });

    test('model 1 and 2 skip the SIM service query', () async {
      for (final modelType in [1, 2]) {
        final cloud = signedIn(vehicle(modelType: modelType));
        cloud.refreshSmartServiceStatusOverride = (_) {
          fail('KKS/YJ control must not query SIM service status');
        };

        final decision = await cloud
            .resolveSelectedRemoteControlServiceDecision();

        expect(decision.message, isNull);
        expect(decision.blocksControl, isFalse);
        cloud.resetForTest();
      }
    });

    test(
      'does not invent a block when the vehicle has no SIM identity',
      () async {
        final cloud = signedIn(vehicle(withSim: false));
        cloud.refreshSmartServiceStatusOverride = (_) {
          fail('SIM query must not run without iccId');
        };

        final decision = await cloud
            .resolveSelectedRemoteControlServiceDecision();
        expect(decision.message, isNull);
        expect(decision.blocksControl, isFalse);
      },
    );
  });

  group('official setCarOperator policy', () {
    test('tracks both power directions for KKS and YJ', () {
      for (final modelType in [1, 2]) {
        final selected = vehicle(modelType: modelType);
        expect(
          OfficialCarOperatorPolicy.updateFor(
            command: CommandCode.powerOn,
            vehicle: selected,
          )?.operatorFlag,
          '1',
        );
        expect(
          OfficialCarOperatorPolicy.updateFor(
            command: CommandCode.powerOff,
            vehicle: selected,
          )?.operatorFlag,
          '0',
        );
      }
    });

    test('tracks only shared power-on for the TLink/QGJ families', () {
      final shared = vehicle(modelType: 8, shared: true);
      final owned = vehicle(modelType: 8);

      expect(
        OfficialCarOperatorPolicy.updateFor(
          command: CommandCode.powerOn,
          vehicle: shared,
        )?.operatorFlag,
        '1',
      );
      expect(
        OfficialCarOperatorPolicy.updateFor(
          command: CommandCode.powerOff,
          vehicle: shared,
        ),
        isNull,
      );
      expect(
        OfficialCarOperatorPolicy.updateFor(
          command: CommandCode.powerOn,
          vehicle: owned,
        ),
        isNull,
      );
    });

    test(
      'cloud service dispatches the exact official operator payload',
      () async {
        final cloud = signedIn(vehicle(modelType: 1));
        String? carId;
        String? flag;
        cloud.setCarOperatorOverride = (nextCarId, nextFlag) async {
          carId = nextCarId;
          flag = nextFlag;
        };

        await cloud.syncCarOperatorAfterCommand(
          command: CommandCode.powerOff,
          vehicle: cloud.state.selectedVehicle!,
        );

        expect(carId, 'car-1');
        expect(flag, '0');
        expect(cloud.sentCarOperatorUpdates.single.carId, 'car-1');
        expect(cloud.sentCarOperatorUpdates.single.operatorFlag, '0');
      },
    );
  });

  test('cloud calls official endpoints with exact request fields', () async {
    final requests = <({String path, Map<String, dynamic> body})>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final raw = await utf8.decoder.bind(request).join();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      requests.add((path: request.uri.path, body: decoded));
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'code': '200',
          'data': request.uri.path.endsWith('/app/sim/queryDetail')
              ? {'code': '1'}
              : null,
        }),
      );
      await request.response.close();
    });

    final cloud = OfficialCloudService();
    cloud.resetForTest(
      apiConfig: OfficialCloudApiConfig(
        apiBase: 'http://${server.address.address}:${server.port}/',
        retryBaseDelay: Duration.zero,
      ),
    );
    signedIn(vehicle());

    await cloud.refreshSelectedSmartServiceStatus(force: true, silent: false);
    await cloud.setCarOperator(carId: 'car-1', operatorFlag: '1');

    expect(requests, hasLength(2));
    expect(requests[0].path, '/app/sim/queryDetail');
    expect(requests[0].body, {'simNo': 'sim-1', 'iccId': 'icc-1'});
    expect(requests[1].path, '/app/car/setCarOperator');
    expect(requests[1].body, {'carId': 'car-1', 'operatorFlag': '1'});
  });
}
