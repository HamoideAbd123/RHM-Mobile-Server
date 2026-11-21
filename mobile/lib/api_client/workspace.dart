part of '../api_client.dart';

extension RhmWorkspaceApi on RhmApiClient {
  Future<List<RhmProject>> listProjects() async {
    final response = await this._send(http.Request('GET', this._endpoint('projects')));
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل المشاريع (HTTP ${response.statusCode}).');
    }
    final data = this._decode(response);
    if (data is! List) throw const RhmApiException('استجابة المشاريع غير صالحة.');
    return data.map(RhmProject.fromJson).toList();
  }

  Future<RhmProject> createProject(String name, {String? description}) async {
    final request = http.Request('POST', this._endpoint('projects'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'name': name, 'description': description});
    final response = await this._send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر إنشاء المشروع (HTTP ${response.statusCode}).');
    }
    final data = this._decode(response);
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
    final uri = this._endpoint('projects/${Uri.encodeComponent(projectName)}/context');
    final response = await this._send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل سياق المشروع (HTTP ${response.statusCode}).');
    }
    final data = this._decode(response);
    if (data is! Map<String, dynamic>) {
      throw const RhmApiException('استجابة سياق المشروع غير صالحة.');
    }
    return data;
  }

  Future<List<RhmTask>> listTasks({String? projectName}) async {
    final uri = this._endpoint('tasks').replace(
      queryParameters: projectName == null || projectName.isEmpty
          ? null
          : {'project_name': projectName},
    );
    final response = await this._send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل المهام (HTTP ${response.statusCode}).');
    }
    final data = this._decode(response);
    if (data is! List) throw const RhmApiException('استجابة المهام غير صالحة.');
    return data.map(RhmTask.fromJson).toList();
  }

  Future<RhmTask> createTask(
    String title, {
    String? projectName,
    String? description,
    String priority = 'normal',
  }) async {
    final request = http.Request('POST', this._endpoint('tasks'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({
        'title': title,
        'project_name': projectName,
        'description': description,
        'priority': priority,
      });
    final response = await this._send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر إنشاء المهمة (HTTP ${response.statusCode}).');
    }
    return RhmTask.fromJson(this._decode(response));
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
      this._endpoint('tasks/${Uri.encodeComponent(id)}'),
    )
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(changes);
    final response = await this._send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحديث المهمة (HTTP ${response.statusCode}).');
    }
    return RhmTask.fromJson(this._decode(response));
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
    final uri = this._endpoint('memories').replace(queryParameters: query);
    final response = await this._send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل الذاكرة (HTTP ${response.statusCode}).');
    }
    final data = this._decode(response);
    if (data is! List) throw const RhmApiException('استجابة الذاكرة غير صالحة.');
    return data.map(RhmMemory.fromJson).toList();
  }

  Future<List<RhmMemory>> searchMemories(String query, {int limit = 20}) async {
    final uri = this._endpoint('memories/search').replace(
      queryParameters: {'q': query, 'limit': '$limit'},
    );
    final response = await this._send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر البحث في الذاكرة (HTTP ${response.statusCode}).');
    }
    final data = this._decode(response);
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
    final request = http.Request('POST', this._endpoint('memories'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({
        'content': content,
        'kind': kind,
        'importance': importance,
        'confidence': confidence,
        'project_name': projectName,
      });
    final response = await this._send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر حفظ الذاكرة (HTTP ${response.statusCode}).');
    }
    return RhmMemory.fromJson(this._decode(response));
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
      this._endpoint('memories/${Uri.encodeComponent(id)}'),
    )
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(changes);
    final response = await this._send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تعديل الذاكرة (HTTP ${response.statusCode}).');
    }
    return RhmMemory.fromJson(this._decode(response));
  }

  Future<void> deleteMemory(String id) async {
    final uri = this._endpoint('memories/${Uri.encodeComponent(id)}').replace(
      queryParameters: {'confirm': 'true'},
    );
    final request = http.Request('DELETE', uri)
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'confirm': true});
    final response = await this._send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر حذف الذاكرة (HTTP ${response.statusCode}).');
    }
  }

  Future<List<RhmDevice>> listDevices() async {
    final response = await this._send(http.Request('GET', this._endpoint('devices')));
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل الأجهزة (HTTP ${response.statusCode}).');
    }
    final data = this._decode(response);
    if (data is! List) throw const RhmApiException('استجابة الأجهزة غير صالحة.');
    return data.map(RhmDevice.fromJson).toList();
  }

  Future<void> revokeDevice(String id) async {
    final request = http.Request(
      'POST',
      this._endpoint('devices/${Uri.encodeComponent(id)}/revoke'),
    )
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'confirm': true});
    final response = await this._send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر إلغاء اعتماد الجهاز (HTTP ${response.statusCode}).');
    }
  }

  Future<List<RhmAuditEvent>> listAuditEvents({
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = this._endpoint('audit').replace(
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    );
    final response = await this._send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل سجل التدقيق (HTTP ${response.statusCode}).');
    }
    final data = this._decode(response);
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
    final request = http.Request('POST', this._endpoint('agent'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({
        'prompt': prompt,
        'project_name': projectName,
        'preferred_provider': preferredProvider,
        'preferred_model': preferredModel,
        'allow_cloud_fallback': false,
      });
    final response = await this._send(
      request,
      timeout: const Duration(minutes: 3),
    );
    if (response.statusCode != 200) {
      final data = this._decode(response);
      final detail = data is Map<String, dynamic> && data['detail'] is String
          ? data['detail'] as String
          : 'HTTP ${response.statusCode}';
      throw RhmApiException('تعذر تشغيل الوكيل: $detail');
    }
    return RhmAgentReply.fromJson(this._decode(response));
  }
}
