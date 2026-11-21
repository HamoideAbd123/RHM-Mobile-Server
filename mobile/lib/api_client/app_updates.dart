part of '../api_client.dart';

extension RhmAppUpdatesApi on RhmApiClient {
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
}
