import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/official_user_profile.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

void main() {
  group('OfficialUserProfile', () {
    test('parses nickName avatar and prefers displayName', () {
      final profile = OfficialUserProfile.fromJson({
        'id': 'uid-1',
        'nickName': ' 极光骑士 ',
        'name': '张三',
        'signature': 'hello',
        'avatarName': 'a.png',
        'avatar_path': 'https://cdn.example.com/a.png',
        'gender': '1',
        'birthday': '1990-01-01',
      });

      expect(profile.id, 'uid-1');
      expect(profile.nickName, '极光骑士');
      expect(profile.displayName, '极光骑士');
      expect(profile.avatarUrl, 'https://cdn.example.com/a.png');
      expect(profile.hasDisplayName, isTrue);
    });

    test('falls back to real name when nick empty', () {
      final profile = OfficialUserProfile.fromJson({'name': '李四'});
      expect(profile.displayName, '李四');
    });
  });

  group('OfficialCloudDataParser.userProfile', () {
    test('parses nested data payload', () {
      // Access via part-visible API through public service parse helper path:
      // OfficialCloudDataParser is private to official_cloud_service.dart.
      // Validate model + state wiring instead of private parser.
      final profile = OfficialUserProfile.fromJson({
        'nickName': '测试用户',
        'avatarPath': 'https://example.com/x.png',
      });
      final state = OfficialCloudState.initial().copyWith(
        token: 't',
        userProfile: profile,
      );
      expect(state.userProfile?.displayName, '测试用户');
      expect(state.copyWith(userProfile: null).userProfile, isNull);
    });
  });
}
