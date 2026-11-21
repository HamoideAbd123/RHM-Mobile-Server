part of '../api_client.dart';

extension RhmDevicePairingApi on RhmApiClient {
  Future<Map<String, dynamic>> createDevicePairingRequest({
    required String name,
    required String publicKey,
  }) async {
    final request = http.Request('POST', _endpoint('mobile/pairing/requests'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'name': name, 'public_key': publicKey});
    final response = await _send(
      request,
      timeout: const Duration(seconds: 20),
    );
    if (response.statusCode != 201) {
      throw RhmApiException(
        'تعذر إنشاء طلب ربط الجهاز (HTTP ${response.statusCode}).',
      );
    }
    final data = _decode(response);
    if (data is! Map<String, dynamic> ||
        data['request_id'] is! String ||
        data['pairing_code'] is! String ||
        data['pairing_secret'] is! String ||
        data['challenge'] is! String) {
      throw const RhmApiException('بيانات طلب ربط الجهاز غير صالحة.');
    }
    return data;
  }

  Future<Map<String, dynamic>?> completeDevicePairingRequest({
    required String requestId,
    required String pairingSecret,
    required String signature,
  }) async {
    final request = http.Request(
      'POST',
      _endpoint(
        'mobile/pairing/requests/${Uri.encodeComponent(requestId)}/complete',
      ),
    )
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({
        'pairing_secret': pairingSecret,
        'signature': signature,
      });
    final response = await _send(
      request,
      timeout: const Duration(seconds: 20),
    );
    if (response.statusCode == 202) return null;
    if (response.statusCode != 200) {
      throw RhmApiException(
        'تعذر إكمال ربط الجهاز (HTTP ${response.statusCode}).',
      );
    }
    final data = _decode(response);
    if (data is! Map<String, dynamic> ||
        data['device_id'] is! String ||
        data['access_token'] is! String ||
        data['refresh_token'] is! String) {
      throw const RhmApiException('اعتماد الجهاز المستلم غير صالح.');
    }
    return data;
  }
}
