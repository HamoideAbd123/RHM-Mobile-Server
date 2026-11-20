import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rhm_mobile/api_client.dart';

const token = 'rhm_test_token_that_is_at_least_32_urlsafe_chars';

void main() {
  test('lists configured MCP servers without returning credential values', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: token,
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'http://127.0.0.1:8000/mcp-client/servers');
        expect(request.headers['authorization'], 'Bearer $token');
        return http.Response(
          jsonEncode({
            'servers': [
              {
                'server_id': 'docs',
                'endpoint': 'https://mcp.example.com/docs',
                'enabled': true,
                'approved': true,
                'allowed_tools': ['search_docs'],
                'credential_configured': true,
              },
            ],
          }),
          200,
        );
      }),
    );

    final servers = await client.listMcpServers();
    expect(servers, hasLength(1));
    expect(servers.single.id, 'docs');
    expect(servers.single.readyForDiscovery, isTrue);
    expect(servers.single.allowedTools, ['search_docs']);
    client.close();
  });

  test('discovers only the configured server tools through authenticated API', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: token,
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'http://127.0.0.1:8000/mcp-client/servers/docs/tools',
        );
        expect(request.headers['authorization'], 'Bearer $token');
        return http.Response(
          jsonEncode({
            'server_id': 'docs',
            'tools': [
              {
                'name': 'search_docs',
                'description': 'Search approved documentation.',
                'input_schema': {
                  'type': 'object',
                  'properties': {'query': {'type': 'string'}},
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final tools = await client.discoverMcpTools('docs');
    expect(tools, hasLength(1));
    expect(tools.single.name, 'search_docs');
    expect(tools.single.inputSchema['type'], 'object');
    client.close();
  });

  test('rejects invalid MCP server identifiers before making a request', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: token,
      httpClient: MockClient((_) async {
        fail('No request should be sent for an invalid MCP server identifier.');
      }),
    );

    await expectLater(
      client.discoverMcpTools('../secrets'),
      throwsA(isA<RhmApiException>()),
    );
    client.close();
  });

  test('does not expose backend response bodies on MCP errors', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: token,
      httpClient: MockClient((_) async => http.Response('secret-token-value', 503)),
    );

    await expectLater(
      client.listMcpServers(),
      throwsA(
        isA<RhmApiException>()
            .having((error) => error.message, 'message', contains('HTTP 503'))
            .having((error) => error.message, 'message', isNot(contains('secret-token-value'))),
      ),
    );
    client.close();
  });
}
