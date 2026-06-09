part of 'official_cloud_service.dart';

class OfficialCloudAuthParser {
  const OfficialCloudAuthParser._();

  static bool looksLikeAuthError(String message) {
    final normalized = message.trim().toLowerCase();
    return normalized.contains('token') ||
        normalized.contains('unauthorized') ||
        normalized.contains('forbidden') ||
        normalized.contains('expired') ||
        normalized.contains('登录') ||
        normalized.contains('认证') ||
        normalized.contains('授权') ||
        normalized.contains('401') ||
        normalized.contains('403') ||
        normalized.contains('过期') ||
        normalized.contains('失效');
  }

  static String extractUserId(Map<String, dynamic> body) {
    return _findUserId(body)?.toString().trim() ?? '';
  }

  static Object? _findUserId(Object? value) {
    if (value is Map) {
      for (final key in const ['uid', 'userId', 'id']) {
        final candidate = value[key];
        if (candidate != null && candidate.toString().trim().isNotEmpty) {
          return candidate;
        }
      }
      for (final child in value.values) {
        final found = _findUserId(child);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _findUserId(child);
        if (found != null) return found;
      }
    }
    return null;
  }
}
