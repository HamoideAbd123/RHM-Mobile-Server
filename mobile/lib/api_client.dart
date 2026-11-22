import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_models.dart';

export 'api_models.dart';

part 'api_client/providers_chat.dart';
part 'api_client/server_updates.dart';
part 'api_client/notifications.dart';
part 'api_client/mcp.dart';
part 'api_client/conversations.dart';
part 'api_client/workspace.dart';
part 'api_client/device_pairing.dart';

class RhmApiClient {
  static const defaultServerUrl = 'http://127.0.0.1:8000';

  RhmApiClient({
    required String serverUrl,
    String? token,
    String? refreshToken,
    Future<void> Function(String accessToken, String refreshToken)?
        onCredentialsRotated,
    Future<void> Function()? onCredentialsInvalidated,
    http.Client? httpClient,
  })  : _serverUri = _validateServerUrl(serverUrl),
        _token = _validateToken(token),
        _refreshToken = _validateToken(refreshToken),
        // ignore: prefer_initializing_formals
        _onCredentialsRotated = onCredentialsRotated,
        // ignore: prefer_initializing_formals
        _onCredentialsInvalidated = onCredentialsInvalidated,
        _http = httpClient ?? http.Client();

  final Uri _serverUri;
  final http.Client _http;
  final Future<void> Function(String accessToken, String refreshToken)?
      _onCredentialsRotated;
  final Future<void> Function()? _onCredentialsInvalidated;
  String? _token;
  String? _refreshToken;
  Future<void>? _refreshInFlight;

  static Uri _validateServerUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    final host = uri?.host.toLowerCase();
    final isLoopbackHost = host == '127.0.0.1' || host == 'localhost';
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        !isLoopbackHost ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const RhmApiException(
        'لأسباب أمنية، يجب أن يكون عنوان RHM محليًا على هذا الهاتف.',
      );
    }
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return uri.replace(path: '$path/');
  }

  static String? _validateToken(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!RegExp(r'^[A-Za-z0-9_-]{32,}$').hasMatch(value)) {
      throw const RhmApiException('بيانات اعتماد RHM غير صالحة.');
    }
    return value;
  }

  String? get accessToken => _token;

  Uri _endpoint(String path) => _serverUri.resolve(path);

  Future<http.Response> _dispatch(
    http.Request request, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    request.followRedirects = false;
    request.maxRedirects = 0;
    request.headers.putIfAbsent('accept', () => 'application/json');
    try {
      final streamed = await _http.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const RhmApiException('لم يستجب خادم RHM قبل انتهاء المهلة.');
    } on RhmApiException {
      rethrow;
    } on http.ClientException {
      throw const RhmApiException(
        'تعذر الوصول إلى خادم RHM. تحقق من تشغيل Backend على 127.0.0.1:8000.',
      );
    }
  }

  Future<http.Response> _send(
    http.Request request, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final method = request.method;
    final uri = request.url;
    final headers = Map<String, String>.from(request.headers);
    final bodyBytes = request.bodyBytes;
    if (_token != null) {
      request.headers['authorization'] = 'Bearer $_token';
    } else {
      request.headers.remove('authorization');
    }
    final response = await _dispatch(request, timeout: timeout);
    if (response.statusCode != 401 || _refreshToken == null) {
      return response;
    }

    await _refreshCredentials();
    final retry = http.Request(method, uri)
      ..headers.addAll(headers)
      ..bodyBytes = bodyBytes;
    retry.headers['authorization'] = 'Bearer $_token';
    return _dispatch(retry, timeout: timeout);
  }

  Future<void> _refreshCredentials() {
    return _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<void> _performRefresh() async {
    final refresh = _refreshToken;
    if (refresh == null) {
      throw const RhmApiException('انتهت جلسة الجهاز؛ أعد ربط الهاتف بخادم RHM.');
    }
    final request = http.Request('POST', _endpoint('mobile/auth/refresh'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'refresh_token': refresh});
    final response = await _dispatch(
      request,
      timeout: const Duration(seconds: 20),
    );
    if (response.statusCode != 200) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        _token = null;
        _refreshToken = null;
        try {
          await _onCredentialsInvalidated?.call();
        } catch (_) {
          // Keep the API failure generic; never expose secure-storage details.
        }
        throw const RhmApiException(
          'تعذر تجديد اعتماد هذا الجهاز. أعد ربط الهاتف بخادم RHM.',
        );
      }
      throw RhmApiException(
        'تعذر تجديد الجلسة بسبب استجابة مؤقتة من الخادم (HTTP ${response.statusCode}).',
      );
    }
    final data = _decode(response);
    if (data is! Map<String, dynamic> ||
        data['access_token'] is! String ||
        data['refresh_token'] is! String) {
      throw const RhmApiException('استجابة تجديد اعتماد الجهاز غير صالحة.');
    }
    final access = _validateToken(data['access_token'] as String)!;
    final nextRefresh = _validateToken(data['refresh_token'] as String)!;
    _token = access;
    _refreshToken = nextRefresh;
    try {
      await _onCredentialsRotated?.call(access, nextRefresh);
    } catch (_) {
      throw const RhmApiException(
        'تم تجديد الاعتماد لكن تعذر حفظه في التخزين الآمن. افتح إعدادات الاتصال قبل إغلاق التطبيق.',
      );
    }
  }

  Object? _decode(http.Response response) {
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const RhmApiException('The RHM server returned an invalid response.');
    }
  }

  void close() => _http.close();
}
