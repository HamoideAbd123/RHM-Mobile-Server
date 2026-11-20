import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rhm_mobile/api_client.dart';
import 'package:rhm_mobile/mcp_screen.dart';

const token = 'rhm_test_token_that_is_at_least_32_urlsafe_chars';

void main() {
  testWidgets(
    'MCP screen lists configured servers and discovers allow-listed tools',
    (tester) async {
      final client = RhmApiClient(
        serverUrl: 'http://127.0.0.1:8000',
        token: token,
        httpClient: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer $token');

          if (request.url.path == '/mcp-client/servers') {
            expect(request.method, 'GET');
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
          }

          if (request.url.path == '/mcp-client/servers/docs/tools') {
            expect(request.method, 'GET');
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
          }

          return http.Response('not found', 404);
        }),
      );
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(home: RhmMcpScreen(api: client)),
      );
      await tester.pumpAndSettle();

      expect(find.text('تكاملات MCP'), findsOneWidget);
      expect(find.text('docs'), findsOneWidget);
      expect(find.text('mcp.example.com'), findsOneWidget);

      final discoverButton = find.text('اكتشاف الأدوات المسموح بها');
      await tester.ensureVisible(discoverButton);
      await tester.tap(discoverButton);
      await tester.pumpAndSettle();

      expect(find.text('search_docs'), findsOneWidget);
      expect(find.text('Search approved documentation.'), findsOneWidget);
    },
  );
}
