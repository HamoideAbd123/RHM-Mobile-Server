part of '../api_client.dart';

extension RhmConversationsApi on RhmApiClient {
  Future<List<RhmConversation>> listConversations({int limit = 50}) async {
    final response = await this._send(
      http.Request('GET', this._endpoint('conversations?limit=$limit')),
    );
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل سجل المحادثات (HTTP ${response.statusCode}).');
    }
    final data = this._decode(response);
    if (data is! List) throw const RhmApiException('استجابة سجل المحادثات غير صالحة.');
    return data.map(RhmConversation.fromJson).toList();
  }

  Future<RhmConversation> createConversation({String title = 'محادثة جديدة'}) async {
    final request = http.Request('POST', this._endpoint('conversations'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'title': title});
    final response = await this._send(request);
    if (response.statusCode != 201) {
      throw RhmApiException('تعذر إنشاء محادثة جديدة (HTTP ${response.statusCode}).');
    }
    return RhmConversation.fromJson(this._decode(response));
  }

  Future<RhmConversation> renameConversation(String id, String title) async {
    final request = http.Request(
      'PATCH',
      this._endpoint('conversations/${Uri.encodeComponent(id)}'),
    )
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'title': title});
    final response = await this._send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر إعادة تسمية المحادثة (HTTP ${response.statusCode}).');
    }
    return RhmConversation.fromJson(this._decode(response));
  }

  Future<void> deleteConversation(String id) async {
    final request = http.Request(
      'DELETE',
      this._endpoint('conversations/${Uri.encodeComponent(id)}'),
    )
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'confirm': true});
    final response = await this._send(request);
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
    final uri = this._endpoint(
      'conversations/${Uri.encodeComponent(conversationId)}/messages',
    ).replace(queryParameters: query);
    final response = await this._send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل رسائل المحادثة (HTTP ${response.statusCode}).');
    }
    final data = this._decode(response);
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
      this._endpoint('conversations/${Uri.encodeComponent(conversationId)}/messages'),
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
    final response = await this._send(request);
    if (response.statusCode != 200) {
      final data = this._decode(response);
      final detail = data is Map<String, dynamic> && data['detail'] is String
          ? data['detail'] as String
          : 'HTTP ${response.statusCode}';
      throw RhmApiException('تعذر إكمال المحادثة: $detail');
    }
    return RhmConversationTurn.fromJson(this._decode(response));
  }
}
