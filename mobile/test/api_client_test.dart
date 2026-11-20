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
  test('fetches update metadata through authenticated RHM backend', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: token,
      httpClient: MockClient((request) async {
        expect(request.url.toString(), 'http://127.0.0.1:8000/mobile/updates/latest');
        expect(request.headers['authorization'], 'Bearer $token');
        return http.Response(
          jsonEncode({
            'tag_name': 'v0.1.5',
            'assets': [
              {'id': 501, 'name': 'app-release.apk', 'size': 2048},
              {'id': 502, 'name': 'app-release.apk.sha256', 'size': 84},
            ],
          }),
          200,
        );
      }),
    );

    final release = await client.fetchLatestUpdate();
    expect(release['tag_name'], 'v0.1.5');
    expect((release['assets'] as List).length, 2);
    client.close();
  });

  test('downloads update assets through authenticated RHM backend', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: token,
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'http://127.0.0.1:8000/mobile/updates/assets/501',
        );
        expect(request.headers['authorization'], 'Bearer $token');
        return http.Response.bytes([1, 2, 3, 4], 200);
      }),
    );

    final bytes = await client.downloadUpdateAsset(501);
    expect(bytes, [1, 2, 3, 4]);
    client.close();
  });

  test('rejects invalid update asset identifiers before making a request', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: token,
      httpClient: MockClient((_) async {
        fail('No request should be sent for an invalid asset identifier.');
      }),
    );

    await expectLater(
      client.downloadUpdateAsset(0),
      throwsA(isA<RhmApiException>()),
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

}
