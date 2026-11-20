import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rhm_mobile/api_client.dart';

void main() {
  final token = 'test_${List.filled(40, 'x').join()}';

  test('lists configured MCP servers', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/mcp-client/servers');
      expect(request.headers['authorization'], 'Bearer $token');
      return http.Response(jsonEncode({
        'servers': [{
          'server_id': 'docs',
          'endpoint': 'https://mcp.example.com/rpc',
          'enabled': true,
          'approved': true,
          'allowed_tools': ['search_docs'],
          'credential_configured': true,
        }],
      }), 200);
    });
    final api = RhmApiClient(
      serverUrl: RhmApiClient.defaultServerUrl,
      token: token,
      httpClient: client,
    );
    addTearDown(api.close);

    final servers = await api.listMcpServers();
    expect(servers, hasLength(1));
    expect(servers.single.id, 'docs');
    expect(servers.single.approved, isTrue);
    expect(servers.single.allowedTools, ['search_docs']);
  });

  test('discovers allowlisted MCP tools', () async {
    final client = MockClient((request) async => http.Response(jsonEncode({
      'server_id': 'docs',
      'tools': [{
        'name': 'search_docs',
        'description': 'Search documentation',
        'input_schema': {'type': 'object', 'required': ['query']},
      }],
    }), 200));
    final api = RhmApiClient(
      serverUrl: RhmApiClient.defaultServerUrl,
      token: token,
      httpClient: client,
    );
    addTearDown(api.close);

    final tools = await api.discoverMcpTools('docs');
    expect(tools.single.name, 'search_docs');
    expect(tools.single.inputSchema['required'], ['query']);
  });

  test('posts reviewed MCP arguments and returns tool result', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/mcp-client/servers/docs/tools/search_docs');
      expect(jsonDecode(request.body), {
        'arguments': {'query': 'RHM documentation'},
      });
      return http.Response(jsonEncode({
        'tool': 'search_docs',
        'risk': 'low',
        'result': {'matches': 2},
      }), 200);
    });
    final api = RhmApiClient(
      serverUrl: RhmApiClient.defaultServerUrl,
      token: token,
      httpClient: client,
    );
    addTearDown(api.close);

    final result = await api.invokeMcpTool(
      'docs',
      'search_docs',
      {'query': 'RHM documentation'},
    );
    expect(result['risk'], 'low');
    expect((result['result'] as Map<String, dynamic>)['matches'], 2);
  });

  test('rejects malformed MCP data', () {
    expect(
      () => RhmMcpServer.fromJson({'server_id': 'docs'}),
      throwsA(isA<RhmApiException>()),
    );
    expect(
      () => RhmMcpTool.fromJson({'name': 7, 'input_schema': []}),
      throwsA(isA<RhmApiException>()),
    );
  });
}
