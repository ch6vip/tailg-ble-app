part of 'official_cloud_service.dart';

class OfficialCloudAuthParser {
  const OfficialCloudAuthParser._();

  static final RegExp _http401Pattern = RegExp(r'\b401\b');
  static final RegExp _http403Pattern = RegExp(r'\b403\b');

  static bool looksLikeAuthError(Object error) {
    // Check HTTP status code first
    if (error is OfficialCloudApiException) {
      if (error.statusCode == 401 || error.statusCode == 403) return true;
    }
    final message = error.toString().trim().toLowerCase();
    if (message.contains('unauthorized') ||
        message.contains('token expired') ||
        message.contains('token invalid') ||
        message.contains('认证失败') ||
        message.contains('登录已过期') ||
        message.contains('授权已失效') ||
        _http401Pattern.hasMatch(message) ||
        _http403Pattern.hasMatch(message)) {
      return true;
    }
    // Compound: 'token' paired with expiry keyword catches 'token 已过期' etc.
    if (message.contains('token') &&
        (message.contains('过期') || message.contains('失效'))) {
      return true;
    }
    return false;
  }

  static String extractUserId(Map<String, dynamic> body) {
    return _findUserId(body) ?? '';
  }

  static String? _findUserId(Object? value) {
    if (value is Map) {
      // Only match unambiguous user-id keys. The previous 'id' fallback was
      // too greedy and would match `carId`, `deviceTravelId`, `extendId`,
      // etc. — returning the wrong user id and breaking downstream queries
      // (or, worse, leaking another user's data).
      for (final key in const ['uid', 'userId']) {
        final candidate = value[key];
        final text = candidate?.toString().trim();
        if (text != null && text.isNotEmpty) {
          return text;
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
