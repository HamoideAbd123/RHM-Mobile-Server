part of '../api_client.dart';

extension RhmProvidersChatApi on RhmApiClient {
  Future<void> checkConnection() async {
    final response = await this._send(
      http.Request('GET', this._endpoint('mobile/health')),
    );
    if (response.statusCode != 200) {
      throw RhmApiException('RHM connection failed (HTTP ${response.statusCode}).');
    }
    final decoded = this._decode(response);
    if (decoded is! Map<String, dynamic> || decoded['status'] != 'ok') {
      throw const RhmApiException('The RHM server did not confirm readiness.');
    }
  }

  Future<List<RhmProviderInfo>> getProviders() async {
    final response = await this._send(http.Request('GET', this._endpoint('providers')));
    if (response.statusCode != 200) throw RhmApiException('Provider discovery failed (HTTP ${response.statusCode}).');
    final data = this._decode(response);
    if (data is! Map<String, dynamic> || data['providers'] is! List) throw const RhmApiException('Invalid provider response.');
    return (data['providers'] as List).map(RhmProviderInfo.fromJson).toList();
  }

  Future<RhmChatReply> sendChat(String prompt, {String? preferredProvider, String? preferredModel}) async {
    if (prompt.trim().isEmpty) {
      throw const RhmApiException('Enter a message before sending.');
    }
    final request = http.Request('POST', this._endpoint('mobile/chat'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'prompt': prompt, 'preferred_provider': preferredProvider, 'preferred_model': preferredModel});
    final response = await this._send(request);
    if (response.statusCode != 200) {
      throw RhmApiException('RHM chat failed (HTTP ${response.statusCode}).');
    }
    return RhmChatReply.fromJson(this._decode(response));
  }
}
