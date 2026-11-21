part of '../api_client.dart';

extension _RhmServerUpdatesApi on RhmApiClient {
  Future<RhmServerUpdateSnapshot> getServerUpdateStatus() async {
    final response = await this._send(
      http.Request('GET', this._endpoint('server-update/status')),
    );
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل حالة تحديث السيرفر (HTTP ${response.statusCode}).');
    }
    return RhmServerUpdateSnapshot.fromJson(this._decode(response));
  }

  Future<List<RhmServerUpdateEvent>> getServerUpdateEvents({int limit = 30}) async {
    final response = await this._send(
      http.Request('GET', this._endpoint('server-update/events?limit=$limit')),
    );
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تحميل إشعارات تحديث السيرفر (HTTP ${response.statusCode}).');
    }
    final data = this._decode(response);
    if (data is! Map<String, dynamic> || data['items'] is! List) {
      throw const RhmApiException('سجل إشعارات تحديث السيرفر غير صالح.');
    }
    return (data['items'] as List).map(RhmServerUpdateEvent.fromJson).toList();
  }

  Future<RhmServerUpdateSnapshot> setServerAutoUpdate(bool enabled) async {
    final request = http.Request('POST', this._endpoint('server-update/preferences'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'auto_update': enabled});
    final response = await this._send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('تعذر تغيير إعداد التحديث التلقائي (HTTP ${response.statusCode}).');
    }
    return this.getServerUpdateStatus();
  }

  Future<Map<String, dynamic>> checkServerUpdates() async {
    final request = http.Request('POST', this._endpoint('server-update/check'))
      ..headers['content-type'] = 'application/json'
      ..body = '{}';
    final response = await this._send(request);
    final data = this._decode(response);
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
    final request = http.Request('POST', this._endpoint('server-update/apply'))
      ..headers['content-type'] = 'application/json'
      ..body = '{}';
    final response = await this._send(request);
    final data = this._decode(response);
    if (response.statusCode != 200) {
      final detail = data is Map<String, dynamic> ? data['detail'] : null;
      throw RhmApiException(detail is String ? detail : 'تعذر طلب تحديث السيرفر (HTTP ${response.statusCode}).');
    }
  }
}
