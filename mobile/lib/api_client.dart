import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class RhmApiException implements Exception {
  const RhmApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RhmChatReply {
  const RhmChatReply({
    required this.provider,
    required this.model,
    required this.content,
  });

  final String provider;
  final String model;
  final String content;

  factory RhmChatReply.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['provider'] is! String ||
        value['model'] is! String ||
        value['content'] is! String) {
      throw const RhmApiException('The RHM server returned an invalid response.');
    }
    return RhmChatReply(
      provider: value['provider'] as String,
      model: value['model'] as String,
      content: value['content'] as String,
    );
  }
}

class RhmProviderInfo {
  const RhmProviderInfo(this.provider, this.status, this.configured, this.models);
  final String provider, status;
  final bool configured;
  final List<String> models;
  factory RhmProviderInfo.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) throw const RhmApiException('Invalid provider information.');
    return RhmProviderInfo(value['provider'] as String? ?? '', value['status'] as String? ?? 'unknown', value['configured'] == true, (value['models'] as List<dynamic>? ?? const []).whereType<String>().toList());
  }
}

class RhmConversation {
  const RhmConversation({
    required this.id,
    required this.title,
    this.projectName,
    this.projectScopeInitialized = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? projectName;
  final bool projectScopeInitialized;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RhmConversation.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['title'] is! String) {
      throw const RhmApiException('Invalid conversation returned by RHM.');
    }
    return RhmConversation(
      id: value['id'] as String,
      title: value['title'] as String,
      projectName: value['project_name'] as String?,
      projectScopeInitialized: value['project_scope_initialized'] == true,
      createdAt: DateTime.tryParse(value['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(value['updated_at']?.toString() ?? ''),
    );
  }
}

class RhmConversationMessage {
  const RhmConversationMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.provider,
    this.model,
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String role;
  final String content;
  final String? provider;
  final String? model;
  final DateTime? createdAt;

  factory RhmConversationMessage.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['conversation_id'] is! String ||
        value['role'] is! String ||
        value['content'] is! String) {
      throw const RhmApiException('Invalid conversation message returned by RHM.');
    }
    return RhmConversationMessage(
      id: value['id'] as String,
      conversationId: value['conversation_id'] as String,
      role: value['role'] as String,
      content: value['content'] as String,
      provider: value['provider'] as String?,
      model: value['model'] as String?,
      createdAt: DateTime.tryParse(value['created_at']?.toString() ?? ''),
    );
  }
}

class RhmConversationPage {
  const RhmConversationPage({
    required this.items,
    required this.hasMore,
    this.nextBefore,
  });

  final List<RhmConversationMessage> items;
  final bool hasMore;
  final String? nextBefore;
}

class RhmConversationTurn {
  const RhmConversationTurn({
    required this.userMessage,
    required this.assistantMessage,
    required this.replayed,
  });

  final RhmConversationMessage userMessage;
  final RhmConversationMessage assistantMessage;
  final bool replayed;

  factory RhmConversationTurn.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const RhmApiException('Invalid conversation turn returned by RHM.');
    }
    return RhmConversationTurn(
      userMessage: RhmConversationMessage.fromJson(value['user_message']),
      assistantMessage: RhmConversationMessage.fromJson(value['assistant_message']),
      replayed: value['replayed'] == true,
    );
  }
}

class RhmProject {
  const RhmProject({
    required this.id,
    required this.name,
    this.description,
    this.status = 'active',
  });

  final String id;
  final String name;
  final String? description;
  final String status;

  factory RhmProject.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['name'] is! String) {
      throw const RhmApiException('Invalid project returned by RHM.');
    }
    return RhmProject(
      id: value['id'] as String,
      name: value['name'] as String,
      description: value['description'] as String?,
      status: value['status'] as String? ?? 'active',
    );
  }
}

class RhmDevice {
  const RhmDevice({
    required this.id,
    required this.name,
    required this.fingerprint,
    required this.status,
    this.lastSeenAt,
    this.inventory,
    this.inventoryUpdatedAt,
  });

