import 'official_cloud_service.dart';

/// Human-facing remote control errors (MQTT ensure/publish + HTTP cmd).
///
/// P0-B3: token expiry / offline / broker failures must not be swallowed into
/// opaque strings that leave the user without a next step.
abstract final class OfficialRemoteErrorMessages {
  static const sessionExpired = '登录已失效，请重新登录官方账号';
  static const networkUnavailable = '手机网络异常，请检查网络后重试';
  static const brokerUnreachable = '远程控车服务连接失败，请稍后重试或检查网络';

  static String describe(Object error) {
    if (error is OfficialCloudApiException) {
      return _fromApiException(error);
    }
    final text = error.toString();
    return _fromText(text) ?? text;
  }

  static String _fromApiException(OfficialCloudApiException error) {
    final status = error.statusCode;
    if (status == 401 || status == 403) {
      return sessionExpired;
    }
    final mapped = _fromText(error.message);
    if (mapped != null) return mapped;
    final message = error.message.trim();
    return message.isEmpty ? brokerUnreachable : message;
  }

  static String? _fromText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();

    if (text.contains(OfficialCloudMessages.signInRequired) ||
        text.contains(OfficialCloudMessages.signInAndSelectVehicleRequired)) {
      return text;
    }
    if (lower.contains('token') ||
        lower.contains('unauthorized') ||
        lower.contains('401') ||
        text.contains('登录失效') ||
        text.contains('未登录') ||
        text.contains('请重新登录')) {
      return sessionExpired;
    }
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('timed out') ||
        lower.contains('timeout') ||
        text.contains('网络失败') ||
        text.contains('手机网络')) {
      return networkUnavailable;
    }
    if (text.contains('MQTT') &&
        (text.contains('连接失败') ||
            text.contains('未连接') ||
            lower.contains('broker'))) {
      return text.contains('网络') ? networkUnavailable : brokerUnreachable;
    }
    return null;
  }
}
