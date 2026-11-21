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

class RhmApiClient {
  static const defaultServerUrl = 'http://127.0.0.1:8000';

  RhmApiClient({
    required String serverUrl,
    required String token,
    http.Client? httpClient,
  })  : _serverUri = _validateServerUrl(serverUrl),
        _token = _validateToken(token),
        _http = httpClient ?? http.Client();

  final Uri _serverUri;
  final String _token;
  final http.Client _http;

  static Uri _validateServerUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    final host = uri?.host.toLowerCase();
    final isLoopbackHost =
        host == '127.0.0.1' || host == 'localhost';
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        !isLoopbackHost ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const RhmApiException(
        'For safety, the shared RHM access token is restricted to this device. '
        'Remote server pairing with a dedicated device credential is not available yet.',
      );
    }
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return uri.replace(path: '$path/');
  }

  static String _validateToken(String value) {
    if (!RegExp(r'^[A-Za-z0-9_-]{32,}$').hasMatch(value)) {
      throw const RhmApiException('The RHM access token is invalid.');
    }
    return value;
  }

  Uri _endpoint(String path) => _serverUri.resolve(path);

  Future<http.Response> _send(
    http.Request request, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    // Never forward the shared local credential through an HTTP redirect.
    request.followRedirects = false;
    request.maxRedirects = 0;
    request.headers['authorization'] = 'Bearer $_token';
    request.headers.putIfAbsent('accept', () => 'application/json');
    try {
      final streamed = await _http.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const RhmApiException('RHM did not respond before the request timed out.');
    } on RhmApiException {
      rethrow;
    } on http.ClientException {
      throw const RhmApiException(
        'Could not reach the RHM server. Check that the backend is running on this phone at 127.0.0.1:8000.',
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