  final String id;
  final String name;
  final String fingerprint;
  final String status;
  final DateTime? lastSeenAt;
  final Map<String, dynamic>? inventory;
  final DateTime? inventoryUpdatedAt;

  factory RhmDevice.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['name'] is! String ||
        value['fingerprint'] is! String ||
        value['status'] is! String) {
      throw const RhmApiException('Invalid device returned by RHM.');
    }
    return RhmDevice(
      id: value['id'] as String,
      name: value['name'] as String,
      fingerprint: value['fingerprint'] as String,
      status: value['status'] as String,
      lastSeenAt: DateTime.tryParse(value['last_seen_at']?.toString() ?? ''),
      inventory: value['inventory'] is Map<String, dynamic>
          ? value['inventory'] as Map<String, dynamic>
          : null,
      inventoryUpdatedAt: DateTime.tryParse(
        value['inventory_updated_at']?.toString() ?? '',
      ),
    );
  }
}

class RhmAuditEvent {
  const RhmAuditEvent({
    required this.id,
    required this.eventType,
    required this.actor,
    required this.action,
    required this.entityType,
    this.entityId,
    this.createdAt,
  });

  final String id;
  final String eventType;
  final String actor;
  final String action;
  final String? entityType;
  final String? entityId;
  final DateTime? createdAt;

  factory RhmAuditEvent.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['event_type'] is! String ||
        value['actor'] is! String ||
        value['action'] is! String ||
        (value['entity_type'] != null && value['entity_type'] is! String)) {
      throw const RhmApiException('Invalid audit event returned by RHM.');
    }
    return RhmAuditEvent(
      id: value['id'] as String,
      eventType: value['event_type'] as String,
      actor: value['actor'] as String,
      action: value['action'] as String,
      entityType: value['entity_type'] as String?,
      entityId: value['entity_id'] as String?,
      createdAt: DateTime.tryParse(value['created_at']?.toString() ?? ''),
    );
  }
}

class RhmTask {
  const RhmTask({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    this.description,
    this.projectId,
  });

  final String id;
  final String title;
  final String status;
  final String priority;
  final String? description;
  final String? projectId;

  factory RhmTask.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['title'] is! String ||
        value['status'] is! String) {
      throw const RhmApiException('Invalid task returned by RHM.');
    }
    return RhmTask(
      id: value['id'] as String,
      title: value['title'] as String,
      status: value['status'] as String,
      priority: value['priority'] as String? ?? 'normal',
      description: value['description'] as String?,
      projectId: value['project_id'] as String?,
    );
  }
}

class RhmMemory {
  const RhmMemory({
    required this.id,
    required this.content,
    required this.kind,
    required this.importance,
    required this.confidence,
    this.source,
    this.projectId,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String content;
  final String kind;
  final double importance;
  final double confidence;
  final String? source;
  final String? projectId;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  factory RhmMemory.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['content'] is! String ||
        value['kind'] is! String) {
      throw const RhmApiException('Invalid memory returned by RHM.');
    }
    return RhmMemory(
      id: value['id'] as String,
      content: value['content'] as String,
      kind: value['kind'] as String,
      importance: (value['importance'] as num?)?.toDouble() ?? 0.5,
      confidence: (value['confidence'] as num?)?.toDouble() ?? 0.5,
      source: value['source'] as String?,
      projectId: value['project_id'] as String?,
      createdAt: DateTime.tryParse(value['created_at']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(value['expires_at']?.toString() ?? ''),
    );
  }
}

class RhmAgentReply {
  const RhmAgentReply({
    required this.content,
    required this.provider,
    required this.model,
    required this.toolCalls,
  });

  final String content;
  final String provider;
  final String model;
  final int toolCalls;

  factory RhmAgentReply.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['content'] is! String ||
        value['provider'] is! String ||
        value['model'] is! String) {
      throw const RhmApiException('Invalid agent response returned by RHM.');
    }
    return RhmAgentReply(
      content: value['content'] as String,
      provider: value['provider'] as String,
      model: value['model'] as String,
      toolCalls: value['tool_calls'] is int ? value['tool_calls'] as int : 0,
    );
  }
}

