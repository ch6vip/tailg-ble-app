part of 'official_cloud_service.dart';

class OfficialCloudApiException implements Exception {
  final String message;
  final int? statusCode;

  const OfficialCloudApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class OfficialCloudRedactor {
  static final RegExp _sensitiveQueryPattern = RegExp(
    r'(?<=\b(?:phone|token|authorization|imei|carId|uid|frame|btmac)=)[^&\s]+',
    caseSensitive: false,
  );
  static final RegExp _phonePattern = RegExp(r'\b1\d{10}\b');
  static final RegExp _imeiPattern = RegExp(r'\b\d{14,17}\b');
  static final RegExp _macPattern = RegExp(
    r'\b(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b',
  );
  static final RegExp _compactMacPattern = RegExp(r'\b[0-9A-Fa-f]{12}\b');

  const OfficialCloudRedactor._();

  static String requestPath(String path) {
    return path.replaceAllMapped(_sensitiveQueryPattern, (match) {
      return _mask(match.group(0) ?? '');
    });
  }

  static String text(String value) {
    return value
        .replaceAllMapped(_phonePattern, (match) => _mask(match.group(0)!))
        .replaceAllMapped(_imeiPattern, (match) => _mask(match.group(0)!))
        .replaceAllMapped(_macPattern, (match) => _mask(match.group(0)!))
        .replaceAllMapped(
          _compactMacPattern,
          (match) => _mask(match.group(0)!),
        );
  }

  static String _mask(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '***';
    if (trimmed.length <= 6) return '***';
    return '${trimmed.substring(0, 3)}***${trimmed.substring(trimmed.length - 3)}';
  }
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
  final Duration retryBaseDelay;

  const OfficialCloudApiConfig({
    this.apiBase = 'https://www.tailgdd.com/v1/api/',
    this.loginMacCode = '000000000000',
    this.phoneMode = 'SM-G998B',
    // Empty by default: callers that genuinely need IP forwarding must set it
    // explicitly. The previous 'localhost' default leaked into production
    // requests and could confuse upstream routing/gateway logic.
    this.forwardServiceIp = '',
    this.language = 'zh_CN',
    this.zoneId = 'UTC+08:00',
    this.apiVersion = '3.0.0',
    this.userAgent = 'okhttp/4.9.3',
    this.connectTimeout = const Duration(seconds: 15),
    this.responseTimeout = const Duration(seconds: 15),
    this.retryBaseDelay = const Duration(milliseconds: 500),
  });

  Uri resolve(String path) => Uri.parse(apiBase).resolve(path);

  Duration retryDelayForAttempt(int attempt) {
    final normalizedAttempt = attempt < 0 ? 0 : attempt;
    return retryBaseDelay * (normalizedAttempt + 1);
  }

  Map<String, String> get defaultHeaders => {
    HttpHeaders.contentTypeHeader: 'application/json',
    // Only emit Forward-Service-Ip when actually configured. The duplicate
    // 'Forward-ServiceIp' (missing hyphen) was a typo that has been removed.
    if (forwardServiceIp.isNotEmpty) 'Forward-Service-Ip': forwardServiceIp,
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

  // 复用单个 HttpClient 以启用 keep-alive / 连接池，避免每次请求
  // 重做 TCP+TLS 握手。服务为单例、生命周期与 App 一致。
  HttpClient? _client;

  _OfficialCloudApiClient({required this.config, required LogService log})
    : _log = log;

  OfficialCloudRequestSummary? get lastRequest => _lastRequest;

  HttpClient get _sharedClient {
    final existing = _client;
    if (existing != null) return existing;
    final created = HttpClient()..connectionTimeout = config.connectTimeout;
    _client = created;
    return created;
  }

  void dispose() {
    _client?.close(force: true);
    _client = null;
  }

  Future<_OfficialApiResponse> request(
    String path, {
    required String method,
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final client = _sharedClient;
    const maxRetries = 2;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
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
        final decoded = await _decodeBody(text);
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
        if (attempt < maxRetries) {
          await Future<void>.delayed(config.retryDelayForAttempt(attempt));
          continue;
        }
        _recordRequestFailure(
          path: path,
          method: method,
          startedAt: startedAt,
          message: '请求超时，请检查网络',
        );
        throw const OfficialCloudApiException('请求超时，请检查网络');
      } on SocketException {
        if (attempt < maxRetries) {
          await Future<void>.delayed(config.retryDelayForAttempt(attempt));
          continue;
        }
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
      }
    }
    // Unreachable — the loop always returns or throws.
    throw StateError('Unreachable');
  }

  void _recordRequest({
    required String path,
    required String method,
    required DateTime startedAt,
    required int statusCode,
    required Map<String, dynamic> body,
  }) {
    final elapsed = DateTime.now().difference(startedAt);
    final safePath = OfficialCloudRedactor.requestPath(path);
    final code = body['code']?.toString();
    final msg = _shortMessage(body['msg']?.toString());
    _lastRequest = OfficialCloudRequestSummary(
      path: safePath,
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
          '$method $safePath status=$statusCode code=${code ?? 'none'} elapsed=${elapsed.inMilliseconds}ms msg=${msg ?? 'none'}',
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
    final safePath = OfficialCloudRedactor.requestPath(path);
    _lastRequest = OfficialCloudRequestSummary(
      path: safePath,
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
          '$method $safePath status=${statusCode?.toString() ?? 'none'} elapsed=${elapsed.inMilliseconds}ms msg=${_shortMessage(message)}',
      level: LogLevel.warning,
    );
  }

  String? _shortMessage(String? message) {
    if (message == null || message.trim().isEmpty) return null;
    final normalized = message.trim();
    if (normalized.length <= 80) return normalized;
    return normalized.substring(0, 80);
  }

  // 超过该阈值的响应体丢到后台 isolate 解析，避免大 JSON 阻塞 UI 线程；
  // 小负载继续在主 isolate 解析（省去 spawn isolate 的开销）。
  static const int _isolateDecodeThreshold = 32 * 1024;

  Future<Map<String, dynamic>> _decodeBody(String text) async {
    if (text.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = text.length > _isolateDecodeThreshold
          ? await compute<String, Object?>(jsonDecode, text)
          : jsonDecode(text);
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
