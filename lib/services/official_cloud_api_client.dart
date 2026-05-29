part of 'official_cloud_service.dart';

class OfficialCloudApiException implements Exception {
  final String message;
  final int? statusCode;

  const OfficialCloudApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class _OfficialApiResponse {
  final int statusCode;
  final Map<String, String> headers;
  final Map<String, dynamic> body;

  const _OfficialApiResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });
}

class OfficialCloudApiConfig {
  final String apiBase;
  final String loginMacCode;
  final String phoneMode;
  final String forwardServiceIp;
  final String language;
  final String zoneId;
  final String apiVersion;
  final String userAgent;
  final Duration connectTimeout;
  final Duration responseTimeout;

  const OfficialCloudApiConfig({
    this.apiBase = 'https://www.tailgdd.com/v1/api/',
    this.loginMacCode = '000000000000',
    this.phoneMode = 'SM-G998B',
    this.forwardServiceIp = 'localhost',
    this.language = 'zh_CN',
    this.zoneId = 'UTC+08:00',
    this.apiVersion = '3.0.0',
    this.userAgent = 'okhttp/4.9.3',
    this.connectTimeout = const Duration(seconds: 15),
    this.responseTimeout = const Duration(seconds: 15),
  });

  Uri resolve(String path) => Uri.parse(apiBase).resolve(path);

  Map<String, String> get defaultHeaders => {
    HttpHeaders.contentTypeHeader: 'application/json',
    'Forward-Service-Ip': forwardServiceIp,
    'Forward-ServiceIp': forwardServiceIp,
    'language': language,
    HttpHeaders.acceptLanguageHeader: language,
    'Zone-id': zoneId,
    'Api-Version': apiVersion,
    HttpHeaders.userAgentHeader: userAgent,
  };
}

class _OfficialCloudApiClient {
  final OfficialCloudApiConfig config;
  final LogService _log;
  OfficialCloudRequestSummary? _lastRequest;

  _OfficialCloudApiClient({required this.config, required LogService log})
    : _log = log;

  OfficialCloudRequestSummary? get lastRequest => _lastRequest;

  Future<_OfficialApiResponse> request(
    String path, {
    required String method,
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = config.connectTimeout;
    final startedAt = DateTime.now();
    try {
      final uri = config.resolve(path);
      final request = await client.openUrl(method, uri);
      for (final entry in config.defaultHeaders.entries) {
        request.headers.set(entry.key, entry.value);
      }
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, token);
      }
      if (body != null) {
        request.add(utf8.encode(jsonEncode(body)));
      }

      final response = await request.close().timeout(
        config.responseTimeout,
        onTimeout: () => throw const OfficialCloudApiException('请求超时，请检查网络'),
      );
      final text = await response.transform(utf8.decoder).join();
      final decoded = _decodeBody(text);
      _recordRequest(
        path: path,
        method: method,
        startedAt: startedAt,
        statusCode: response.statusCode,
        body: decoded,
      );
      final headers = <String, String>{};
      response.headers.forEach((name, values) {
        if (values.isNotEmpty) headers[name.toLowerCase()] = values.first;
      });
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OfficialCloudApiException(
          decoded['msg']?.toString() ?? '官方接口返回 ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      return _OfficialApiResponse(
        statusCode: response.statusCode,
        headers: headers,
        body: decoded,
      );
    } on TimeoutException {
      _recordRequestFailure(
        path: path,
        method: method,
        startedAt: startedAt,
        message: '请求超时，请检查网络',
      );
      throw const OfficialCloudApiException('请求超时，请检查网络');
    } on SocketException {
      _recordRequestFailure(
        path: path,
        method: method,
        startedAt: startedAt,
        message: '网络不可用，请检查连接',
      );
      throw const OfficialCloudApiException('网络不可用，请检查连接');
    } on OfficialCloudApiException catch (e) {
      _recordRequestFailure(
        path: path,
        method: method,
        startedAt: startedAt,
        message: e.message,
        statusCode: e.statusCode,
      );
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  void _recordRequest({
    required String path,
    required String method,
    required DateTime startedAt,
    required int statusCode,
    required Map<String, dynamic> body,
  }) {
    final elapsed = DateTime.now().difference(startedAt);
    final code = body['code']?.toString();
    final msg = _shortMessage(body['msg']?.toString());
    _lastRequest = OfficialCloudRequestSummary(
      path: path,
      method: method,
      statusCode: statusCode,
      code: code,
      message: msg,
      elapsed: elapsed,
      success: statusCode >= 200 && statusCode < 300,
      at: DateTime.now(),
    );
    _log.operation(
      '官方云接口返回',
      detail:
          '$method $path status=$statusCode code=${code ?? 'none'} elapsed=${elapsed.inMilliseconds}ms msg=${msg ?? 'none'}',
      level: LogLevel.debug,
    );
  }

  void _recordRequestFailure({
    required String path,
    required String method,
    required DateTime startedAt,
    required String message,
    int? statusCode,
  }) {
    final elapsed = DateTime.now().difference(startedAt);
    _lastRequest = OfficialCloudRequestSummary(
      path: path,
      method: method,
      statusCode: statusCode,
      code: null,
      message: _shortMessage(message),
      elapsed: elapsed,
      success: false,
      at: DateTime.now(),
    );
    _log.operation(
      '官方云接口失败',
      detail:
          '$method $path status=${statusCode?.toString() ?? 'none'} elapsed=${elapsed.inMilliseconds}ms msg=${_shortMessage(message)}',
      level: LogLevel.warning,
    );
  }

  String? _shortMessage(String? message) {
    if (message == null || message.trim().isEmpty) return null;
    final normalized = message.trim();
    if (normalized.length <= 80) return normalized;
    return normalized.substring(0, 80);
  }

  Map<String, dynamic> _decodeBody(String text) {
    if (text.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      final end = text.length < 80 ? text.length : 80;
      throw OfficialCloudApiException(
        '服务器返回非 JSON 数据: ${text.substring(0, end)}',
      );
    }
    throw const OfficialCloudApiException('服务器返回数据格式不正确');
  }
}

class OfficialCloudRequestSummary {
  final String path;
  final String method;
  final int? statusCode;
  final String? code;
  final String? message;
  final Duration elapsed;
  final bool success;
  final DateTime at;

  const OfficialCloudRequestSummary({
    required this.path,
    required this.method,
    required this.statusCode,
    required this.code,
    required this.message,
    required this.elapsed,
    required this.success,
    required this.at,
  });
}
