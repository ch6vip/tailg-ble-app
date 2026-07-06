import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/ble/constants.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/services/control_channel_resolver.dart';
import 'package:tailg_ble_app/services/control_command_executor.dart';
import 'package:tailg_ble_app/services/control_command_policy.dart';
import 'package:tailg_ble_app/services/control_command_result.dart';
import 'package:tailg_ble_app/services/log_service.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

import 'helpers/storage_mocks.dart';

void main() {
  group('OfficialVehicle', () {
    test('parses official car status fields', () {
      final vehicle = OfficialVehicle.fromJson({
        'imei': 'IMEI_MAIN',
        'imeiGps': 'IMEI_GPS',
        'carId': 'car-1',
        'carName': 'Tailg',
        'carNickName': 'My Bike',
        'carPhoto': 'https://example.com/bike.png',
        'frame': 'FRAME123',
        'defenceStatus': 1,
        'acc': 0,
        'electricQuantity': '87',
        'voltage': '52.5',
        'online': true,
        'btname': 'Q_BASH_TEST',
        'btmac': 'AA:BB:CC:DD:EE:FF',
        'longitude': '104.1',
        'latitude': '25.1',
        'modelType': 1501,
        'mileage': '12.5',
      });

      expect(vehicle.displayName, 'My Bike');
      expect(vehicle.isLocked, isTrue);
      expect(vehicle.isPowerOn, isFalse);
      expect(vehicle.electricQuantity, 87);
      expect(vehicle.voltage, 52.5);
      expect(vehicle.mileage, 12.5);
      expect(vehicle.commandImei, 'IMEI_GPS');
      expect(vehicle.normalizedBtmac, 'AA:BB:CC:DD:EE:FF');
      expect(vehicle.hasBleIdentity, isTrue);
      expect(vehicle.hasGpsService, isTrue);
    });

    test('falls back to main imei for non GPS model type', () {
      final vehicle = OfficialVehicle.fromJson({
        'imei': 'IMEI_MAIN',
        'imeiGps': 'IMEI_GPS',
        'modelType': 2,
      });

      expect(vehicle.commandImei, 'IMEI_MAIN');
      expect(vehicle.hasGpsService, isFalse);
    });

    test('normalizes compact official bluetooth mac', () {
      final vehicle = OfficialVehicle.fromJson({'btmac': 'aabbccddeeff'});

      expect(vehicle.normalizedBtmac, 'AA:BB:CC:DD:EE:FF');
      expect(vehicle.hasBleIdentity, isTrue);
    });

    test('rejects invalid official bluetooth mac', () {
      final vehicle = OfficialVehicle.fromJson({'btmac': 'not-a-mac'});

      expect(vehicle.normalizedBtmac, isEmpty);
      expect(vehicle.hasBleIdentity, isFalse);
    });

    test('parses official feature flags for conditional control modules', () {
      final vehicle = OfficialVehicle.fromJson({
        'navigationProjection': '1',
        'cameraService': true,
        'smartMeter': {'enabled': true},
        'bleRenewal': 1,
        'chargingStation': 'true',
      });

      expect(vehicle.supportsNavigationProjection, isTrue);
      expect(vehicle.supportsCamera, isTrue);
      expect(vehicle.supportsSmartMeter, isTrue);
      expect(vehicle.supportsBleRenewal, isTrue);
      expect(vehicle.supportsChargingStation, isTrue);
    });

    test('treats disabled official feature flags as hidden', () {
      final vehicle = OfficialVehicle.fromJson({
        'navigationProjection': '0',
        'cameraService': false,
        'smartMeter': {'enabled': false},
        'bleRenewal': '关闭',
        'chargingStation': 'false',
      });

      expect(vehicle.supportsNavigationProjection, isFalse);
      expect(vehicle.supportsCamera, isFalse);
      expect(vehicle.supportsSmartMeter, isFalse);
      expect(vehicle.supportsBleRenewal, isFalse);
      expect(vehicle.supportsChargingStation, isFalse);
    });

    test('serializes raw official fields for startup cache', () {
      final vehicle = OfficialVehicle.fromJson({
        'carId': 'car-1',
        'carNickName': '缓存车',
        'navigationProjection': '1',
        'cameraService': true,
        'featureGroup': {
          'smartMeter': {'enabled': true},
        },
      });

      final json = vehicle.toJson();

      expect(json['carId'], 'car-1');
      expect(json['navigationProjection'], '1');
      expect(json['cameraService'], isTrue);
      expect(json['featureGroup'], {
        'smartMeter': {'enabled': true},
      });
    });
  });

  group('OfficialCloudCommand', () {
    test('maps supported command codes', () {
      expect(
        OfficialCloudCommand.fromCommandCode(CommandCode.lock)?.apiName,
        'lock',
      );
      expect(
        OfficialCloudCommand.fromCommandCode(CommandCode.unlock)?.apiName,
        'unlock',
      );
      expect(
        OfficialCloudCommand.fromCommandCode(CommandCode.powerOn)?.apiName,
        'start',
      );
      expect(
        OfficialCloudCommand.fromCommandCode(CommandCode.powerOff)?.apiName,
        'stop',
      );
      expect(
        OfficialCloudCommand.fromCommandCode(CommandCode.find)?.apiName,
        'search',
      );
      expect(
        OfficialCloudCommand.fromCommandCode(CommandCode.openSeat)?.apiName,
        'openCushion',
      );
    });

    test('rejects unsupported read commands', () {
      expect(
        OfficialCloudCommand.fromCommandCode(CommandCode.readState),
        isNull,
      );
      expect(
        OfficialCloudCommand.fromCommandCode(CommandCode.readAntiTheft),
        isNull,
      );
    });
  });

  group('OfficialCloudApiConfig', () {
    test('keeps official client defaults in one place', () {
      const config = OfficialCloudApiConfig();

      expect(
        config.resolve('app/login').toString(),
        'https://www.tailgdd.com/v1/api/app/login',
      );
      expect(config.apiBase, OfficialCloudApiConfig.defaultApiBase);
      expect(config.loginMacCode, OfficialCloudApiConfig.defaultLoginMacCode);
      expect(config.phoneMode, OfficialCloudApiConfig.defaultPhoneMode);
      expect(
        config.forwardServiceIp,
        OfficialCloudApiConfig.defaultForwardServiceIp,
      );
      expect(config.language, OfficialCloudApiConfig.defaultLanguage);
      expect(config.zoneId, OfficialCloudApiConfig.defaultZoneId);
      expect(config.apiVersion, OfficialCloudApiConfig.defaultApiVersion);
      expect(config.userAgent, OfficialCloudApiConfig.defaultUserAgent);
      expect(
        config.connectTimeout,
        OfficialCloudApiConfig.defaultConnectTimeout,
      );
      expect(
        config.responseTimeout,
        OfficialCloudApiConfig.defaultResponseTimeout,
      );
      expect(
        config.retryBaseDelay,
        OfficialCloudApiConfig.defaultRetryBaseDelay,
      );
      expect(
        config.retryDelayForAttempt(0),
        OfficialCloudApiConfig.defaultRetryBaseDelay,
      );
      expect(
        config.retryDelayForAttempt(1),
        OfficialCloudApiConfig.defaultRetryBaseDelay * 2,
      );
      expect(
        config.retryDelayForAttempt(-1),
        OfficialCloudApiConfig.defaultRetryBaseDelay,
      );
      // Forward-Service-Ip is omitted by default (P2-8: was 'localhost' +
      // a duplicate 'Forward-ServiceIp' typo). Only emitted when configured.
      expect(config.defaultHeaders.containsKey('Forward-Service-Ip'), isFalse);
      expect(config.defaultHeaders.containsKey('Forward-ServiceIp'), isFalse);
      expect(
        config.defaultHeaders['language'],
        OfficialCloudApiConfig.defaultLanguage,
      );
      expect(
        config.defaultHeaders['accept-language'],
        OfficialCloudApiConfig.defaultLanguage,
      );
      expect(
        config.defaultHeaders['Zone-id'],
        OfficialCloudApiConfig.defaultZoneId,
      );
      expect(
        config.defaultHeaders['Api-Version'],
        OfficialCloudApiConfig.defaultApiVersion,
      );
      expect(
        config.defaultHeaders['user-agent'],
        OfficialCloudApiConfig.defaultUserAgent,
      );

      const configured = OfficialCloudApiConfig(forwardServiceIp: '10.0.0.1');
      expect(configured.defaultHeaders['Forward-Service-Ip'], '10.0.0.1');
      expect(
        configured.defaultHeaders.containsKey('Forward-ServiceIp'),
        isFalse,
      );
    });
  });

  group('OfficialCloudApiClient retry policy', () {
    test('retries 5xx responses for read requests', () async {
      var requests = 0;
      final server = await _startOfficialCloudServer((request) async {
        requests++;
        if (requests < 3) {
          await _writeJsonResponse(request, 502, {'msg': 'gateway busy'});
          return;
        }
        await _writeJsonResponse(request, 200, {
          'code': '200',
          'data': {'ok': true},
        });
      });
      addTearDown(server.close);

      final client = OfficialCloudApiClient(
        config: OfficialCloudApiConfig(
          apiBase: server.apiBase,
          retryBaseDelay: Duration.zero,
        ),
        log: LogService(),
      );
      addTearDown(client.dispose);

      final response = await client.request(
        'app/read',
        method: 'POST',
        retryPolicy: OfficialCloudRetryPolicy.readRequest,
      );

      expect(requests, 3);
      expect(response.statusCode, 200);
      expect(response.body['data'], {'ok': true});
      expect(client.lastRequest?.statusCode, 200);
      expect(client.lastRequest?.success, isTrue);
    });

    test('does not retry 5xx responses by default', () async {
      var requests = 0;
      final server = await _startOfficialCloudServer((request) async {
        requests++;
        await _writeJsonResponse(request, 502, {'msg': 'gateway busy'});
      });
      addTearDown(server.close);

      final client = OfficialCloudApiClient(
        config: OfficialCloudApiConfig(
          apiBase: server.apiBase,
          retryBaseDelay: Duration.zero,
        ),
        log: LogService(),
      );
      addTearDown(client.dispose);

      await expectLater(
        client.request('app/device/cmd/lock', method: 'POST'),
        throwsA(
          isA<OfficialCloudApiException>()
              .having((e) => e.statusCode, 'statusCode', 502)
              .having((e) => e.message, 'message', 'gateway busy'),
        ),
      );

      expect(requests, 1);
      expect(client.lastRequest?.statusCode, 502);
      expect(client.lastRequest?.success, isFalse);
    });

    test('reports non-JSON response body excerpt', () async {
      final server = await _startOfficialCloudServer((request) async {
        request.response.statusCode = 200;
        request.response.write('plain text response');
        await request.response.close();
      });
      addTearDown(server.close);

      final client = OfficialCloudApiClient(
        config: OfficialCloudApiConfig(apiBase: server.apiBase),
        log: LogService(),
      );
      addTearDown(client.dispose);

      await expectLater(
        client.request('app/read', method: 'GET'),
        throwsA(
          isA<OfficialCloudApiException>().having(
            (e) => e.message,
            'message',
            '服务器返回非 JSON 数据: plain text response',
          ),
        ),
      );
    });

    test('rejects JSON responses that are not objects', () async {
      final server = await _startOfficialCloudServer((request) async {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(['ok']));
        await request.response.close();
      });
      addTearDown(server.close);

      final client = OfficialCloudApiClient(
        config: OfficialCloudApiConfig(apiBase: server.apiBase),
        log: LogService(),
      );
      addTearDown(client.dispose);

      await expectLater(
        client.request('app/read', method: 'GET'),
        throwsA(
          isA<OfficialCloudApiException>().having(
            (e) => e.message,
            'message',
            '服务器返回数据格式不正确',
          ),
        ),
      );
    });
  });

  group('OfficialCloudApiException', () {
    test('keeps message and optional status code', () {
      const error = OfficialCloudApiException('官方错误', statusCode: 403);

      expect(error.message, '官方错误');
      expect(error.statusCode, 403);
      expect(error.toString(), '官方错误');
    });
  });

  group('OfficialCloudResponseCode', () {
    test('parses only explicit official success codes', () {
      expect(
        OfficialCloudResponseCode.parse('200'),
        OfficialCloudResponseCode.success,
      );
      expect(
        OfficialCloudResponseCode.parse(0),
        OfficialCloudResponseCode.legacySuccess,
      );
      expect(OfficialCloudResponseCode.parse('500'), isNull);
      expect(OfficialCloudResponseCode.parse(null), isNull);
    });

    test('does not infer success from message text', () {
      expect(
        OfficialCloudResponseCode.isSuccessBody({
          'code': '500',
          'msg': '操作未成功',
        }),
        isFalse,
      );
      expect(OfficialCloudResponseCode.isSuccessBody({'msg': '成功'}), isFalse);
    });
  });

  group('OfficialCloudLoginValidator', () {
    test('keeps official login input validation in one place', () {
      expect(
        OfficialCloudLoginValidator.compactPhone('188 1234\t5678'),
        '18812345678',
      );

      expect(OfficialCloudLoginValidator.isValidPhone('18812345678'), isTrue);
      expect(OfficialCloudLoginValidator.isValidPhone('1881234567'), isFalse);
      expect(OfficialCloudLoginValidator.isValidPhone('188123456789'), isFalse);
      expect(
        OfficialCloudLoginValidator.isValidPhone('188 1234 5678'),
        isFalse,
      );

      expect(OfficialCloudLoginValidator.isValidSmsCode('1234'), isTrue);
      expect(OfficialCloudLoginValidator.isValidSmsCode('12345678'), isTrue);
      expect(OfficialCloudLoginValidator.isValidSmsCode('123'), isFalse);
      expect(OfficialCloudLoginValidator.isValidSmsCode('123456789'), isFalse);
      expect(OfficialCloudLoginValidator.isValidSmsCode('abcd'), isFalse);
    });
  });

  group('OfficialCloudRedactor', () {
    test('masks sensitive request path values and diagnostic text', () {
      expect(
        OfficialCloudRedactor.requestPath(
          'app/getCode?phone=18886120851&imei=860123456789377&btmac=aabbccddeeff',
        ),
        'app/getCode?phone=188***851&imei=860***377&btmac=aab***eff',
      );
      expect(
        OfficialCloudRedactor.text(
          'phone=18886120851 imei=860123456789377 mac=AA:BB:CC:DD:EE:FF compact=aabbccddeeff',
        ),
        'phone=188***851 imei=860***377 mac=AA:***:FF compact=aab***eff',
      );
    });
  });

  group('OfficialCloudAuthParser', () {
    test('extracts user id from nested official login responses', () {
      expect(
        OfficialCloudAuthParser.extractUserId({
          'data': {
            'profile': [
              {'name': 'ignored'},
              {'uid': '  user-1  '},
            ],
          },
        }),
        'user-1',
      );
      expect(
        OfficialCloudAuthParser.extractUserId({
          'data': {
            'account': {'userId': 12345},
          },
        }),
        '12345',
      );
      expect(OfficialCloudAuthParser.extractUserId({}), isEmpty);
    });

    test('does not match generic id fields (regression for P1-4)', () {
      // Previously 'id' was a fallback key and would mis-match carId,
      // deviceTravelId, extendId, etc. Only uid/userId should match.
      expect(
        OfficialCloudAuthParser.extractUserId({
          'data': {
            'carId': 'CAR-XYZ',
            'deviceTravelId': 'TRAVEL-1',
            'extendId': 'EXT-9',
          },
        }),
        isEmpty,
      );
      expect(
        OfficialCloudAuthParser.extractUserId({
          'data': {'id': 'should-not-match'},
        }),
        isEmpty,
      );
    });

    test(
      'recognizes auth failure messages without matching generic errors',
      () {
        expect(
          OfficialCloudAuthParser.looksLikeAuthError('token 已过期，请重新登录'),
          isTrue,
        );
        expect(
          OfficialCloudAuthParser.looksLikeAuthError('TOKEN expired'),
          isTrue,
        );
        expect(
          OfficialCloudAuthParser.looksLikeAuthError('Unauthorized request'),
          isTrue,
        );
        expect(OfficialCloudAuthParser.looksLikeAuthError('HTTP 403'), isTrue);
        expect(OfficialCloudAuthParser.looksLikeAuthError('网络不可用'), isFalse);
        expect(
          OfficialCloudAuthParser.looksLikeAuthError('server timeout'),
          isFalse,
        );
      },
    );
  });

  group('OfficialCloudDataParser', () {
    test('parses vehicle payload from list or single map', () {
      final list = OfficialCloudDataParser.vehicles([
        {'carId': 'car-1', 'carNickName': 'A'},
        {'carId': '', 'carNickName': 'invalid'},
        'ignored',
      ]);
      final single = OfficialCloudDataParser.vehicles({
        'carId': 'car-2',
        'carNickName': 'B',
      });
      final invalidSingle = OfficialCloudDataParser.vehicles('ignored');

      expect(list, hasLength(1));
      expect(list.first.displayName, 'A');
      expect(single, hasLength(1));
      expect(single.first.displayName, 'B');
      expect(invalidSingle, isEmpty);
    });

    test('returns empty detail models for missing map payloads', () {
      final batteryInfo = OfficialCloudDataParser.batteryInfo(null);
      final location = OfficialCloudDataParser.vehicleLocation('invalid');
      final fence = OfficialCloudDataParser.fenceData(null);
      final parsedLocation = OfficialCloudDataParser.vehicleLocation({
        'bleConnectLat': '25.1',
        'bleConnectLng': '104.1',
      });

      expect(batteryInfo.hasData, isFalse);
      expect(location.hasData, isFalse);
      expect(fence.hasData, isFalse);
      expect(parsedLocation.hasData, isTrue);
      expect(parsedLocation.latitude, 25.1);
    });

    test('filters travel days and points without usable data', () {
      final days = OfficialCloudDataParser.travelDays([
        {
          'travelDate': '2026-05-29',
          'totalTime': '1800',
          'totalMileage': '12.5',
        },
        {'travelDate': ''},
        'ignored',
      ]);
      final points = OfficialCloudDataParser.travelPoints([
        {'lat': '25.1', 'lng': '104.1', 'reportTime': '2026-05-29 10:01:00'},
        {'lat': '', 'lng': ''},
      ]);

      expect(days, hasLength(1));
      expect(days.first.travelDate, '2026-05-29');
      expect(points, hasLength(1));
      expect(points.first.hasCoordinate, isTrue);
    });
  });

  group('OfficialCloudVehicleMapper', () {
    test('maps official bluetooth identity into a local QGJ profile', () {
      final profile = OfficialCloudVehicleMapper.profileFromOfficialVehicle(
        OfficialVehicle.fromJson({
          'carNickName': '通勤车',
          'btmac': 'aabbccddeeff',
          'btname': 'Q_BASH_TEST',
        }),
      );

      expect(profile, isNotNull);
      expect(profile!.id, 'AA:BB:CC:DD:EE:FF');
      expect(profile.name, '通勤车');
      expect(profile.protocol, VehicleProtocol.qgj);
    });

    test('returns null when official vehicle has no valid bluetooth mac', () {
      final profile = OfficialCloudVehicleMapper.profileFromOfficialVehicle(
        OfficialVehicle.fromJson({
          'carNickName': '无蓝牙车',
          'btmac': 'invalid',
          'btname': 'Q_BASH_TEST',
        }),
      );

      expect(profile, isNull);
    });

    test('keeps unknown official bluetooth name on auto protocol', () {
      final profile = OfficialCloudVehicleMapper.profileFromOfficialVehicle(
        OfficialVehicle.fromJson({
          'carName': '普通车',
          'btmac': '11:22:33:44:55:66',
          'btname': 'TAILG_OTHER',
        }),
      );

      expect(profile, isNotNull);
      expect(profile!.protocol, VehicleProtocol.auto);
      expect(profile.name, '普通车');
    });
  });

  group('OfficialCloudVehicleLinks', () {
    test('normalizes stored links from persistence boundaries', () {
      expect(
        OfficialCloudVehicleLinks.normalize({
          ' official-1 ': ' local-1 ',
          '': 'local-empty-key',
          'official-empty-value': ' ',
          'official-2': 'local-2',
        }),
        {'official-1': 'local-1', 'official-2': 'local-2'},
      );
    });

    test('links and unlinks official vehicles without mutating source map', () {
      final original = {'official-1': 'local-1'};
      final linked = OfficialCloudVehicleLinks.link(
        original,
        officialVehicleKey: 'official-2',
        localVehicleId: 'local-2',
      );
      final unlinked = OfficialCloudVehicleLinks.unlink(linked, 'official-1');

      expect(original, {'official-1': 'local-1'});
      expect(linked, {'official-1': 'local-1', 'official-2': 'local-2'});
      expect(unlinked, {'official-2': 'local-2'});
    });

    test('prunes links by valid local vehicle ids', () {
      final pruned = OfficialCloudVehicleLinks.prune(
        {
          'official-1': 'local-1',
          'official-2': 'local-2',
          'official-3': 'local-3',
          ' official-4 ': ' local-4 ',
          '': 'local-1',
          'official-empty': '',
        },
        {'local-1', ' local-3 ', 'local-4', ''},
      );

      expect(pruned, {
        'official-1': 'local-1',
        'official-3': 'local-3',
        'official-4': 'local-4',
      });
    });

    test('normalizes invalid local link writes', () {
      final original = {'official-1': 'local-1'};

      expect(
        OfficialCloudVehicleLinks.link(
          original,
          officialVehicleKey: '',
          localVehicleId: 'local-2',
        ),
        original,
      );
      expect(
        OfficialCloudVehicleLinks.link(
          original,
          officialVehicleKey: 'official-1',
          localVehicleId: '',
        ),
        isEmpty,
      );
      expect(
        OfficialCloudVehicleLinks.link(
          {' official-1 ': ' local-1 '},
          officialVehicleKey: ' official-2 ',
          localVehicleId: ' local-2 ',
        ),
        {'official-1': 'local-1', 'official-2': 'local-2'},
      );
    });

    test('checks whether official vehicle already links to local vehicle', () {
      final links = {'official-1': 'local-1'};

      expect(
        OfficialCloudVehicleLinks.isLinkedTo(
          {' official-1 ': ' local-1 '},
          officialVehicleKey: ' official-1 ',
          localVehicleId: ' local-1 ',
        ),
        isTrue,
      );
      expect(
        OfficialCloudVehicleLinks.isLinkedTo(
          links,
          officialVehicleKey: 'official-1',
          localVehicleId: 'local-2',
        ),
        isFalse,
      );
    });
  });

  group('OfficialCloudVehicle sync', () {
    test(
      'maps official vehicle to local profile data and skips invalid macs',
      () {
        final mapped = OfficialCloudVehicleMapper.profileFromOfficialVehicle(
          OfficialVehicle.fromJson({
            'carNickName': '同步车',
            'btmac': 'aabbccddeeff',
            'btname': 'Q_BASH_SYNC',
          }),
        );
        final skipped = OfficialCloudVehicleMapper.profileFromOfficialVehicle(
          OfficialVehicle.fromJson({'carNickName': '坏车', 'btmac': 'bad'}),
        );

        expect(mapped, isNotNull);
        expect(mapped!.id, 'AA:BB:CC:DD:EE:FF');
        expect(mapped.name, '同步车');
        expect(mapped.protocol, VehicleProtocol.qgj);
        expect(skipped, isNull);
      },
    );

    test('prefers existing linked local vehicle before profile mapping', () {
      final decision = OfficialCloudVehicleSyncPlanner.plan(
        selectedVehicle: OfficialVehicle.fromJson({
          'carId': 'official-1',
          'carNickName': '官方车',
          'btmac': 'aabbccddeeff',
          'btname': 'Q_BASH_SYNC',
        }),
        localVehicleLinks: const {'official-1': 'local-1'},
        localVehicles: [
          VehicleProfile(
            id: 'local-1',
            name: '本地车',
            protocol: VehicleProtocol.standard,
            createdAt: DateTime(2026, 5, 29),
            updatedAt: DateTime(2026, 5, 29),
          ),
        ],
      );

      expect(decision, isNotNull);
      expect(decision!.linkedLocalVehicleId, 'local-1');
      expect(decision.profileData, isNull);
    });

    test(
      'falls back to profile mapping when linked local vehicle is missing',
      () {
        final decision = OfficialCloudVehicleSyncPlanner.plan(
          selectedVehicle: OfficialVehicle.fromJson({
            'carId': 'official-2',
            'carNickName': '官方车2',
            'btmac': 'aabbccddeeff',
            'btname': 'QGJ_SYNC',
          }),
          localVehicleLinks: const {'official-2': 'missing-local'},
          localVehicles: const [],
        );

        expect(decision, isNotNull);
        expect(decision!.linkedLocalVehicleId, isNull);
        expect(decision.profileData, isNotNull);
        expect(decision.profileData!.id, 'AA:BB:CC:DD:EE:FF');
        expect(decision.profileData!.protocol, VehicleProtocol.qgj);
      },
    );
  });

  group('OfficialCloudStorage', () {
    setUp(() {
      resetMockStorage();
      OfficialCloudService().resetForTest();
      LogService().clear();
    });

    tearDown(() {
      resetMockStorage();
      OfficialCloudService().resetForTest();
      LogService().clear();
    });

    test(
      'logs non-map persisted vehicle links and loads empty links',
      () async {
        SharedPreferences.setMockInitialValues({
          'official_cloud_vehicle_links': '[]',
        });

        final service = OfficialCloudService();
        await service.init();

        expect(service.state.localVehicleLinks, isEmpty);
        final warning = LogService().all.singleWhere(
          (entry) =>
              entry.message == '官云本地车辆关联数据格式异常，已忽略' &&
              entry.level == LogLevel.warning,
        );
        expect(warning.detail, 'Expected JSON object, got List<dynamic>');
      },
    );

    test('normalizes persisted vehicle links on load', () async {
      SharedPreferences.setMockInitialValues({
        'official_cloud_vehicle_links': jsonEncode({
          ' official-1 ': ' local-1 ',
          '': 'local-empty-key',
          'official-empty-value': ' ',
          'official-2': 123,
        }),
      });

      final service = OfficialCloudService();
      await service.init();

      expect(service.state.localVehicleLinks, {
        'official-1': 'local-1',
        'official-2': '123',
      });
    });

    test(
      'restores cached carControlInfo with login session before refresh',
      () async {
        SharedPreferences.setMockInitialValues({
          'official_cloud_token': 'cached-token',
          'official_cloud_phone': '18800001111',
          'official_cloud_user_id': 'user-1',
          'official_cloud_selected_vehicle': 'car-1',
          'carControlInfo': jsonEncode({
            'carId': 'car-1',
            'carNickName': '通勤车',
            'carPhoto': 'https://example.com/bike.png',
            'navigationProjection': '1',
            'cameraService': true,
          }),
        });

        final service = OfficialCloudService();
        await service.initForTest();

        expect(service.state.signedIn, isTrue);
        expect(service.state.vehicles, hasLength(1));
        expect(service.state.selectedVehicle?.key, 'car-1');
        expect(service.state.selectedVehicle?.displayName, '通勤车');
        expect(
          service.state.selectedVehicle?.carPhoto,
          'https://example.com/bike.png',
        );
        expect(
          service.state.selectedVehicle?.supportsNavigationProjection,
          isTrue,
        );
        expect(service.state.selectedVehicle?.supportsCamera, isTrue);
      },
    );

    test('ignores cached carControlInfo without login session', () async {
      SharedPreferences.setMockInitialValues({
        'official_cloud_selected_vehicle': 'car-1',
        'carControlInfo': jsonEncode({'carId': 'car-1', 'carNickName': '旧缓存车'}),
      });

      final service = OfficialCloudService();
      await service.initForTest();

      expect(service.state.signedIn, isFalse);
      expect(service.state.vehicles, isEmpty);
      expect(service.state.selectedVehicle, isNull);
    });

    test('logs invalid cached carControlInfo with login session', () async {
      SharedPreferences.setMockInitialValues({
        'official_cloud_token': 'cached-token',
        'official_cloud_phone': '18800001111',
        'official_cloud_user_id': 'user-1',
        'carControlInfo': jsonEncode([
          {'carNickName': '无标识缓存车'},
        ]),
      });

      final service = OfficialCloudService();
      await service.initForTest();

      expect(service.state.signedIn, isTrue);
      expect(service.state.vehicles, isEmpty);
      final warning = LogService().all.singleWhere(
        (entry) =>
            entry.message == '官云车辆控制缓存无有效车辆，已忽略' &&
            entry.level == LogLevel.warning,
      );
      expect(warning.detail, 'type=List<dynamic>');
    });

    test('selectVehicle persists official carControlInfo cache', () async {
      final vehicle = OfficialVehicle.fromJson({
        'carId': 'car-2',
        'carNickName': '选中车',
        'navigationProjection': '1',
        'cameraService': true,
      });
      final service = OfficialCloudService();
      service.setStateForTest(
        OfficialCloudState.initial().copyWith(
          initialized: true,
          token: 'token',
          vehicles: [vehicle],
        ),
      );

      await service.selectVehicle(vehicle);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('official_cloud_selected_vehicle'), 'car-2');
      final cached =
          jsonDecode(prefs.getString('carControlInfo')!)
              as Map<String, dynamic>;
      expect(cached['carId'], 'car-2');
      expect(cached['navigationProjection'], '1');
      expect(cached['cameraService'], isTrue);
    });

    test('logout clears cached carControlInfo', () async {
      final vehicle = OfficialVehicle.fromJson({
        'carId': 'car-3',
        'carNickName': '退出车',
      });
      SharedPreferences.setMockInitialValues({
        'official_cloud_selected_vehicle': 'car-3',
        'carControlInfo': jsonEncode(vehicle.toJson()),
      });
      final service = OfficialCloudService();
      service.setStateForTest(
        OfficialCloudState.initial().copyWith(
          initialized: true,
          token: 'token',
          vehicles: [vehicle],
          selectedVehicleKey: 'car-3',
        ),
      );

      await service.logout();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('official_cloud_selected_vehicle'), isNull);
      expect(prefs.getString('carControlInfo'), isNull);
      expect(service.state.vehicles, isEmpty);
      expect(service.state.selectedVehicle, isNull);
    });
  });

  group('ControlChannelResolver', () {
    test('enables linked BLE channel when ready and local vehicle matches', () {
      final state = _cloudState(
        channel: OfficialControlChannel.ble,
        signedIn: true,
        withVehicle: true,
        links: const {'official-1': 'local-1'},
      );

      final availability = ControlChannelResolver.resolve(
        cloudState: state,
        bleReady: true,
        defaultVehicleId: 'local-1',
      );

      expect(availability.canUseBle, isTrue);
      expect(availability.enabled, isTrue);
      expect(availability.willUseBle, isTrue);
    });

    test('disables BLE channel when linked local vehicle differs', () {
      final state = _cloudState(
        channel: OfficialControlChannel.ble,
        signedIn: true,
        withVehicle: true,
        links: const {'official-1': 'local-1'},
      );

      final availability = ControlChannelResolver.resolve(
        cloudState: state,
        bleReady: true,
        defaultVehicleId: 'other-local',
      );

      expect(availability.canUseBle, isFalse);
      expect(availability.enabled, isFalse);
      expect(availability.bleUnavailableReason, '默认本地车辆与官方车辆关联不一致');
      expect(availability.disabledReason, '默认本地车辆与官方车辆关联不一致');
    });

    test('disables BLE channel when disconnected', () {
      final state = _cloudState(channel: OfficialControlChannel.ble);

      final availability = ControlChannelResolver.resolve(
        cloudState: state,
        bleReady: false,
        defaultVehicleId: null,
      );

      expect(availability.canUseBle, isFalse);
      expect(availability.enabled, isFalse);
      expect(availability.effectiveChannelLabel, '不可用');
      expect(availability.bleUnavailableReason, 'BLE 未连接或协议未就绪');
      expect(availability.disabledReason, 'BLE 未连接或协议未就绪');
    });

    test(
      'enables official cloud only when signed in with a selected vehicle',
      () {
        final available = ControlChannelResolver.resolve(
          cloudState: _cloudState(
            channel: OfficialControlChannel.officialCloud,
            signedIn: true,
            withVehicle: true,
          ),
          bleReady: false,
          defaultVehicleId: null,
        );
        final missingVehicle = ControlChannelResolver.resolve(
          cloudState: _cloudState(
            channel: OfficialControlChannel.officialCloud,
            signedIn: true,
          ),
          bleReady: false,
          defaultVehicleId: null,
        );
        final signedOut = ControlChannelResolver.resolve(
          cloudState: _cloudState(
            channel: OfficialControlChannel.officialCloud,
          ),
          bleReady: false,
          defaultVehicleId: null,
        );

        expect(available.enabled, isTrue);
        expect(available.effectiveChannelLabel, '官方云端');
        expect(available.willUseBle, isFalse);
        expect(missingVehicle.enabled, isFalse);
        expect(missingVehicle.disabledReason, '官方账号未选择车辆');
        expect(signedOut.enabled, isFalse);
        expect(signedOut.disabledReason, '请先登录官方账号');
      },
    );

    test('automatic channel prefers BLE and falls back to official cloud', () {
      final state = _cloudState(
        signedIn: true,
        withVehicle: true,
        links: const {'official-1': 'local-1'},
      );

      final bleAvailable = ControlChannelResolver.resolve(
        cloudState: state,
        bleReady: true,
        defaultVehicleId: 'local-1',
      );
      final cloudFallback = ControlChannelResolver.resolve(
        cloudState: state,
        bleReady: false,
        defaultVehicleId: 'local-1',
      );

      expect(bleAvailable.enabled, isTrue);
      expect(bleAvailable.effectiveChannelLabel, 'BLE');
      expect(bleAvailable.willUseBle, isTrue);
      expect(cloudFallback.enabled, isTrue);
      expect(cloudFallback.effectiveChannelLabel, '官方云端');
      expect(cloudFallback.willUseBle, isFalse);
    });

    test('automatic channel disables when BLE and cloud are unavailable', () {
      final availability = ControlChannelResolver.resolve(
        cloudState: _cloudState(),
        bleReady: false,
        defaultVehicleId: null,
      );

      expect(availability.enabled, isFalse);
      expect(availability.willUseBle, isFalse);
      expect(availability.bleUnavailableReason, 'BLE 未连接或协议未就绪');
      expect(availability.cloudUnavailableReason, '请先登录官方账号');
      expect(availability.disabledReason, 'BLE：BLE 未连接或协议未就绪；云端：请先登录官方账号');
    });

    test('busy state disables an otherwise available route', () {
      final availability = ControlChannelResolver.resolve(
        cloudState: _cloudState(
          channel: OfficialControlChannel.ble,
          signedIn: true,
          withVehicle: true,
          links: const {'official-1': 'local-1'},
        ),
        bleReady: true,
        defaultVehicleId: 'local-1',
        busy: true,
      );

      expect(availability.canUseBle, isTrue);
      expect(availability.enabled, isFalse);
    });
  });

  group('ControlCommandResult', () {
    test('marks successful BLE commands as bike-state refreshable', () {
      final result = ControlCommandResult.bleSuccess(CommandCode.lock);

      expect(result.success, isTrue);
      expect(result.transport, ControlCommandTransport.ble);
      expect(result.shouldRefreshBikeState, isTrue);
      expect(result.failureMessage, isNull);
    });

    test('keeps cloud success message without requesting BLE refresh', () {
      final result = ControlCommandResult.cloudSuccess(
        CommandCode.find,
        message: 'success',
      );

      expect(result.success, isTrue);
      expect(result.transport, ControlCommandTransport.officialCloud);
      expect(result.shouldRefreshBikeState, isFalse);
      expect(result.successMessage, '寻车已完成');
    });

    test('carries unavailable and failed command messages', () {
      final unavailable = ControlCommandResult.unavailable(
        CommandCode.unlock,
        'BLE 未连接',
      );
      final failed = ControlCommandResult.failure(
        CommandCode.powerOn,
        transport: ControlCommandTransport.ble,
        message: '命令发送失败',
      );

      expect(unavailable.success, isFalse);
      expect(unavailable.transport, ControlCommandTransport.unavailable);
      expect(unavailable.failureMessage, 'BLE 未连接');
      expect(failed.success, isFalse);
      expect(failed.failureMessage, '命令发送失败');
    });
  });

  group('ControlCommandPolicy', () {
    test('blocks find command when vehicle is already powered on', () {
      final result = ControlCommandPolicy.evaluate(
        command: CommandCode.find,
        isPowerOn: true,
      );

      expect(result.allowed, isFalse);
      expect(result.disabledReason, '车辆已上电，不能寻车');
    });

    test('allows find command when vehicle is powered off', () {
      final result = ControlCommandPolicy.evaluate(
        command: CommandCode.find,
        isPowerOn: false,
      );

      expect(result.allowed, isTrue);
      expect(result.disabledReason, isNull);
    });

    test('does not block other control commands while powered on', () {
      const commands = [
        CommandCode.lock,
        CommandCode.unlock,
        CommandCode.powerOn,
        CommandCode.powerOff,
        CommandCode.openSeat,
      ];

      for (final command in commands) {
        final result = ControlCommandPolicy.evaluate(
          command: command,
          isPowerOn: true,
        );

        expect(result.allowed, isTrue, reason: command.name);
        expect(result.disabledReason, isNull, reason: command.name);
      }
    });
  });

  group('ControlCommandExecutor', () {
    test('uses BLE sender for an available BLE route', () async {
      final calls = <CommandCode>[];
      final executor = ControlCommandExecutor(
        sendBleCommand: (command) async {
          calls.add(command);
          return true;
        },
        sendCloudCommand: (_) => fail('cloud sender should not be called'),
      );

      final result = await executor.send(
        command: CommandCode.lock,
        availability: _availability(
          channel: OfficialControlChannel.ble,
          canUseBle: true,
        ),
      );

      expect(result.success, isTrue);
      expect(result.transport, ControlCommandTransport.ble);
      expect(calls, [CommandCode.lock]);
    });

    test('uses official cloud sender for an available cloud route', () async {
      final calls = <CommandCode>[];
      final executor = ControlCommandExecutor(
        sendBleCommand: (_) => fail('BLE sender should not be called'),
        sendCloudCommand: (command) async {
          calls.add(command);
          return 'ok';
        },
      );

      final result = await executor.send(
        command: CommandCode.find,
        availability: _availability(
          channel: OfficialControlChannel.officialCloud,
          canUseCloud: true,
        ),
      );

      expect(result.success, isTrue);
      expect(result.transport, ControlCommandTransport.officialCloud);
      expect(result.successMessage, '寻车已完成');
      expect(calls, [CommandCode.find]);
    });

    test('automatic route prefers BLE before official cloud', () async {
      final calls = <String>[];
      final executor = ControlCommandExecutor(
        sendBleCommand: (command) async {
          calls.add('ble:${command.name}');
          return true;
        },
        sendCloudCommand: (command) async {
          calls.add('cloud:${command.name}');
          return 'ok';
        },
      );

      final result = await executor.send(
        command: CommandCode.powerOn,
        availability: _availability(canUseBle: true, canUseCloud: true),
      );

      expect(result.transport, ControlCommandTransport.ble);
      expect(calls, ['ble:powerOn']);
    });

    test(
      'automatic route falls back to official cloud when BLE is unavailable',
      () async {
        final calls = <String>[];
        final executor = ControlCommandExecutor(
          sendBleCommand: (command) async {
            calls.add('ble:${command.name}');
            return true;
          },
          sendCloudCommand: (command) async {
            calls.add('cloud:${command.name}');
            return 'ok';
          },
        );

        final result = await executor.send(
          command: CommandCode.unlock,
          availability: _availability(canUseCloud: true),
        );

        expect(result.transport, ControlCommandTransport.officialCloud);
        expect(calls, ['cloud:unlock']);
      },
    );

    test('unavailable route does not call any sender', () async {
      final executor = ControlCommandExecutor(
        sendBleCommand: (_) => fail('BLE sender should not be called'),
        sendCloudCommand: (_) => fail('cloud sender should not be called'),
      );

      final result = await executor.send(
        command: CommandCode.lock,
        availability: _availability(disabledReason: '不可用'),
      );

      expect(result.success, isFalse);
      expect(result.transport, ControlCommandTransport.unavailable);
      expect(result.failureMessage, '不可用');
    });

    test('maps BLE false and official cloud exception to failures', () async {
      final bleExecutor = ControlCommandExecutor(
        sendBleCommand: (_) async => false,
        sendCloudCommand: (_) => fail('cloud sender should not be called'),
      );
      final cloudExecutor = ControlCommandExecutor(
        sendBleCommand: (_) => fail('BLE sender should not be called'),
        sendCloudCommand: (_) async =>
            throw const OfficialCloudApiException('官方错误'),
      );

      final bleResult = await bleExecutor.send(
        command: CommandCode.powerOff,
        availability: _availability(
          channel: OfficialControlChannel.ble,
          canUseBle: true,
        ),
      );
      final cloudResult = await cloudExecutor.send(
        command: CommandCode.powerOff,
        availability: _availability(
          channel: OfficialControlChannel.officialCloud,
          canUseCloud: true,
        ),
      );

      expect(bleResult.success, isFalse);
      expect(bleResult.failureMessage, '熄火失败');
      expect(cloudResult.success, isFalse);
      expect(cloudResult.failureMessage, '官方错误');
    });

    test('maps command timeouts to transport failures', () async {
      final pendingBle = Completer<bool>();
      final pendingCloud = Completer<String>();
      final bleExecutor = ControlCommandExecutor(
        sendBleCommand: (_) => pendingBle.future,
        sendCloudCommand: (_) => fail('cloud sender should not be called'),
        bleTimeout: Duration.zero,
      );
      final cloudExecutor = ControlCommandExecutor(
        sendBleCommand: (_) => fail('BLE sender should not be called'),
        sendCloudCommand: (_) => pendingCloud.future,
        cloudTimeout: Duration.zero,
      );

      final bleResult = await bleExecutor.send(
        command: CommandCode.lock,
        availability: _availability(
          channel: OfficialControlChannel.ble,
          canUseBle: true,
        ),
      );
      final cloudResult = await cloudExecutor.send(
        command: CommandCode.find,
        availability: _availability(
          channel: OfficialControlChannel.officialCloud,
          canUseCloud: true,
        ),
      );

      expect(bleResult.success, isFalse);
      expect(bleResult.transport, ControlCommandTransport.ble);
      expect(bleResult.failureMessage, 'BLE command timed out');
      expect(cloudResult.success, isFalse);
      expect(cloudResult.transport, ControlCommandTransport.officialCloud);
      expect(cloudResult.failureMessage, 'Cloud command timed out');

      pendingBle.complete(true);
      pendingCloud.complete('ok');
    });
  });

  group('OfficialVehicleSelfCheck', () {
    test('keeps raw official status response without guessing meanings', () {
      final result = OfficialVehicleSelfCheck.fromResponse({
        'code': '200',
        'msg': '成功',
        'data': {'imei': '123456789012345', 'voltage': 52.6, 'fault': 0},
      });

      expect(result.code, 200);
      expect(result.displayMessage, '成功');
      expect(result.dataMap['voltage'], 52.6);
      expect(result.raw['msg'], '成功');

      final nonMap = OfficialVehicleSelfCheck.fromResponse({
        'code': 500,
        'data': 'not-map',
      });
      expect(nonMap.dataMap, isEmpty);
      expect(nonMap.displayMessage, 'code=500');
    });
  });

  group('Official map replica models', () {
    test('parses official parking location and fence fields', () {
      final locationJson = {
        'extendId': 'ext-1',
        'bleConnectTime': '2026-05-29 10:00:00',
        'bleConnectLat': '25.123456',
        'bleConnectLng': '104.654321',
        'carId': 'car-1',
        'bleConnectAddress': '停车点',
      };
      final location = OfficialVehicleLocation.fromJson(locationJson);
      final fence = OfficialFenceData.fromJson({
        'fenceRadius': '5',
        'fenceRadiusMax': '10',
        'fenceRadiusMin': '1',
        'fenceSwitch': '1',
        'fenceTimeFr': '08:00',
        'fenceTimeTo': '22:00',
      });
      locationJson['bleConnectAddress'] = 'mutated';

      expect(location.hasData, isTrue);
      expect(location.latitude, 25.123456);
      expect(location.longitude, 104.654321);
      expect(location.raw['bleConnectAddress'], '停车点');
      expect(fence.enabled, isTrue);
      expect(fence.statusLabel, '已开启');
      expect(fence.radiusLabel, '500m');
      expect(fence.radiusMeters, 500);
      expect(fence.timeLabel, '08:00 - 22:00');
    });

    test('parses official travel list and track points', () {
      final day = OfficialTravelDay.fromJson({
        'travelDate': '2026-05-29',
        'totalTime': '1800',
        'totalMileage': '12.5',
        'deviceTravelDtoList': [
          42,
          'bad-entry',
          {
            'deviceTravelId': 'travel-1',
            'travelDate': '2026-05-29',
            'startTime': '10:00',
            'endTime': '10:30',
            'mileage': '12.5',
            'averageSpeed': '25',
            'maxSpeed': '42',
            'min': '30',
          },
        ],
      });
      final point = OfficialTravelPoint.fromJson({
        'lat': '25.1',
        'lng': '104.1',
        'heading': '90',
        'speed': '20',
        'starsNum': '8',
        'reportTime': '2026-05-29 10:01:00',
      });

      expect(day.hasData, isTrue);
      expect(day.records, hasLength(1));
      expect(day.records.first.deviceTravelId, 'travel-1');
      expect(day.records.first.raw['min'], '30');
      expect(day.records.first.mileageLabel, '12.5km');
      expect(day.records.first.averageSpeedLabel, '25km/h');
      expect(point.hasCoordinate, isTrue);
      expect(point.latitude, 25.1);
      expect(point.longitude, 104.1);
    });

    test('rounds raw float trip speeds/mileage for display', () {
      final day = OfficialTravelDay.fromJson({
        'travelDate': '2026-06-01',
        'deviceTravelDtoList': [
          {
            'deviceTravelId': 'travel-2',
            'mileage': '604.0',
            'averageSpeed': '20.133333333333333',
            'maxSpeed': '45.6789',
          },
        ],
      });
      final record = day.records.first;
      expect(record.averageSpeedLabel, '20.1km/h');
      expect(record.maxSpeedLabel, '45.7km/h');
      expect(record.mileageLabel, '604km');
    });
  });
}

