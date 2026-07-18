import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/services/official_remote_error_messages.dart';

void main() {
  group('OfficialRemoteErrorMessages (P0-B3)', () {
    test('maps token / 401 to re-login guidance', () {
      expect(
        OfficialRemoteErrorMessages.describe(
          const OfficialCloudApiException('token expired', statusCode: 401),
        ),
        OfficialRemoteErrorMessages.sessionExpired,
      );
      expect(
        OfficialRemoteErrorMessages.describe(Exception('Unauthorized 401')),
        OfficialRemoteErrorMessages.sessionExpired,
      );
    });

    test('maps network failures to check-network guidance', () {
      expect(
        OfficialRemoteErrorMessages.describe(
          const OfficialCloudApiException('官方 MQTT 网络失败: SocketException'),
        ),
        OfficialRemoteErrorMessages.networkUnavailable,
      );
      expect(
        OfficialRemoteErrorMessages.describe(
          Exception('SocketException: Failed host lookup'),
        ),
        OfficialRemoteErrorMessages.networkUnavailable,
      );
    });

    test('preserves explicit sign-in required copy', () {
      expect(
        OfficialRemoteErrorMessages.describe(
          const OfficialCloudApiException(
            OfficialCloudMessages.signInAndSelectVehicleRequired,
          ),
        ),
        OfficialCloudMessages.signInAndSelectVehicleRequired,
      );
    });

    test('maps generic MQTT connect failures to broker guidance', () {
      expect(
        OfficialRemoteErrorMessages.describe(
          const OfficialCloudApiException('官方 MQTT 连接失败: disconnected'),
        ),
        OfficialRemoteErrorMessages.brokerUnreachable,
      );
    });
  });
}
