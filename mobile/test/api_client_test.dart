import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rhm_mobile/api_client.dart';

const token = 'rhm_test_token_that_is_at_least_32_urlsafe_chars';

void main() {
  test('restricts the shared API token to loopback hosts', () {
    expect(
      () => RhmApiClient(serverUrl: 'http://rhm.example', token: token),
      throwsA(isA<RhmApiException>()),
    );
    expect(
      () => RhmApiClient(serverUrl: 'http://[::1]:8000', token: token),
      throwsA(isA<RhmApiException>()),
    );
    expect(
      () => RhmApiClient(serverUrl: 'http://192.168.1.5:8000', token: token),
      throwsA(isA<RhmApiException>()),
    );
    expect(
      () => RhmApiClient(serverUrl: 'https://rhm.example', token: token),
      throwsA(isA<RhmApiException>()),
    );
    expect(
      () => RhmApiClient(serverUrl: 'http://user@127.0.0.1:8000', token: token),
      throwsA(isA<RhmApiException>()),
    );
    expect(
      () => RhmApiClient(serverUrl: 'https://user@rhm.example', token: token),
      throwsA(isA<RhmApiException>()),
    );
    expect(
      () => RhmApiClient(serverUrl: 'http://127.0.0.1:8000', token: 'short'),
      throwsA(isA<RhmApiException>()),
    );
  });

  test('parses audit events when entity_type is null', () {
    final event = RhmAuditEvent.fromJson({
      'id': 'event-1',
      'event_type': 'system',
      'actor': 'rhm',
      'action': 'health.checked',
      'entity_type': null,
    });

    expect(event.entityType, isNull);
  });

  test('preserves audit entity_type when it is present', () {
    final event = RhmAuditEvent.fromJson({
      'id': 'event-2',
      'event_type': 'conversation',
      'actor': 'user',
      'action': 'conversation.message_sent',
      'entity_type': 'conversation',
    });

    expect(event.entityType, 'conversation');
  });

  test('uses the same-phone localhost URL as its default', () {
    expect(RhmApiClient.defaultServerUrl, 'http://127.0.0.1:8000');
    final client = RhmApiClient(
      serverUrl: RhmApiClient.defaultServerUrl,
      token: token,
    );
    client.close();
  });

  test('sends bearer token to RHM chat route', () async {
    var received = false;
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000/',
      token: token,
      httpClient: MockClient((request) async {
        received = true;
        expect(request.url.toString(), 'http://127.0.0.1:8000/mobile/chat');
        expect(request.headers['authorization'], 'Bearer $token');
        expect(request.followRedirects, isFalse);
        expect(request.maxRedirects, 0);
        expect(request.headers['content-type'], 'application/json');
        expect(jsonDecode(request.body), {
          'prompt': 'مرحبًا',
          'preferred_provider': null,
          'preferred_model': null,
        });
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'provider': 'gemini',
              'model': 'gemini-3.6-flash',
              'content': 'أهلًا',
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final reply = await client.sendChat('مرحبًا');
    expect(received, isTrue);
    expect(reply.content, 'أهلًا');
    expect(reply.provider, 'gemini');
    client.close();
  });

  test('checks authenticated mobile health endpoint', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000/rhm/',
      token: token,
      httpClient: MockClient((request) async {
        expect(request.url.toString(), 'http://127.0.0.1:8000/rhm/mobile/health');
        expect(request.headers['authorization'], 'Bearer $token');
        return http.Response('{"status":"ok"}', 200);
      }),
    );

    await client.checkConnection();
    client.close();
  });

  test('reports an authentication failure from the health endpoint safely', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: token,
      httpClient: MockClient((_) async => http.Response('private server body', 401)),
    );

    await expectLater(
      client.checkConnection(),
      throwsA(
        isA<RhmApiException>()
            .having((error) => error.message, 'message', contains('HTTP 401'))
            .having((error) => error.message, 'message', isNot(contains('private'))),
      ),
    );
    client.close();
  });

  test('rejects a malformed health response instead of marking the server ready', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: token,
      httpClient: MockClient((_) async => http.Response('not-json', 200)),
    );

    await expectLater(
      client.checkConnection(),
      throwsA(
        isA<RhmApiException>().having(
          (error) => error.message,
          'message',
          contains('invalid response'),
        ),
      ),
    );
    client.close();
  });

  test('does not include response bodies in server errors', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: token,
      httpClient: MockClient((_) async => http.Response('secret response body', 401)),
    );

    await expectLater(
      client.sendChat('hello'),
      throwsA(
        isA<RhmApiException>()
            .having((error) => error.message, 'message', contains('HTTP 401'))
            .having((error) => error.message, 'message', isNot(contains('secret'))),
      ),
    );
    client.close();
  });
  test('fetches backend and frontend runtime from the shared update API', () async {
    final sha = List.filled(40, 'a').join();
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: token,
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'http://127.0.0.1:8000/server-update/status');
        expect(request.headers['authorization'], 'Bearer $token');
        return http.Response(
          jsonEncode({
            'preferences': {'auto_update': true, 'interval_seconds': 300},
            'supervisor_running': true,
            'runtime': {'state': 'up_to_date', 'current_sha': sha},
            'frontend': {
              'state': 'running',
              'port': 3000,
              'current_sha': sha,
              'message': 'The Next.js production frontend is running and healthy.',
            },
          }),
          200,
        );
      }),
    );

    final snapshot = await client.getServerUpdateStatus();
    expect(snapshot.supervisorRunning, isTrue);
    expect(snapshot.frontend?['state'], 'running');
    expect(snapshot.frontend?['port'], 3000);
    expect(snapshot.frontend?['current_sha'], sha);
    client.close();
  });

  test('accepts older server status responses without frontend runtime data', () {
    final snapshot = RhmServerUpdateSnapshot.fromJson({
      'preferences': {'auto_update': false, 'interval_seconds': 300},
      'supervisor_running': false,
      'runtime': {'state': 'up_to_date'},
    });

    expect(snapshot.frontend, isNull);
  });

  test('refreshes an expired device access token once and persists rotation', () async {
    const expiredAccess = 'rhm_expired_access_token_that_is_long_enough_123456';
    const currentRefresh = 'rhm_current_refresh_token_that_is_long_enough_123456';
    const nextAccess = 'rhm_next_access_token_that_is_long_enough_123456789';
    const nextRefresh = 'rhm_next_refresh_token_that_is_long_enough_123456789';
    var healthCalls = 0;
    var savedAccess = '';
    var savedRefresh = '';
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: expiredAccess,
      refreshToken: currentRefresh,
      onCredentialsRotated: (access, refresh) async {
        savedAccess = access;
        savedRefresh = refresh;
      },
      httpClient: MockClient((request) async {
        if (request.url.path == '/mobile/auth/refresh') {
          expect(request.headers.containsKey('authorization'), isFalse);
          expect(jsonDecode(request.body), {'refresh_token': currentRefresh});
          return http.Response(
            jsonEncode({
              'access_token': nextAccess,
              'refresh_token': nextRefresh,
            }),
            200,
          );
        }
        healthCalls++;
        if (healthCalls == 1) {
          expect(request.headers['authorization'], 'Bearer $expiredAccess');
          return http.Response('{"detail":"expired"}', 401);
        }
        expect(request.headers['authorization'], 'Bearer $nextAccess');
        return http.Response('{"status":"ok"}', 200);
      }),
    );

    await client.checkConnection();
    expect(healthCalls, 2);
    expect(savedAccess, nextAccess);
    expect(savedRefresh, nextRefresh);
    expect(client.accessToken, nextAccess);
    client.close();
  });

  test('clears persisted credentials when refresh is rejected', () async {
    const access = 'rhm_expired_access_token_that_is_long_enough_123456';
    const refresh = 'rhm_expired_refresh_token_that_is_long_enough_123456';
    var invalidated = false;
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: access,
      refreshToken: refresh,
      onCredentialsInvalidated: () async {
        invalidated = true;
      },
      httpClient: MockClient((request) async {
        if (request.url.path == '/mobile/auth/refresh') {
          return http.Response('{"detail":"revoked"}', 401);
        }
        return http.Response('{"detail":"expired"}', 401);
      }),
    );

    await expectLater(client.checkConnection(), throwsA(isA<RhmApiException>()));
    expect(invalidated, isTrue);
    expect(client.accessToken, isNull);
    client.close();
  });

  test('creates a pairing request without sending a bearer token', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/mobile/pairing/requests');
        expect(request.headers.containsKey('authorization'), isFalse);
        expect(jsonDecode(request.body), {
          'name': 'RHM Android phone',
          'public_key': 'A' * 43,
        });
        return http.Response(
          jsonEncode({
            'request_id': '11111111-1111-4111-8111-111111111111',
            'pairing_code': 'pair_code_123',
            'pairing_secret': 'pairing_secret_that_is_long_enough_123456',
            'challenge': 'challenge_value',
            'expires_at': '2026-11-22T00:00:00+00:00',
          }),
          201,
        );
      }),
    );

    final request = await client.createDevicePairingRequest(
      name: 'RHM Android phone',
      publicKey: 'A' * 43,
    );
    expect(request['pairing_code'], 'pair_code_123');
    client.close();
  });

  test('returns pending state while owner approval is outstanding', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/complete'));
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response('{"detail":"Waiting for owner approval"}', 202);
      }),
    );

    final result = await client.completeDevicePairingRequest(
      requestId: '11111111-1111-4111-8111-111111111111',
      pairingSecret: 'pairing_secret_that_is_long_enough_123456',
      signature: 'A' * 86,
    );
    expect(result, isNull);
    client.close();
  });

  test('creates a separate authenticated session for background polling', () async {
    const primary = 'rhm_primary_access_token_that_is_long_enough_123456';
    const backgroundAccess = 'rhm_background_access_token_that_is_long_enough_123456';
    const backgroundRefresh = 'rhm_background_refresh_token_that_is_long_enough_123456';
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: primary,
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/mobile/auth/background-session');
        expect(request.headers['authorization'], 'Bearer $primary');
        expect(jsonDecode(request.body), isEmpty);
        return http.Response(
          jsonEncode({
            'purpose': 'background',
            'access_token': backgroundAccess,
            'refresh_token': backgroundRefresh,
          }),
          200,
        );
      }),
    );

    final session = await client.createBackgroundDeviceSession();
    expect(session['purpose'], 'background');
    expect(session['access_token'], backgroundAccess);
    expect(session['refresh_token'], backgroundRefresh);
    client.close();
  });

}
