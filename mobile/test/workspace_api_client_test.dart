import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rhm_mobile/api_client.dart';

const testToken = 'rhm_workspace_test_token_with_more_than_32_chars';

void main() {
  test('lists persistent conversations with authenticated requests', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: testToken,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/conversations');
        expect(request.url.queryParameters['limit'], '50');
        expect(request.headers['authorization'], 'Bearer $testToken');
        return http.Response(
          jsonEncode([
            {
              'id': 'conversation-1',
              'title': 'RHM mobile',
              'project_name': null,
              'created_at': '2026-11-07T00:00:00Z',
              'updated_at': '2026-11-07T00:01:00Z',
            },
          ]),
          200,
        );
      }),
    );

    final items = await client.listConversations();
    expect(items, hasLength(1));
    expect(items.single.id, 'conversation-1');
    expect(items.single.title, 'RHM mobile');
    client.close();
  });

  test('creates a persistent conversation', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: testToken,
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/conversations');
        expect(request.headers['authorization'], 'Bearer $testToken');
        expect(jsonDecode(request.body), {'title': 'New thread'});
        return http.Response(
          jsonEncode({
            'id': 'conversation-2',
            'title': 'New thread',
            'project_name': null,
            'created_at': '2026-11-07T00:00:00Z',
            'updated_at': '2026-11-07T00:00:00Z',
          }),
          201,
        );
      }),
    );

    final conversation = await client.createConversation(title: 'New thread');
    expect(conversation.id, 'conversation-2');
    client.close();
  });

  test('loads message history and pagination cursor', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: testToken,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/conversations/conversation-1/messages');
        expect(request.url.queryParameters['before'], 'message-cursor');
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'message-1',
                'conversation_id': 'conversation-1',
                'role': 'assistant',
                'content': 'Saved reply',
                'provider': 'gemini',
                'model': 'gemini-3.6-flash',
                'created_at': '2026-11-07T00:01:00Z',
              },
            ],
            'has_more': true,
            'next_before': 'message-1',
          }),
          200,
        );
      }),
    );

    final page = await client.listConversationMessages(
      'conversation-1',
      before: 'message-cursor',
    );
    expect(page.items.single.content, 'Saved reply');
    expect(page.hasMore, isTrue);
    expect(page.nextBefore, 'message-1');
    client.close();
  });

  test('sends an idempotent persistent conversation turn', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: testToken,
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/conversations/conversation-1/messages');
        expect(request.headers['authorization'], 'Bearer $testToken');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['prompt'], 'Hello RHM');
        expect(body['request_id'], '8e03978e-40d5-43e8-bc93-6894a57f9324');
        expect(body['preferred_provider'], 'gemini');
        return http.Response(
          jsonEncode({
            'conversation_id': 'conversation-1',
            'provider': 'gemini',
            'model': 'gemini-3.6-flash',
            'routing_reason': 'test',
            'replayed': false,
            'user_message': {
              'id': 'user-1',
              'conversation_id': 'conversation-1',
              'role': 'user',
              'content': 'Hello RHM',
              'provider': null,
              'model': null,
              'created_at': '2026-11-07T00:00:00Z',
            },
            'assistant_message': {
              'id': 'assistant-1',
              'conversation_id': 'conversation-1',
              'role': 'assistant',
              'content': 'Hello.',
              'provider': 'gemini',
              'model': 'gemini-3.6-flash',
              'created_at': '2026-11-07T00:00:01Z',
            },
          }),
          200,
        );
      }),
    );

    final turn = await client.sendConversationMessage(
      'conversation-1',
      'Hello RHM',
      requestId: '8e03978e-40d5-43e8-bc93-6894a57f9324',
      preferredProvider: 'gemini',
    );
    expect(turn.assistantMessage.content, 'Hello.');
    expect(turn.userMessage.role, 'user');
    expect(turn.replayed, isFalse);
    client.close();
  });

  test('supports project, task, memory and safe-agent API contracts', () async {
    final responses = <String, http.Response>{
      '/projects': http.Response(
        jsonEncode([
          {'id': 'project-1', 'name': 'RHM', 'description': null, 'status': 'active'},
        ]),
        200,
      ),
      '/tasks': http.Response(
        jsonEncode([
          {
            'id': 'task-1',
            'title': 'Review app',
            'description': null,
            'status': 'open',
            'priority': 'normal',
            'project_id': null,
          },
        ]),
        200,
      ),
      '/memories': http.Response(
        jsonEncode([
          {
            'id': 'memory-1',
            'content': 'RHM is a personal AI OS',
            'kind': 'semantic',
            'importance': 0.8,
            'confidence': 0.9,
          },
        ]),
        200,
      ),
      '/agent': http.Response(
        jsonEncode({
          'content': 'There is one open task.',
          'provider': 'gemini',
          'model': 'gemini-3.6-flash',
          'tool_calls': 1,
        }),
        200,
      ),
    };
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: testToken,
      httpClient: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer $testToken');
        return responses[request.url.path]!;
      }),
    );

    expect((await client.listProjects()).single.name, 'RHM');
    expect((await client.listTasks()).single.status, 'open');
    expect((await client.listMemories()).single.kind, 'semantic');
    expect((await client.runAgent('Review my tasks')).toolCalls, 1);
    client.close();
  });

  test('updates a task status through the validated PATCH route', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: testToken,
      httpClient: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/tasks/task-1');
        expect(jsonDecode(request.body), {'status': 'done'});
        return http.Response(
          jsonEncode({
            'id': 'task-1',
            'title': 'Review app',
            'description': null,
            'status': 'done',
            'priority': 'normal',
            'project_id': null,
          }),
          200,
        );
      }),
    );

    final task = await client.updateTask('task-1', status: 'done');
    expect(task.status, 'done');
    client.close();
  });

  test('supports project-scoped memory reads and creation', () async {
    var readChecked = false;
    var createChecked = false;
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: testToken,
      httpClient: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer $testToken');
        if (request.method == 'GET') {
          expect(request.url.path, '/memories');
          expect(request.url.queryParameters['project_name'], 'RHM');
          readChecked = true;
          return http.Response(
            jsonEncode([
              {
                'id': 'memory-project-1',
                'content': 'Project fact',
                'kind': 'fact',
                'importance': 0.8,
                'confidence': 0.9,
                'project_id': 'project-1',
              },
            ]),
            200,
          );
        }
        expect(request.method, 'POST');
        expect(request.url.path, '/memories');
        expect(jsonDecode(request.body), {
          'content': 'Keep the API stable',
          'kind': 'semantic',
          'importance': 0.5,
          'confidence': 0.7,
          'project_name': 'RHM',
        });
        createChecked = true;
        return http.Response(
          jsonEncode({
            'id': 'memory-project-2',
            'content': 'Keep the API stable',
            'kind': 'semantic',
            'importance': 0.5,
            'confidence': 0.7,
            'project_id': 'project-1',
          }),
          200,
        );
      }),
    );

    final listed = await client.listMemories(projectName: 'RHM');
    final created = await client.createMemory(
      'Keep the API stable',
      projectName: 'RHM',
    );
    expect(readChecked, isTrue);
    expect(createChecked, isTrue);
    expect(listed.single.projectId, 'project-1');
    expect(created.projectId, 'project-1');
    client.close();
  });

  test('loads project context, audit events, and registered devices', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: testToken,
      httpClient: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer $testToken');
        if (request.url.pathSegments.contains('context')) {
          expect(request.url.pathSegments, ['projects', 'RHM Mobile', 'context']);
          return http.Response(
            jsonEncode({
              'project': {'name': 'RHM Mobile'},
              'open_tasks': [],
              'memories': [],
            }),
            200,
          );
        }
        if (request.url.path == '/audit') {
          return http.Response(
            jsonEncode([
              {
                'id': 'event-1',
                'event_type': 'conversation',
                'actor': 'user',
                'action': 'conversation.created',
                'entity_type': 'conversation',
                'entity_id': 'conversation-1',
                'created_at': '2026-11-07T00:00:00Z',
              },
            ]),
            200,
          );
        }
        expect(request.url.path, '/devices');
        return http.Response(
          jsonEncode([
            {
              'id': 'device-1',
              'name': 'Huawei',
              'fingerprint': 'aabbcc',
              'status': 'active',
              'last_seen_at': '2026-11-07T00:00:00Z',
              'inventory': {'platform': 'android'},
              'inventory_updated_at': '2026-11-07T00:00:00Z',
            },
          ]),
          200,
        );
      }),
    );

    expect((await client.getProjectContext('RHM Mobile'))['project'], isA<Map>());
    expect((await client.listAuditEvents()).single.action, 'conversation.created');
    final devices = await client.listDevices();
    expect(devices.single.name, 'Huawei');
    expect(devices.single.inventory?['platform'], 'android');
    client.close();
  });

  test('deletes conversations and revokes devices only through explicit calls', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: testToken,
      httpClient: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer $testToken');
        if (request.url.path == '/conversations/conversation-1') {
          expect(request.method, 'DELETE');
          expect(jsonDecode(request.body), {'confirm': true});
          return http.Response('{"deleted":true,"id":"conversation-1"}', 200);
        }
        expect(request.method, 'POST');
        expect(request.url.path, '/devices/device-1/revoke');
        expect(jsonDecode(request.body), {'confirm': true});
        return http.Response('{"id":"device-1","status":"revoked"}', 200);
      }),
    );

    await client.deleteConversation('conversation-1');
    await client.revokeDevice('device-1');
    client.close();
  });

  test('edits a saved memory through the validated PATCH route', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: testToken,
      httpClient: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/memories/memory-1');
        expect(jsonDecode(request.body), {'content': 'Updated fact'});
        return http.Response(
          jsonEncode({
            'id': 'memory-1',
            'content': 'Updated fact',
            'kind': 'semantic',
            'importance': 0.5,
            'confidence': 0.7,
          }),
          200,
        );
      }),
    );

    expect((await client.updateMemory('memory-1', content: 'Updated fact')).content, 'Updated fact');
    client.close();
  });



  test('deletes a memory with explicit confirmation and JSON content type', () async {
    final client = RhmApiClient(
      serverUrl: 'http://127.0.0.1:8000',
      token: testToken,
      httpClient: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/memories/memory-1');
        expect(request.url.queryParameters['confirm'], 'true');
        expect(request.headers['content-type'], 'application/json');
        expect(jsonDecode(request.body), {'confirm': true});
        return http.Response('{"deleted":true,"id":"memory-1"}', 200);
      }),
    );

    await client.deleteMemory('memory-1');
    client.close();
  });


}