class RhmMcpServer {
  const RhmMcpServer({
    required this.id,
    required this.endpoint,
    required this.enabled,
    required this.approved,
    required this.allowedTools,
    required this.credentialConfigured,
  });

  final String id;
  final String endpoint;
  final bool enabled;
  final bool approved;
  final List<String> allowedTools;
  final bool credentialConfigured;

  bool get readyForDiscovery => enabled && approved && credentialConfigured;

  factory RhmMcpServer.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['server_id'] is! String ||
        value['endpoint'] is! String ||
        value['allowed_tools'] is! List) {
      throw const RhmApiException('استجابة خادم MCP غير صالحة.');
    }
    return RhmMcpServer(
      id: value['server_id'] as String,
      endpoint: value['endpoint'] as String,
      enabled: value['enabled'] == true,
      approved: value['approved'] == true,
      allowedTools: (value['allowed_tools'] as List).whereType<String>().toList(),
      credentialConfigured: value['credential_configured'] == true,
    );
  }
}

class RhmMcpTool {
  const RhmMcpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  factory RhmMcpTool.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['name'] is! String ||
        (value['input_schema'] != null && value['input_schema'] is! Map)) {
      throw const RhmApiException('بيانات أداة MCP غير صالحة.');
    }
    return RhmMcpTool(
      name: value['name'] as String,
      description: value['description'] as String? ?? '',
      inputSchema: value['input_schema'] is Map<String, dynamic>
          ? value['input_schema'] as Map<String, dynamic>
          : const <String, dynamic>{},
    );
  }
}

class RhmServerUpdateSnapshot {
  const RhmServerUpdateSnapshot({
    required this.autoUpdate,
    required this.intervalSeconds,
    required this.supervisorRunning,
    required this.runtime,
    this.frontend,
  });

  final bool autoUpdate;
  final int intervalSeconds;
  final bool supervisorRunning;
  final Map<String, dynamic> runtime;
  final Map<String, dynamic>? frontend;

  factory RhmServerUpdateSnapshot.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const RhmApiException('استجابة حالة تحديث السيرفر غير صالحة.');
    }
    final preferences = value['preferences'];
    final runtime = value['runtime'];
    final frontend = value['frontend'];
    if (preferences is! Map<String, dynamic> ||
        runtime is! Map<String, dynamic> ||
        (frontend != null && frontend is! Map<String, dynamic>)) {
      throw const RhmApiException('بيانات لوحة تحديث السيرفر غير مكتملة.');
    }
    return RhmServerUpdateSnapshot(
      autoUpdate: preferences['auto_update'] == true,
      intervalSeconds: preferences['interval_seconds'] is int
          ? preferences['interval_seconds'] as int
          : 300,
      supervisorRunning: value['supervisor_running'] == true,
      runtime: runtime,
      frontend: frontend is Map<String, dynamic> ? frontend : null,
    );
  }
}

class RhmServerUpdateEvent {
  const RhmServerUpdateEvent({
    required this.id,
    required this.state,
    required this.message,
    required this.createdAt,
    this.targetSha,
  });

  final String id;
  final String state;
  final String message;
  final DateTime? createdAt;
  final String? targetSha;

