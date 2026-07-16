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
  final String obsAvatarId;
  final String province;
  final String city;
  final String area;
  final String address;
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
    this.obsAvatarId = '',
    this.province = '',
    this.city = '',
    this.area = '',
    this.address = '',
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
      obsAvatarId: parsePersistedString(json['obsAvatarId']),
      province: parsePersistedString(json['province']),
      city: parsePersistedString(json['city']),
      area: parsePersistedString(json['area']),
      address: parsePersistedString(json['address']),
      raw: Map<String, dynamic>.unmodifiable(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickName': nickName,
      'name': name,
      'signature': signature,
      'avatarName': avatarName,
      'avatar_path': avatarPath,
      'gender': gender,
      'birthday': birthday,
      'obsAvatarId': obsAvatarId,
      'province': province,
      'city': city,
      'area': area,
      'address': address,
    };
  }

  OfficialUserProfile copyWith({
    String? id,
    String? nickName,
    String? name,
    String? signature,
    String? avatarName,
    String? avatarPath,
    String? gender,
    String? birthday,
    String? obsAvatarId,
    String? province,
    String? city,
    String? area,
    String? address,
    Map<String, dynamic>? raw,
  }) {
    return OfficialUserProfile(
      id: id ?? this.id,
      nickName: nickName ?? this.nickName,
      name: name ?? this.name,
      signature: signature ?? this.signature,
      avatarName: avatarName ?? this.avatarName,
      avatarPath: avatarPath ?? this.avatarPath,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      obsAvatarId: obsAvatarId ?? this.obsAvatarId,
      province: province ?? this.province,
      city: city ?? this.city,
      area: area ?? this.area,
      address: address ?? this.address,
      raw: raw ?? this.raw,
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
