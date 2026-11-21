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
