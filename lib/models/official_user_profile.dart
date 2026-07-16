import 'persistence_value.dart';

/// Official user profile from `POST app/getUserProfile`.
///
/// Decompiled: [UserInfoBean] — nickName / avatar / signature etc.
/// No member level or points balance on this payload.
class OfficialUserProfile {
  final String id;
  final String nickName;
  final String name;
  final String signature;
  final String avatarName;
  final String avatarPath;
  final String gender;
  final String birthday;
  final Map<String, dynamic> raw;

  const OfficialUserProfile({
    required this.id,
    required this.nickName,
    required this.name,
    required this.signature,
    required this.avatarName,
    required this.avatarPath,
    required this.gender,
    required this.birthday,
    this.raw = const {},
  });

  factory OfficialUserProfile.fromJson(Map<String, dynamic> json) {
    return OfficialUserProfile(
      id: parsePersistedString(json['id']),
      nickName: parsePersistedString(json['nickName']),
      name: parsePersistedString(json['name']),
      signature: parsePersistedString(json['signature']),
      avatarName: parsePersistedString(json['avatarName']),
      avatarPath: parsePersistedString(
        json['avatar_path'] ?? json['avatarPath'],
      ),
      gender: parsePersistedString(json['gender']),
      birthday: parsePersistedString(json['birthday'] ?? json['birthDay']),
      raw: Map<String, dynamic>.unmodifiable(json),
    );
  }

  /// Prefer social nick, then real name.
  String get displayName {
    final nick = nickName.trim();
    if (nick.isNotEmpty) return nick;
    final real = name.trim();
    if (real.isNotEmpty) return real;
    return '';
  }

  String? get avatarUrl {
    final path = avatarPath.trim();
    if (path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return path;
  }

  bool get hasDisplayName => displayName.isNotEmpty;
}