  factory RhmServerUpdateEvent.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['state'] is! String ||
        value['message'] is! String) {
      throw const RhmApiException('حدث تحديث سيرفر غير صالح.');
    }
    return RhmServerUpdateEvent(
      id: value['id'] as String,
      state: value['state'] as String,
      message: value['message'] as String,
      createdAt: DateTime.tryParse(value['created_at']?.toString() ?? ''),
      targetSha: value['target_sha'] as String?,
    );
  }
}

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

  Future<void> checkConnection() async {
    final response = await _send(
      http.Request('GET', _endpoint('mobile/health')),
    );
    if (response.statusCode != 200) {
      throw RhmApiException('RHM connection failed (HTTP ${response.statusCode}).');
    }
    final decoded = _decode(response);
    if (decoded is! Map<String, dynamic> || decoded['status'] != 'ok') {
      throw const RhmApiException('The RHM server did not confirm readiness.');
    }
  }

  Future<RhmServerUpdateSnapshot> getServerUpdateStatus() async {
    final response = await _send(
      http.Request('GET', _endpoint('server-update/status')),
    );
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل حالة تحديث السيرفر (HTTP ${response.statusCode}).');
    }
    return RhmServerUpdateSnapshot.fromJson(_decode(response));
  }

  Future<List<RhmServerUpdateEvent>> getServerUpdateEvents({int limit = 30}) async {
    final response = await _send(
      http.Request('GET', _endpoint('server-update/events?limit=$limit')),
    );
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل إشعارات تحديث السيرفر (HTTP ${response.statusCode}).');
    }
    final data = _decode(response);
    if (data is! Map<String, dynamic> || data['items'] is! List) {
      throw const RhmApiException('سجل إشعارات تحديث السيرفر غير صالح.');
    }
    return (data['items'] as List).map(RhmServerUpdateEvent.fromJson).toList();
  }

  Future<RhmServerUpdateSnapshot> setServerAutoUpdate(bool enabled) async {
    final request = http.Request('POST', _endpoint('server-update/preferences'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'auto_update': enabled});
    final response = await _send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تغيير إعداد التحديث التلقائي (HTTP ${response.statusCode}).');
    }
    return getServerUpdateStatus();
  }

  Future<Map<String, dynamic>> checkServerUpdates() async {
    final request = http.Request('POST', _endpoint('server-update/check'))
      ..headers['content-type'] = 'application/json'
      ..body = '{}';
    final response = await _send(request);
    final data = _decode(response);
    if (response.statusCode != 200) {
      final detail = data is Map<String, dynamic> ? data['detail'] : null;
      throw RhmApiException(detail is String ? detail : 'فشل فحص تحديثات السيرفر (HTTP ${response.statusCode}).');
    }
    if (data is! Map<String, dynamic>) {
      throw const RhmApiException('استجابة فحص تحديث السيرفر غير صالحة.');
    }
    return data;
  }

  Future<void> requestServerUpdate() async {
    final request = http.Request('POST', _endpoint('server-update/apply'))
      ..headers['content-type'] = 'application/json'
      ..body = '{}';
    final response = await _send(request);
    final data = _decode(response);
    if (response.statusCode != 200) {
      final detail = data is Map<String, dynamic> ? data['detail'] : null;
      throw RhmApiException(detail is String ? detail : 'تعذر طلب تحديث السيرفر (HTTP ${response.statusCode}).');
    }
  }

  Future<Map<String, dynamic>> getNotifications({
    int limit = 100,
    bool unreadOnly = false,
  }) async {
    final response = await _send(
      http.Request(
        'GET',
        _endpoint('notifications?limit=$limit&unread_only=$unreadOnly'),
      ),
    );
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل إشعارات RHM (HTTP ${response.statusCode}).');
    }
    final data = _decode(response);
    if (data is! Map<String, dynamic> || data['items'] is! List) {
      throw const RhmApiException('استجابة إشعارات RHM غير صالحة.');
    }
    return data;
  }

  Future<Map<String, dynamic>> getNotificationPreferences() async {
    final response = await _send(
      http.Request('GET', _endpoint('notifications/preferences')),
    );
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل إعدادات الإشعارات (HTTP ${response.statusCode}).');
    }
    final data = _decode(response);
    if (data is! Map<String, dynamic>) {
      throw const RhmApiException('إعدادات الإشعارات غير صالحة.');
    }
    return data;
  }

  Future<Map<String, dynamic>> updateNotificationPreferences(
    Map<String, dynamic> changes,
  ) async {
    final request = http.Request('POST', _endpoint('notifications/preferences'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(changes);
    final response = await _send(request);
    final data = _decode(response);
    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      final detail = data is Map<String, dynamic> ? data['detail'] : null;
      throw RhmApiException(
        detail is String ? detail : 'تعذر حفظ إعدادات الإشعارات (HTTP ${response.statusCode}).',
      );
    }
    return data;
  }

  Future<void> markNotificationsRead({
    List<String> eventIds = const [],
    bool markAll = false,
  }) async {
    final request = http.Request('POST', _endpoint('notifications/read'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({
        'event_ids': eventIds,
        'mark_all': markAll,
      });
    final response = await _send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحديث حالة الإشعارات (HTTP ${response.statusCode}).');
    }
  }

  Future<void> reportAppUpdateAvailable(String version) async {
    final request = http.Request('POST', _endpoint('mobile/updates/notifications'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'version': version});
    final response = await _send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تسجيل إشعار تحديث التطبيق (HTTP ${response.statusCode}).');
    }
  }

  Future<Map<String, dynamic>> fetchLatestUpdate() async {
    final response = await _send(
      http.Request('GET', _endpoint('mobile/updates/latest')),
    );
    if (response.statusCode != 200) {
      throw RhmApiException('RHM update discovery failed (HTTP ${response.statusCode}).');
    }
    final data = _decode(response);
    if (data is! Map<String, dynamic> || data['assets'] is! List) {
      throw const RhmApiException('RHM returned invalid update metadata.');
    }
    return data;
  }

  Future<Uint8List> downloadUpdateAsset(int assetId) async {
    if (assetId <= 0) {
      throw const RhmApiException('RHM update asset identifier is invalid.');
    }
    final request = http.Request('GET', _endpoint('mobile/updates/assets/$assetId'))
      ..headers['accept'] = 'application/octet-stream';
    final response = await _send(
      request,
      timeout: const Duration(minutes: 5),
    );
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw RhmApiException('RHM update asset download failed (HTTP ${response.statusCode}).');
    }
    if (response.bodyBytes.length > 100 * 1024 * 1024) {
      throw const RhmApiException('RHM update asset exceeds the allowed size.');
    }
    return response.bodyBytes;
  }

  Future<List<RhmProviderInfo>> getProviders() async {
    final response = await _send(http.Request('GET', _endpoint('providers')));
    if (response.statusCode != 200) throw RhmApiException('Provider discovery failed (HTTP ${response.statusCode}).');
    final data = _decode(response);
    if (data is! Map<String, dynamic> || data['providers'] is! List) throw const RhmApiException('Invalid provider response.');
    return (data['providers'] as List).map(RhmProviderInfo.fromJson).toList();
  }
  Future<List<RhmMcpServer>> listMcpServers() async {
    final response = await _send(
      http.Request('GET', _endpoint('mcp-client/servers')),
    );
    if (response.statusCode != 200) {
      // Error bodies are untrusted: never surface arbitrary backend text or secrets.
      throw RhmApiException(
        'تعذر تحميل خوادم MCP (HTTP ${response.statusCode}).',
      );
    }
    final data = _decode(response);
    if (data is! Map<String, dynamic> || data['servers'] is! List) {
      throw const RhmApiException('استجابة قائمة خوادم MCP غير صالحة.');
    }
    return (data['servers'] as List).map(RhmMcpServer.fromJson).toList();
  }

  Future<List<RhmMcpTool>> discoverMcpTools(String serverId) async {
    bool isAllowedUnit(int code) =>
        (code >= 97 && code <= 122) ||
        (code >= 48 && code <= 57) ||
        code == 95 ||
        code == 45;
    final codes = serverId.codeUnits;
    final validId = codes.isNotEmpty &&
        codes.length <= 48 &&
        codes.first >= 97 &&
        codes.first <= 122 &&
        codes.every(isAllowedUnit);
    if (!validId) {
      throw const RhmApiException('معرّف خادم MCP غير صالح.');
    }
    final response = await _send(
      http.Request(
        'GET',
        _endpoint('mcp-client/servers/${Uri.encodeComponent(serverId)}/tools'),
      ),
      timeout: const Duration(seconds: 40),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      final detail = data is Map<String, dynamic> ? data['detail'] : null;
      throw RhmApiException(
        detail is String ? detail : 'تعذر اكتشاف أدوات MCP (HTTP ${response.statusCode}).',
      );
    }
    if (data is! Map<String, dynamic> || data['tools'] is! List) {
      throw const RhmApiException('استجابة أدوات MCP غير صالحة.');
    }
    return (data['tools'] as List).map(RhmMcpTool.fromJson).toList();
  }

  Future<Map<String, dynamic>> invokeMcpTool(
    String serverId,
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    final request = http.Request(
      'POST',
      _endpoint(
        'mcp-client/servers/${Uri.encodeComponent(serverId)}/tools/${Uri.encodeComponent(toolName)}',
      ),
    )
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'arguments': arguments});
    final response = await _send(
      request,
      timeout: const Duration(seconds: 25),
    );
    final data = _decode(response);
    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      final detail = data is Map<String, dynamic> ? data['detail'] : null;
      throw RhmApiException(
        detail is String ? detail : 'فشل استدعاء أداة MCP (HTTP ${response.statusCode}).',
      );
    }
    return data;
  }

  Future<RhmChatReply> sendChat(String prompt, {String? preferredProvider, String? preferredModel}) async {
    if (prompt.trim().isEmpty) {
      throw const RhmApiException('Enter a message before sending.');
    }
    final request = http.Request('POST', _endpoint('mobile/chat'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'prompt': prompt, 'preferred_provider': preferredProvider, 'preferred_model': preferredModel});
    final response = await _send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('RHM chat failed (HTTP ${response.statusCode}).');
    }
    return RhmChatReply.fromJson(_decode(response));
  }


  Future<List<RhmConversation>> listConversations({int limit = 50}) async {
    final response = await _send(
      http.Request('GET', _endpoint('conversations?limit=$limit')),
    );
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل سجل المحادثات (HTTP ${response.statusCode}).');
    }
    final data = _decode(response);
    if (data is! List) throw const RhmApiException('استجابة سجل المحادثات غير صالحة.');
    return data.map(RhmConversation.fromJson).toList();
  }

  Future<RhmConversation> createConversation({String title = 'محادثة جديدة'}) async {
    final request = http.Request('POST', _endpoint('conversations'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'title': title});
    final response = await _send(request);
    if (response.statusCode != 201) {
      throw RhmApiException('تعذر إنشاء محادثة جديدة (HTTP ${response.statusCode}).');
    }
    return RhmConversation.fromJson(_decode(response));
  }

  Future<RhmConversation> renameConversation(String id, String title) async {
    final request = http.Request(
      'PATCH',
      _endpoint('conversations/${Uri.encodeComponent(id)}'),
    )
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'title': title});
    final response = await _send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر إعادة تسمية المحادثة (HTTP ${response.statusCode}).');
    }
    return RhmConversation.fromJson(_decode(response));
  }

  Future<void> deleteConversation(String id) async {
    final request = http.Request(
      'DELETE',
      _endpoint('conversations/${Uri.encodeComponent(id)}'),
    )
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'confirm': true});
    final response = await _send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر حذف المحادثة (HTTP ${response.statusCode}).');
    }
  }

  Future<RhmConversationPage> listConversationMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (before != null) query['before'] = before;
    final uri = _endpoint(
      'conversations/${Uri.encodeComponent(conversationId)}/messages',
    ).replace(queryParameters: query);
    final response = await _send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل رسائل المحادثة (HTTP ${response.statusCode}).');
    }
    final data = _decode(response);
    if (data is! Map<String, dynamic> || data['items'] is! List) {
      throw const RhmApiException('استجابة رسائل المحادثة غير صالحة.');
    }
    return RhmConversationPage(
      items: (data['items'] as List)
          .map(RhmConversationMessage.fromJson)
          .toList(),
      hasMore: data['has_more'] == true,
      nextBefore: data['next_before'] as String?,
    );
  }

  Future<RhmConversationTurn> sendConversationMessage(
    String conversationId,
    String prompt, {
    required String requestId,
    String? projectName,
    String? preferredProvider,
    String? preferredModel,
  }) async {
    if (prompt.trim().isEmpty) {
      throw const RhmApiException('اكتب رسالة قبل الإرسال.');
    }
    final request = http.Request(
      'POST',
      _endpoint('conversations/${Uri.encodeComponent(conversationId)}/messages'),
    )
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({
        'prompt': prompt,
        'request_id': requestId,
        'project_name': projectName,
        'preferred_provider': preferredProvider,
        'preferred_model': preferredModel,
        'allow_cloud_fallback': false,
      });
    final response = await _send(request);
    if (response.statusCode != 200) {
      final data = _decode(response);
      final detail = data is Map<String, dynamic> && data['detail'] is String
          ? data['detail'] as String
          : 'HTTP ${response.statusCode}';
      throw RhmApiException('تعذر إكمال المحادثة: $detail');
    }
    return RhmConversationTurn.fromJson(_decode(response));
  }

  Future<List<RhmProject>> listProjects() async {
    final response = await _send(http.Request('GET', _endpoint('projects')));
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل المشاريع (HTTP ${response.statusCode}).');
    }
    final data = _decode(response);
    if (data is! List) throw const RhmApiException('استجابة المشاريع غير صالحة.');
    return data.map(RhmProject.fromJson).toList();
  }

  Future<RhmProject> createProject(String name, {String? description}) async {
    final request = http.Request('POST', _endpoint('projects'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'name': name, 'description': description});
    final response = await _send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر إنشاء المشروع (HTTP ${response.statusCode}).');
    }
    final data = _decode(response);
    if (data is! Map<String, dynamic> ||
        data['id'] is! String ||
        data['name'] is! String) {
      throw const RhmApiException('استجابة إنشاء المشروع غير صالحة.');
    }
    return RhmProject(
      id: data['id'] as String,
      name: data['name'] as String,
      status: data['status'] as String? ?? 'active',
    );
  }

  Future<Map<String, dynamic>> getProjectContext(String projectName) async {
    final uri = _endpoint('projects/${Uri.encodeComponent(projectName)}/context');
    final response = await _send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل سياق المشروع (HTTP ${response.statusCode}).');
    }
    final data = _decode(response);
    if (data is! Map<String, dynamic>) {
      throw const RhmApiException('استجابة سياق المشروع غير صالحة.');
    }
    return data;
  }

  Future<List<RhmTask>> listTasks({String? projectName}) async {
    final uri = _endpoint('tasks').replace(
      queryParameters: projectName == null || projectName.isEmpty
          ? null
          : {'project_name': projectName},
    );
    final response = await _send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل المهام (HTTP ${response.statusCode}).');
    }
    final data = _decode(response);
    if (data is! List) throw const RhmApiException('استجابة المهام غير صالحة.');
    return data.map(RhmTask.fromJson).toList();
  }

  Future<RhmTask> createTask(
    String title, {
    String? projectName,
    String? description,
    String priority = 'normal',
  }) async {
    final request = http.Request('POST', _endpoint('tasks'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({
        'title': title,
        'project_name': projectName,
        'description': description,
        'priority': priority,
      });
    final response = await _send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر إنشاء المهمة (HTTP ${response.statusCode}).');
    }
    return RhmTask.fromJson(_decode(response));
  }

  Future<RhmTask> updateTask(
    String id, {
    String? status,
    String? priority,
    String? title,
    String? description,
  }) async {
    final changes = <String, dynamic>{
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
    };
    if (changes.isEmpty) {
      throw const RhmApiException('حدد تغييرًا واحدًا على الأقل للمهمة.');
    }
    final request = http.Request(
      'PATCH',
      _endpoint('tasks/${Uri.encodeComponent(id)}'),
    )
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(changes);
    final response = await _send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحديث المهمة (HTTP ${response.statusCode}).');
    }
    return RhmTask.fromJson(_decode(response));
  }

  Future<List<RhmMemory>> listMemories({
    int limit = 50,
    int offset = 0,
    String? projectName,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (projectName != null && projectName.isNotEmpty)
        'project_name': projectName,
    };
    final uri = _endpoint('memories').replace(queryParameters: query);
    final response = await _send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل الذاكرة (HTTP ${response.statusCode}).');
    }
    final data = _decode(response);
    if (data is! List) throw const RhmApiException('استجابة الذاكرة غير صالحة.');
    return data.map(RhmMemory.fromJson).toList();
  }

  Future<List<RhmMemory>> searchMemories(String query, {int limit = 20}) async {
    final uri = _endpoint('memories/search').replace(
      queryParameters: {'q': query, 'limit': '$limit'},
    );
    final response = await _send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر البحث في الذاكرة (HTTP ${response.statusCode}).');
    }
    final data = _decode(response);
    if (data is! List) throw const RhmApiException('استجابة البحث غير صالحة.');
    return data.map(RhmMemory.fromJson).toList();
  }

  Future<RhmMemory> createMemory(
    String content, {
    String kind = 'semantic',
    double importance = 0.5,
    double confidence = 0.7,
    String? projectName,
  }) async {
    final request = http.Request('POST', _endpoint('memories'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({
        'content': content,
        'kind': kind,
        'importance': importance,
        'confidence': confidence,
        'project_name': projectName,
      });
    final response = await _send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر حفظ الذاكرة (HTTP ${response.statusCode}).');
    }
    return RhmMemory.fromJson(_decode(response));
  }

  Future<RhmMemory> updateMemory(
    String id, {
    String? content,
    String? kind,
    double? importance,
    double? confidence,
  }) async {
    final changes = <String, dynamic>{
      if (content != null) 'content': content,
      if (kind != null) 'kind': kind,
      if (importance != null) 'importance': importance,
      if (confidence != null) 'confidence': confidence,
    };
    if (changes.isEmpty) {
      throw const RhmApiException('حدد تعديلًا واحدًا على الأقل للذاكرة.');
    }
    final request = http.Request(
      'PATCH',
      _endpoint('memories/${Uri.encodeComponent(id)}'),
    )
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(changes);
    final response = await _send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تعديل الذاكرة (HTTP ${response.statusCode}).');
    }
    return RhmMemory.fromJson(_decode(response));
  }

  Future<void> deleteMemory(String id) async {
    final uri = _endpoint('memories/${Uri.encodeComponent(id)}').replace(
      queryParameters: {'confirm': 'true'},
    );
    final request = http.Request('DELETE', uri)
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'confirm': true});
    final response = await _send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر حذف الذاكرة (HTTP ${response.statusCode}).');
    }
  }

  Future<List<RhmDevice>> listDevices() async {
    final response = await _send(http.Request('GET', _endpoint('devices')));
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل الأجهزة (HTTP ${response.statusCode}).');
    }
    final data = _decode(response);
    if (data is! List) throw const RhmApiException('استجابة الأجهزة غير صالحة.');
    return data.map(RhmDevice.fromJson).toList();
  }

  Future<void> revokeDevice(String id) async {
    final request = http.Request(
      'POST',
      _endpoint('devices/${Uri.encodeComponent(id)}/revoke'),
    )
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'confirm': true});
    final response = await _send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر إلغاء اعتماد الجهاز (HTTP ${response.statusCode}).');
    }
  }

  Future<List<RhmAuditEvent>> listAuditEvents({
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = _endpoint('audit').replace(
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    );
    final response = await _send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل سجل التدقيق (HTTP ${response.statusCode}).');
    }
    final data = _decode(response);
    if (data is! List) throw const RhmApiException('استجابة سجل التدقيق غير صالحة.');
    return data.map(RhmAuditEvent.fromJson).toList();
  }

  Future<RhmAgentReply> runAgent(
    String prompt, {
    String? projectName,
    String? preferredProvider,
    String? preferredModel,
  }) async {
    if (prompt.trim().isEmpty) {
      throw const RhmApiException('اكتب طلبًا للوكيل أولًا.');
    }
    final request = http.Request('POST', _endpoint('agent'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({
        'prompt': prompt,
        'project_name': projectName,
        'preferred_provider': preferredProvider,
        'preferred_model': preferredModel,
        'allow_cloud_fallback': false,
      });
    final response = await _send(
      request,
      timeout: const Duration(minutes: 3),
    );
    if (response.statusCode != 200) {
      final data = _decode(response);
      final detail = data is Map<String, dynamic> && data['detail'] is String
          ? data['detail'] as String
          : 'HTTP ${response.statusCode}';
      throw RhmApiException('تعذر تشغيل الوكيل: $detail');
    }
    return RhmAgentReply.fromJson(_decode(response));
  }

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
