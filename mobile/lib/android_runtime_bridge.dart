import 'package:flutter/services.dart';

class RhmAndroidRuntimeStatus {
  const RhmAndroidRuntimeStatus({
    required this.supported,
    required this.managerRunning,
    required this.autostartEnabled,
    required this.notificationPermissionGranted,
    required this.apiPortReachable,
    this.lastApiCheckAt,
    this.lastError,
  });

  final bool supported;
  final bool managerRunning;
  final bool autostartEnabled;
  final bool notificationPermissionGranted;
  final bool apiPortReachable;
  final DateTime? lastApiCheckAt;
  final String? lastError;

  factory RhmAndroidRuntimeStatus.fromMap(Map<String, dynamic> data) {
    final checkAt = data['lastApiCheckAt'];
    final error = data['lastError']?.toString() ?? '';
    return RhmAndroidRuntimeStatus(
      supported: data['supported'] == true,
      managerRunning: data['managerRunning'] == true,
      autostartEnabled: data['autostartEnabled'] == true,
      notificationPermissionGranted:
          data['notificationPermissionGranted'] == true,
      apiPortReachable: data['apiPortReachable'] == true,
      lastApiCheckAt: checkAt is int && checkAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(checkAt)
          : null,
      lastError: error.isEmpty ? null : error,
    );
  }

  factory RhmAndroidRuntimeStatus.unsupported() =>
      const RhmAndroidRuntimeStatus(
        supported: false,
        managerRunning: false,
        autostartEnabled: false,
        notificationPermissionGranted: false,
        apiPortReachable: false,
      );
}

class RhmAndroidRuntimeException implements Exception {
  const RhmAndroidRuntimeException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class RhmAndroidRuntimeBridge {
  static const String channelName = 'com.rhm.rhm_mobile/aps_runtime';
  static const MethodChannel _channel = MethodChannel(channelName);

  Future<RhmAndroidRuntimeStatus> getStatus() async {
    try {
      final data =
          await _channel.invokeMapMethod<String, dynamic>('getStatus');
      return RhmAndroidRuntimeStatus.fromMap(data ?? const {});
    } on PlatformException catch (error) {
      throw RhmAndroidRuntimeException(
        error.code,
        error.message ?? 'تعذر قراءة حالة مضيف Android.',
      );
    }
  }

  Future<void> startManager() async {
    try {
      await _channel.invokeMethod<void>('startManager');
    } on PlatformException catch (error) {
      throw RhmAndroidRuntimeException(
        error.code,
        error.message ?? 'تعذر تشغيل مراقبة RHM.',
      );
    }
  }

  Future<void> stopManager() async {
    try {
      await _channel.invokeMethod<void>('stopManager');
    } on PlatformException catch (error) {
      throw RhmAndroidRuntimeException(
        error.code,
        error.message ?? 'تعذر إيقاف مراقبة RHM.',
      );
    }
  }

  Future<void> setAutostartEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>(
        'setAutostartEnabled',
        enabled,
      );
    } on PlatformException catch (error) {
      throw RhmAndroidRuntimeException(
        error.code,
        error.message ?? 'تعذر حفظ إعداد التشغيل التلقائي.',
      );
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } on PlatformException catch (error) {
      throw RhmAndroidRuntimeException(
        error.code,
        error.message ?? 'تعذر فتح إعدادات الإشعارات.',
      );
    }
  }
}