class _OfficialCloudTestServer {
  final HttpServer _server;

  const _OfficialCloudTestServer(this._server);

  String get apiBase =>
      'http://${_server.address.host}:${_server.port}/v1/api/';

  Future<void> close() => _server.close(force: true);
}

Future<_OfficialCloudTestServer> _startOfficialCloudServer(
  FutureOr<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    try {
      await handler(request);
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'msg': '$e'}));
      await request.response.close();
    }
  });
  return _OfficialCloudTestServer(server);
}

Future<void> _writeJsonResponse(
  HttpRequest request,
  int statusCode,
  Map<String, Object?> body,
) async {
  request.response.statusCode = statusCode;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  await request.response.close();
}

ControlChannelAvailability _availability({
  OfficialControlChannel channel = OfficialControlChannel.automatic,
  bool canUseBle = false,
  bool canUseCloud = false,
  String disabledReason = '请连接 BLE 或登录官方账号后再控车',
}) {
  final willUseBle =
      channel == OfficialControlChannel.ble ||
      (channel == OfficialControlChannel.automatic && canUseBle);
  return ControlChannelAvailability(
    channel: channel,
    canUseBle: canUseBle,
    canUseCloud: canUseCloud,
    enabled: canUseBle || canUseCloud,
    willUseBle: willUseBle,
    effectiveChannelLabel: willUseBle
        ? 'BLE'
        : canUseCloud
        ? '官方云端'
        : '不可用',
    bleUnavailableReason: canUseBle ? '' : 'BLE 未连接或协议未就绪',
    cloudUnavailableReason: canUseCloud ? '' : '请先登录官方账号',
    disabledReason: disabledReason,
  );
}

OfficialCloudState _cloudState({
  OfficialControlChannel channel = OfficialControlChannel.automatic,
  bool signedIn = false,
  bool withVehicle = false,
  Map<String, String> links = const {},
}) {
  final vehicle = OfficialVehicle.fromJson({
    'carId': 'official-1',
    'carNickName': '测试车辆',
  });
  return OfficialCloudState.initial().copyWith(
    token: signedIn ? 'token' : '',
    vehicles: withVehicle ? [vehicle] : const <OfficialVehicle>[],
    selectedVehicleKey: withVehicle ? vehicle.key : null,
    controlChannel: channel,
    localVehicleLinks: links,
  );
}
