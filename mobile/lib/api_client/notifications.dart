part of '../api_client.dart';

extension RhmNotificationsApi on RhmApiClient {
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
}
