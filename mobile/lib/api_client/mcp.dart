part of '../api_client.dart';

extension _RhmMcpApi on RhmApiClient {
  Future<List<RhmMcpServer>> listMcpServers() async {
    final response = await this._send(
      http.Request('GET', this._endpoint('mcp-client/servers')),
    );
    if (response.statusCode != 200) {
      // Error bodies are untrusted: never surface arbitrary backend text or secrets.
      throw RhmApiException(
        'تعذر تحميل خوادم MCP (HTTP ${response.statusCode}).',
      );
    }
    final data = this._decode(response);
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
    final response = await this._send(
      http.Request(
        'GET',
        this._endpoint('mcp-client/servers/${Uri.encodeComponent(serverId)}/tools'),
      ),
      timeout: const Duration(seconds: 40),
    );
    final data = this._decode(response);
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
      this._endpoint(
        'mcp-client/servers/${Uri.encodeComponent(serverId)}/tools/${Uri.encodeComponent(toolName)}',
      ),
    )
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({'arguments': arguments});
    final response = await this._send(
      request,
      timeout: const Duration(seconds: 25),
    );
    final data = this._decode(response);
    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      final detail = data is Map<String, dynamic> ? data['detail'] : null;
      throw RhmApiException(
        detail is String ? detail : 'فشل استدعاء أداة MCP (HTTP ${response.statusCode}).',
      );
    }
    return data;
  }
}
