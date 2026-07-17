import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/models/command_types.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/services/control_channel_resolver.dart';
import 'package:tailg_ble_app/services/control_command_executor.dart';
import 'package:tailg_ble_app/services/control_command_policy.dart';
import 'package:tailg_ble_app/services/control_command_result.dart';
import 'package:tailg_ble_app/services/log_service.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

import 'helpers/source_scan.dart';
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
      expect(vehicle.normalizedDeviceMac, 'AA:BB:CC:DD:EE:FF');
      expect(vehicle.hasDeviceMac, isTrue);
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

      expect(vehicle.normalizedDeviceMac, 'AA:BB:CC:DD:EE:FF');
      expect(vehicle.hasDeviceMac, isTrue);
    });

    test('rejects invalid official bluetooth mac', () {
      final vehicle = OfficialVehicle.fromJson({'btmac': 'not-a-mac'});

      expect(vehicle.normalizedDeviceMac, isEmpty);
      expect(vehicle.hasDeviceMac, isFalse);
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
      expect(vehicle.supportsServiceRenewal, isTrue);
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
      expect(vehicle.supportsServiceRenewal, isFalse);
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

    test('serializes official raw fields without exposing stored raw map', () {
      final vehicle = OfficialVehicle.fromJson({
        'carId': 'car-1',
        'customFlag': 'raw',
      });

      final json = vehicle.toJson();
      json['customFlag'] = 'changed';

      expect(identical(json, vehicle.raw), isFalse);
      expect(vehicle.raw['customFlag'], 'raw');
      expect(vehicle.toJson()['customFlag'], 'raw');
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

    test('records request summary with injected clock', () async {
      final server = await _startOfficialCloudServer((request) async {
        await _writeJsonResponse(request, 200, {
          'code': '200',
          'msg': 'ok userId=user-secret password=qgj-secret',
        });
      });
      addTearDown(server.close);

      final startedAt = DateTime(2026, 6, 1, 8);
      final completedAt = startedAt.add(const Duration(milliseconds: 150));
      final clockTimes = [startedAt, completedAt];
      final client = OfficialCloudApiClient(
        config: OfficialCloudApiConfig(apiBase: server.apiBase),
        log: LogService(),
        clock: () => clockTimes.removeAt(0),
      );
      addTearDown(client.dispose);

      await client.request('app/read', method: 'GET');

      final summary = client.lastRequest;
      expect(summary, isNotNull);
      expect(summary!.elapsed, const Duration(milliseconds: 150));
      expect(summary.at, completedAt);
      expect(summary.message, 'ok userId=use***ret password=qgj***ret');
    });

    test('does not retry 5xx responses by default', () async {
      var requests = 0;
      final server = await _startOfficialCloudServer((request) async {
        requests++;
        await _writeJsonResponse(request, 502, {
          'msg': 'gateway busy userId=user-secret password=qgj-secret',
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

      await expectLater(
        client.request('app/device/cmd/lock', method: 'POST'),
        throwsA(
          isA<OfficialCloudApiException>()
              .having((e) => e.statusCode, 'statusCode', 502)
              .having(
                (e) => e.message,
                'message',
                'gateway busy userId=use***ret password=qgj***ret',
              ),
        ),
      );

      expect(requests, 1);
      expect(client.lastRequest?.statusCode, 502);
      expect(client.lastRequest?.success, isFalse);
      expect(
        client.lastRequest?.message,
        'gateway busy userId=use***ret password=qgj***ret',
      );
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

  group('OfficialCloudService errors', () {
    test('redacts business failure messages before throwing', () {
      final source = readSource('lib/services/official_cloud_service.dart');
      final methodStart = source.indexOf('void _ensureSuccess(');
      final methodEnd = source.indexOf('  void _setLoading(', methodStart);

      expect(methodStart, greaterThanOrEqualTo(0));
      expect(methodEnd, greaterThan(methodStart));

      final methodSource = source.substring(methodStart, methodEnd);

      expect(methodSource, contains('OfficialCloudRedactor.text('));
      expect(
        methodSource,
        isNot(
          contains(
            'throw OfficialCloudApiException(\n'
            '        msg == null || msg.isEmpty ? fallback : msg,',
          ),
        ),
      );
    });

    test('uses the shared redactor before publishing error state', () {
      final source = readSource('lib/services/official_cloud_service.dart');

      expect(source, contains('OfficialCloudRedactor.errorMessage(e)'));
      // Error state fields must go through the redactor, not raw toString.
      expect(RegExp(r'error:\s*e\.toString\(\)').hasMatch(source), isFalse);
      expect(RegExp(r'Error:\s*e\.toString\(\)').hasMatch(source), isFalse);
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
          'app/getCode?phone=18886120851&imei=860123456789377&btmac=aabbccddeeff&userId=user-secret&password=qgj-secret&mac=AA:BB:CC:DD:EE:FF',
        ),
        'app/getCode?phone=188***851&imei=860***377&btmac=aab***eff&userId=use***ret&password=qgj***ret&mac=AA:***:FF',
      );
      expect(
        OfficialCloudRedactor.text(
          'phone=18886120851 imei=860123456789377 mac=AA:BB:CC:DD:EE:FF compact=aabbccddeeff userId=user-secret password=qgj-secret authorization=raw-secret-token Bearer bearer-secret-token frame=L12345678901234567',
        ),
        'phone=188***851 imei=860***377 mac=AA:***:FF compact=aab***eff userId=use***ret password=qgj***ret authorization=raw***ken Bearer bea***ken frame=L12***567',
      );
    });

    test('normalizes API and generic exceptions through one entry point', () {
      expect(
        OfficialCloudRedactor.errorMessage(
          const OfficialCloudApiException('phone=18886120851'),
        ),
        'phone=188***851',
      );
      expect(
        OfficialCloudRedactor.errorMessage(
          Exception('authorization=raw-secret-token'),
        ),
        'Exception: authorization=raw***ken',
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
      final vehicleJson = {'carId': 'car-1', 'carNickName': 'A'};
      final list = OfficialCloudDataParser.vehicles([
        vehicleJson,
        {'carId': '', 'carNickName': 'invalid'},
        'ignored',
      ]);
      final single = OfficialCloudDataParser.vehicles({
        'carId': 'car-2',
        'carNickName': 'B',
      });
      final invalidSingle = OfficialCloudDataParser.vehicles('ignored');
      vehicleJson['carNickName'] = 'mutated';

      expect(list, hasLength(1));
      expect(list.first.displayName, 'A');
      expect(list.first.raw['carNickName'], 'A');
      expect(single, hasLength(1));
      expect(single.first.displayName, 'B');
      expect(invalidSingle, isEmpty);
    });

    test('parses user profile nickName from getUserProfile data', () {
      final profile = OfficialCloudDataParser.userProfile({
        'id': 'u-1',
        'nickName': '极光骑士',
        'avatar_path': 'https://cdn.example.com/a.png',
        'signature': 'ride on',
      });
      expect(profile, isNotNull);
      expect(profile!.displayName, '极光骑士');
      expect(profile.avatarUrl, 'https://cdn.example.com/a.png');
      expect(OfficialCloudDataParser.userProfile(null), isNull);
      expect(OfficialCloudDataParser.userProfile(<String, dynamic>{}), isNull);
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

    test('ignores non-map list payload items', () {
      final days = OfficialCloudDataParser.travelDays(['ignored', 42, null]);
      final points = OfficialCloudDataParser.travelPoints(['ignored', 42]);

      expect(days, isEmpty);
      expect(points, isEmpty);
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

    test(
      'logs corrupt persisted vehicle links and loads empty links',
      () async {
        SharedPreferences.setMockInitialValues({
          'official_cloud_vehicle_links': '{',
        });

        final service = OfficialCloudService();
        await service.init();

        expect(service.state.localVehicleLinks, isEmpty);
        final warning = LogService().all.singleWhere(
          (entry) =>
              entry.message == '官云本地车辆关联数据损坏，已忽略' &&
              entry.level == LogLevel.warning,
        );
        expect(warning.detail, contains('FormatException'));
      },
    );

    test(
      'logs decoded null persisted vehicle links as a shape warning',
      () async {
        SharedPreferences.setMockInitialValues({
          'official_cloud_vehicle_links': 'null',
        });

        final service = OfficialCloudService();
        await service.init();

        expect(service.state.localVehicleLinks, isEmpty);
        final warning = LogService().all.singleWhere(
          (entry) =>
              entry.message == '官云本地车辆关联数据格式异常，已忽略' &&
              entry.level == LogLevel.warning,
        );
        expect(warning.detail, 'Expected JSON object, got Null');
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

    test(
      'logs decoded null cached carControlInfo with login session',
      () async {
        SharedPreferences.setMockInitialValues({
          'official_cloud_token': 'cached-token',
          'official_cloud_phone': '18800001111',
          'official_cloud_user_id': 'user-1',
          'carControlInfo': 'null',
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
        expect(warning.detail, 'type=Null');
      },
    );

    test('logs corrupt cached carControlInfo with login session', () async {
      SharedPreferences.setMockInitialValues({
        'official_cloud_token': 'cached-token',
        'official_cloud_phone': '18800001111',
        'official_cloud_user_id': 'user-1',
        'carControlInfo': '{',
      });

      final service = OfficialCloudService();
      await service.initForTest();

      expect(service.state.signedIn, isTrue);
      expect(service.state.vehicles, isEmpty);
      final warning = LogService().all.singleWhere(
        (entry) =>
            entry.message == '官云车辆控制缓存损坏，已忽略' &&
            entry.level == LogLevel.warning,
      );
      expect(warning.detail, contains('FormatException'));
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

    test('uses injected clock for missing uid travel month', () async {
      final vehicle = OfficialVehicle.fromJson({
        'carId': 'car-4',
        'carNickName': '轨迹车',
        'frame': 'FRAME-4',
      });
      final service = OfficialCloudService();
      service.resetForTest(clock: () => DateTime(2026, 7, 6, 10));
      service.setStateForTest(
        OfficialCloudState.initial().copyWith(
          initialized: true,
          token: 'token',
          vehicles: [vehicle],
          selectedVehicleKey: vehicle.key,
        ),
      );

      await service.refreshTravelHistory();

      expect(service.state.travelMonth, '2026-07');
      expect(service.state.travelDays, isEmpty);
      expect(service.state.travelError, '官方登录未返回 uid，无法读取历史轨迹');
    });
  });

  group('OfficialCloudService P1 cloud contracts', () {
    setUp(() {
      resetMockStorage();
      OfficialCloudService().resetForTest();
      LogService().clear();
    });

    tearDown(() {
      OfficialCloudService().resetForTest();
      LogService().clear();
    });

    test('writes car nickname and refreshes vehicle cache', () async {
      final requestBodies = <String, Map<String, dynamic>?>{};
      var carStatusCalls = 0;
      final server = await _startOfficialCloudServer((request) async {
        final bodyText = await utf8.decoder.bind(request).join();
        requestBodies[request.uri.path] = bodyText.isEmpty
            ? null
            : jsonDecode(bodyText) as Map<String, dynamic>;
        if (request.uri.path.endsWith('/app/car/updateCarInfo')) {
          await _writeJsonResponse(request, 200, {
            'code': '200',
            'msg': 'success',
          });
          return;
        }
        if (request.uri.path.endsWith('/app/centralControl/carStatus')) {
          carStatusCalls += 1;
          await _writeJsonResponse(request, 200, {
            'code': '200',
            'msg': 'success',
            'data': {
              'carId': 'nick-car',
              'carNickName': '新昵称',
              'carName': '型号车',
            },
          });
          return;
        }
        await _writeJsonResponse(request, 404, {'msg': 'unexpected path'});
      });
      final service = OfficialCloudService();
      try {
        service.resetForTest(
          apiConfig: OfficialCloudApiConfig(
            apiBase: server.apiBase,
            retryBaseDelay: Duration.zero,
          ),
        );
        final vehicle = OfficialVehicle.fromJson({
          'carId': 'nick-car',
          'carNickName': '旧昵称',
          'carName': '型号车',
        });
        service.setStateForTest(
          OfficialCloudState.initial().copyWith(
            initialized: true,
            token: 'test-token',
            vehicles: [vehicle],
            selectedVehicleKey: vehicle.key,
          ),
        );

        await service.updateCarNickName(
          carId: 'nick-car',
          carNickName: ' 新昵称 ',
        );

        expect(requestBodies['/v1/api/app/car/updateCarInfo'], {
          'carId': 'nick-car',
          'carNickName': '新昵称',
        });
        expect(carStatusCalls, greaterThanOrEqualTo(1));
        expect(service.state.selectedVehicle?.carNickName, '新昵称');
        expect(service.state.selectedVehicle?.displayName, '新昵称');
      } finally {
        service.resetForTest();
        await server.close();
      }
    });

    test('writes fence settings and refreshes the saved state', () async {
      final requestBodies = <String, Map<String, dynamic>?>{};
      final server = await _startOfficialCloudServer((request) async {
        final text = await utf8.decoder.bind(request).join();
        requestBodies[request.uri.path] = text.isEmpty
            ? null
            : jsonDecode(text) as Map<String, dynamic>;
        if (request.uri.path.endsWith('/app/device/updFenceData')) {
          await _writeJsonResponse(request, 200, {
            'code': '200',
            'msg': 'success',
          });
          return;
        }
        if (request.uri.path.endsWith('/app/device/getFenceData')) {
          await _writeJsonResponse(request, 200, {
            'code': '200',
            'msg': 'success',
            'data': {
              'fenceSwitch': '1',
              'fenceRadius': '5',
              'fenceRadiusMin': '1',
              'fenceRadiusMax': '100',
              'fenceTimeFr': '08:00',
              'fenceTimeTo': '22:00',
            },
          });
          return;
        }
        await _writeJsonResponse(request, 404, {'msg': 'unexpected path'});
      });
      final service = OfficialCloudService();
      try {
        service.resetForTest(
          apiConfig: OfficialCloudApiConfig(
            apiBase: server.apiBase,
            retryBaseDelay: Duration.zero,
          ),
        );
        final vehicle = OfficialVehicle.fromJson({
          'carId': 'fence-car',
          'carNickName': '围栏测试车',
        });
        service.setStateForTest(
          OfficialCloudState.initial().copyWith(
            initialized: true,
            token: 'test-token',
            vehicles: [vehicle],
            selectedVehicleKey: vehicle.key,
          ),
        );

        await service.updateFenceData(
          enabled: true,
          radiusValue: 5,
          timeFrom: '08:00',
          timeTo: '22:00',
        );

        expect(
          requestBodies['/v1/api/app/device/updFenceData'],
          containsPair('carId', 'fence-car'),
        );
        expect(
          requestBodies['/v1/api/app/device/updFenceData'],
          containsPair('fenceSwitch', '1'),
        );
        expect(
          requestBodies['/v1/api/app/device/updFenceData'],
          containsPair('fenceRadius', '5'),
        );
        expect(requestBodies['/v1/api/app/device/getFenceData'], {
          'carId': 'fence-car',
        });
        expect(service.state.fenceData?.enabled, isTrue);
        expect(service.state.fenceData?.fenceRadius, '5');
      } finally {
        service.resetForTest();
        await server.close();
      }
    });

    test('reads, writes, and clears official message settings', () async {
      final requestBodies = <String, Map<String, dynamic>?>{};
      final authorizationHeaders = <String, String?>{};
      final server = await _startOfficialCloudServer((request) async {
        final text = await utf8.decoder.bind(request).join();
        requestBodies[request.uri.path] = text.isEmpty
            ? null
            : jsonDecode(text) as Map<String, dynamic>;
        authorizationHeaders[request.uri.path] = request.headers.value(
          HttpHeaders.authorizationHeader,
        );
        if (request.uri.path.endsWith('/app/msg/getMessageControl')) {
          await _writeJsonResponse(request, 200, {
            'code': '200',
            'msg': 'success',
            'data': {'carMsg': '1', 'sysMsg': 0, 'alarm': true},
          });
          return;
        }
        if (request.uri.path.endsWith('/app/msg/setMessagePushConfig') ||
            request.uri.path.endsWith('/app/msg/delMsg')) {
          await _writeJsonResponse(request, 200, {
            'code': '200',
            'msg': 'success',
          });
          return;
        }
        await _writeJsonResponse(request, 404, {'msg': 'unexpected path'});
      });
      final service = OfficialCloudService();
      try {
        service.resetForTest(
          apiConfig: OfficialCloudApiConfig(
            apiBase: server.apiBase,
            retryBaseDelay: Duration.zero,
          ),
        );
        service.setStateForTest(
          OfficialCloudState.initial().copyWith(
            initialized: true,
            token: 'test-token',
            vehicleMessages: [
              OfficialCloudMessage.vehicle({
                'msgId': 'vehicle-message',
                'title': '车辆消息',
              }),
            ],
            systemMessages: [
              OfficialCloudMessage.system({
                'sysMessageRecordId': 'system-message',
                'title': '系统消息',
              }),
            ],
          ),
        );

        final config = await service.getMessageControl();
        await service.setMessagePushConfig({'carMsg': false, 'sysMsg': true});
        await service.deleteMessages();

        expect(config, {'carMsg': true, 'sysMsg': false, 'alarm': true});
        expect(requestBodies['/v1/api/app/msg/setMessagePushConfig'], {
          'carMsg': '0',
          'sysMsg': '1',
        });
        expect(requestBodies['/v1/api/app/msg/delMsg'], isNull);
        expect(authorizationHeaders.values, everyElement('test-token'));
        expect(service.state.vehicleMessages, isEmpty);
        expect(service.state.systemMessages, isEmpty);
      } finally {
        service.resetForTest();
        await server.close();
      }
    });

    test('failed server-side message deletion preserves messages', () async {
      final server = await _startOfficialCloudServer((request) async {
        await _writeJsonResponse(request, 200, {
          'code': '500',
          'msg': '服务端拒绝清空',
        });
      });
      final service = OfficialCloudService();
      try {
        service.resetForTest(
          apiConfig: OfficialCloudApiConfig(
            apiBase: server.apiBase,
            retryBaseDelay: Duration.zero,
          ),
        );
        service.setStateForTest(
          OfficialCloudState.initial().copyWith(
            initialized: true,
            token: 'test-token',
            vehicleMessages: [
              OfficialCloudMessage.vehicle({
                'msgId': 'message-to-keep',
                'title': '保留消息',
              }),
            ],
          ),
        );

        await expectLater(
          service.deleteMessages(),
          throwsA(
            isA<OfficialCloudApiException>().having(
              (error) => error.message,
              'message',
              '服务端拒绝清空',
            ),
          ),
        );
        expect(service.state.vehicleMessages, hasLength(1));
      } finally {
        service.resetForTest();
        await server.close();
      }
    });
  });

  group('ControlChannelResolver', () {
    test(
      'enables official cloud only when signed in with a selected vehicle',
      () {
        final available = ControlChannelResolver.resolve(
          cloudState: _cloudState(signedIn: true, withVehicle: true),
          channel: OfficialControlChannel.officialCloud,
        );
        final missingVehicle = ControlChannelResolver.resolve(
          cloudState: _cloudState(signedIn: true),
          channel: OfficialControlChannel.officialCloud,
        );
        final signedOut = ControlChannelResolver.resolve(
          cloudState: _cloudState(),
          channel: OfficialControlChannel.officialCloud,
        );

        expect(available.enabled, isTrue);
        expect(available.effectiveChannelLabel, '官方云端');
        expect(missingVehicle.enabled, isFalse);
        expect(missingVehicle.disabledReason, '官方账号未选择车辆');
        expect(signedOut.enabled, isFalse);
        expect(signedOut.disabledReason, '请先登录官方账号');
      },
    );

    test('busy state disables an otherwise available route', () {
      final availability = ControlChannelResolver.resolve(
        cloudState: _cloudState(signedIn: true, withVehicle: true),
        channel: OfficialControlChannel.officialCloud,
        busy: true,
      );

      expect(availability.canUseCloud, isTrue);
      expect(availability.enabled, isFalse);
      expect(availability.disabledReason, '正在执行控车指令，请稍候');
      expect(availability.disabledReason, isNot(contains('请登录官方账号并选择车辆后再控车')));
    });

    test('busy state keeps signed-out reason when cloud is unavailable', () {
      final availability = ControlChannelResolver.resolve(
        cloudState: _cloudState(),
        channel: OfficialControlChannel.officialCloud,
        busy: true,
      );

      expect(availability.canUseCloud, isFalse);
      expect(availability.enabled, isFalse);
      expect(availability.disabledReason, '请先登录官方账号');
    });

    test('automatic mode prefers BLE when ready', () {
      final availability = ControlChannelResolver.resolve(
        cloudState: _cloudState(signedIn: true, withVehicle: true),
        bleReady: true,
        channel: OfficialControlChannel.automatic,
      );

      expect(availability.enabled, isTrue);
      expect(availability.canUseBle, isTrue);
      expect(availability.willUseBle, isTrue);
      expect(availability.effectiveChannelLabel, 'BLE');
    });

    test(
      'automatic mode falls back to cloud only when vehicle has remote ability',
      () {
        final withGps = ControlChannelResolver.resolve(
          cloudState: _cloudState(
            signedIn: true,
            withVehicle: true,
            withGpsService: true,
          ),
          bleReady: false,
          channel: OfficialControlChannel.automatic,
        );
        final pureBle = ControlChannelResolver.resolve(
          cloudState: _cloudState(signedIn: true, withVehicle: true),
          bleReady: false,
          channel: OfficialControlChannel.automatic,
        );

        expect(withGps.enabled, isTrue);
        expect(withGps.canUseCloud, isTrue);
        expect(withGps.willUseBle, isFalse);
        expect(withGps.vehicleAllowsCloudFallback, isTrue);
        expect(withGps.effectiveChannelLabel, '官方云端');

        expect(pureBle.enabled, isFalse);
        expect(pureBle.canUseCloud, isFalse);
        expect(pureBle.vehicleAllowsCloudFallback, isFalse);
        expect(pureBle.disabledReason, contains('蓝牙'));
      },
    );
  });

  group('ControlCommandResult', () {
    test('keeps cloud success message', () {
      final result = ControlCommandResult.cloudSuccess(
        CommandCode.find,
        message: 'success',
      );

      expect(result.success, isTrue);
      expect(result.transport, ControlCommandTransport.officialCloud);
      expect(result.successMessage, '寻车已完成');
    });

    test('carries unavailable and failed command messages', () {
      final unavailable = ControlCommandResult.unavailable(
        CommandCode.unlock,
        '云端不可用',
      );
      final failed = ControlCommandResult.failure(
        CommandCode.powerOn,
        message: '命令发送失败',
      );

      expect(unavailable.success, isFalse);
      expect(unavailable.transport, ControlCommandTransport.unavailable);
      expect(unavailable.failureMessage, '云端不可用');
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
    ControlChannelAvailability availableCloud() {
      return ControlChannelResolver.resolve(
        cloudState: _cloudState(signedIn: true, withVehicle: true),
        channel: OfficialControlChannel.officialCloud,
      );
    }

    test('uses official cloud sender for a command', () async {
      final calls = <CommandCode>[];
      final executor = ControlCommandExecutor(
        sendCloudCommand: (command) async {
          calls.add(command);
          return 'ok';
        },
      );

      final result = await executor.send(
        command: CommandCode.find,
        availability: availableCloud(),
      );

      expect(result.success, isTrue);
      expect(result.transport, ControlCommandTransport.officialCloud);
      expect(result.successMessage, '寻车已完成');
      expect(calls, [CommandCode.find]);
    });

    test('maps official cloud exception to failure', () async {
      final executor = ControlCommandExecutor(
        sendCloudCommand: (_) async =>
            throw const OfficialCloudApiException('官方错误'),
      );

      final result = await executor.send(
        command: CommandCode.powerOff,
        availability: availableCloud(),
      );

      expect(result.success, isFalse);
      expect(result.failureMessage, '官方错误');
    });

    test('maps command timeouts to transport failures', () async {
      final pendingCloud = Completer<String>();
      final executor = ControlCommandExecutor(
        sendCloudCommand: (_) => pendingCloud.future,
        cloudTimeout: Duration.zero,
      );

      final result = await executor.send(
        command: CommandCode.find,
        availability: availableCloud(),
      );

      expect(result.success, isFalse);
      expect(result.transport, ControlCommandTransport.officialCloud);
      expect(result.failureMessage, 'Cloud command timed out');

      pendingCloud.complete('ok');
    });

    test('prefers BLE in automatic mode when ready', () async {
      final bleCalls = <CommandCode>[];
      final cloudCalls = <CommandCode>[];
      final executor = ControlCommandExecutor(
        sendBleCommand: (command) async {
          bleCalls.add(command);
          return true;
        },
        sendCloudCommand: (command) async {
          cloudCalls.add(command);
          return 'ok';
        },
      );

      final availability = ControlChannelResolver.resolve(
        cloudState: _cloudState(signedIn: true, withVehicle: true),
        bleReady: true,
        channel: OfficialControlChannel.automatic,
      );
      final result = await executor.send(
        command: CommandCode.lock,
        availability: availability,
      );

      expect(result.success, isTrue);
      expect(result.transport, ControlCommandTransport.ble);
      expect(bleCalls, [CommandCode.lock]);
      expect(cloudCalls, isEmpty);
    });

    test('automatic mode uses cloud only for remote-capable vehicles', () async {
      final bleCalls = <CommandCode>[];
      final cloudCalls = <CommandCode>[];
      final executor = ControlCommandExecutor(
        sendBleCommand: (command) async {
          bleCalls.add(command);
          return true;
        },
        sendCloudCommand: (command) async {
          cloudCalls.add(command);
          return 'ok';
        },
      );

      final availability = ControlChannelResolver.resolve(
        cloudState: _cloudState(
          signedIn: true,
          withVehicle: true,
          withGpsService: true,
        ),
        bleReady: false,
        channel: OfficialControlChannel.automatic,
      );
      final result = await executor.send(
        command: CommandCode.unlock,
        availability: availability,
      );

      expect(result.success, isTrue);
      expect(result.transport, ControlCommandTransport.officialCloud);
      expect(bleCalls, isEmpty);
      expect(cloudCalls, [CommandCode.unlock]);
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

    test('keeps self-check raw maps immutable', () {
      final result = OfficialVehicleSelfCheck.fromResponse({
        'code': '200',
        'data': {'voltage': 52.6},
      });

      expect(() => result.dataMap['voltage'] = 48.0, throwsUnsupportedError);
      expect(() => result.raw['code'] = '500', throwsUnsupportedError);
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

    test('keeps replica model raw maps immutable', () {
      final location = OfficialVehicleLocation.fromJson({
        'latitude': '25.1',
        'longitude': '104.1',
      });
      final day = OfficialTravelDay.fromJson({
        'travelDate': '2026-06-01',
        'deviceTravelDtoList': [
          {'deviceTravelId': 'trip-1', 'mileage': '1.0'},
        ],
      });

      expect(() => location.raw['latitude'] = '0', throwsUnsupportedError);
      expect(() => day.raw['travelDate'] = 'changed', throwsUnsupportedError);
      expect(
        () => day.records.first.raw['mileage'] = '0',
        throwsUnsupportedError,
      );
    });

    test('parses official travel list and track points', () {
      final recordJson = {
        'deviceTravelId': 'travel-1',
        'travelDate': '2026-05-29',
        'startTime': '10:00',
        'endTime': '10:30',
        'mileage': '12.5',
        'averageSpeed': '25',
        'maxSpeed': '42',
        'min': '30',
      };
      final day = OfficialTravelDay.fromJson({
        'travelDate': '2026-05-29',
        'totalTime': '1800',
        'totalMileage': '12.5',
        'deviceTravelDtoList': [42, 'bad-entry', recordJson],
      });
      final point = OfficialTravelPoint.fromJson({
        'lat': '25.1',
        'lng': '104.1',
        'heading': '90',
        'speed': '20',
        'starsNum': '8',
        'reportTime': '2026-05-29 10:01:00',
      });
      recordJson['min'] = 'mutated';

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

    test('ignores non-list official travel record payloads', () {
      final day = OfficialTravelDay.fromJson({
        'travelDate': '2026-06-01',
        'deviceTravelDtoList': {'deviceTravelId': 'travel-ignored'},
      });

      expect(day.hasData, isTrue);
      expect(day.records, isEmpty);
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

    test('aggregates travel mileage and duration across records', () {
      final day = OfficialTravelDay.fromJson({
        'travelDate': '2026-06-01',
        'deviceTravelDtoList': [
          {
            'deviceTravelId': 'a',
            'mileage': '12.5',
            'hours': '1',
            'min': '30',
            'sec': '0',
          },
          {
            'deviceTravelId': 'b',
            'mileage': '7.5',
            'hours': '0',
            'min': '45',
            'sec': '30',
          },
        ],
      });

      expect(sumTravelMileageKm(day.records), 20.0);
      expect(
        sumTravelDurationSeconds(day.records),
        1 * 3600 + 30 * 60 + 45 * 60 + 30,
      );
      expect(formatCompactDuration(5430), '1h30m');
      expect(formatCompactDuration(45 * 60), '45m');
      expect(formatCompactDuration(0), '0m');
      expect(formatCompactDuration(0, emptyWhenZero: true), '');
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

OfficialCloudState _cloudState({
  bool signedIn = false,
  bool withVehicle = false,
  bool withGpsService = false,
}) {
  final vehicle = OfficialVehicle.fromJson({
    'carId': 'official-1',
    'carNickName': '测试车辆',
    if (withGpsService) ...{
      // Official isGps==1 equivalent: GPS model type + imeiGps.
      'modelType': 8,
      'imeiGps': '860123456789012',
    },
  });
  return OfficialCloudState.initial().copyWith(
    token: signedIn ? 'token' : '',
    vehicles: withVehicle ? [vehicle] : const <OfficialVehicle>[],
    selectedVehicleKey: withVehicle ? vehicle.key : null,
  );
}
