import 'dart:io';

import 'package:flutter/services.dart';

class RhmAndroidRuntimeStatus {
  const RhmAndroidRuntimeStatus({
    required this.supported,
    required this.managerRunning,
    required this.autostartEnabled,
    required this.notificationPermissionGranted,
    required this.apiPortReachable,
    required this.apiHealthState,
    required this.backendAutostartEnabled,
    required this.termuxInstalled,
    required this.termuxPermissionGranted,
    this.lastApiCheckAt,
    this.lastError,
    this.recoveryAttempts = 0,
    this.lastRecoveryAt,
    this.lastRecoveryAction,
  });

  final bool supported;
  final bool managerRunning;
  final bool autostartEnabled;
  final bool notificationPermissionGranted;
  final bool apiPortReachable;
  final String apiHealthState;
  final bool backendAutostartEnabled;
  final bool termuxInstalled;
  final bool termuxPermissionGranted;
  final DateTime? lastApiCheckAt;
  final String? lastError;
  final int recoveryAttempts;
  final DateTime? lastRecoveryAt;
  final String? lastRecoveryAction;

  factory RhmAndroidRuntimeStatus.fromMap(Map<String, dynamic> data) {
    final checkAt = data['lastApiCheckAt'];
    final recoveryAt = data['lastRecoveryAt'];
    final error = data['lastError']?.toString() ?? '';
    final recoveryAction = data['lastRecoveryAction']?.toString() ?? '';
    return RhmAndroidRuntimeStatus(
      supported: data['supported'] == true,
      managerRunning: data['managerRunning'] == true,
      autostartEnabled: data['autostartEnabled'] == true,
      notificationPermissionGranted:
          data['notificationPermissionGranted'] == true,
      apiPortReachable: data['apiHealthy'] == true || data['apiPortReachable'] == true,
      apiHealthState: data['apiHealthState']?.toString() ?? 'unknown',
      backendAutostartEnabled: data['backendAutostartEnabled'] == true,
      termuxInstalled: data['termuxInstalled'] == true,
      termuxPermissionGranted: data['termuxPermissionGranted'] == true,
      lastApiCheckAt: checkAt is int && checkAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(checkAt)
          : null,
      lastError: error.isEmpty ? null : error,
      recoveryAttempts: data['recoveryAttempts'] is int
          ? data['recoveryAttempts'] as int
          : 0,
      lastRecoveryAt: recoveryAt is int && recoveryAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(recoveryAt)
          : null,
      lastRecoveryAction:
          recoveryAction.isEmpty ? null : recoveryAction,
    );
  }

  factory RhmAndroidRuntimeStatus.unsupported() =>
      const RhmAndroidRuntimeStatus(
        supported: false,
        managerRunning: false,
        autostartEnabled: false,
        notificationPermissionGranted: false,
        apiPortReachable: false,
        apiHealthState: 'unsupported',
        backendAutostartEnabled: false,
        termuxInstalled: false,
        termuxPermissionGranted: false,
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

  Future<void> setHealthToken(String token) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setHealthToken', token);
    } on PlatformException catch (error) {
      throw RhmAndroidRuntimeException(
        error.code,
        error.message ?? 'تعذر مزامنة رمز فحص الصحة إلى Android Keystore.',
      );
    }
  }

  Future<void> setHealthCredentials(
    String accessToken,
    String refreshToken,
  ) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(
        'setHealthCredentials',
        {
          'accessToken': accessToken,
          'refreshToken': refreshToken,
        },
      );
    } on PlatformException catch (error) {
      throw RhmAndroidRuntimeException(
        error.code,
        error.message ?? 'تعذر مزامنة اعتماد الجهاز إلى Android Keystore.',
      );
    }
  }

  Future<void> startBackend() => _invokeBackendAction('startBackend');
  Future<void> stopBackend() => _invokeBackendAction('stopBackend');
  Future<void> restartBackend() => _invokeBackendAction('restartBackend');

  Future<void> _invokeBackendAction(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (error) {
      throw RhmAndroidRuntimeException(
        error.code,
        error.message ?? 'تعذر إرسال أمر إدارة Backend إلى Termux.',
      );
    }
  }

  Future<void> setBackendAutostartEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setBackendAutostartEnabled', enabled);
    } on PlatformException catch (error) {
      throw RhmAndroidRuntimeException(
        error.code,
        error.message ?? 'تعذر حفظ تشغيل Backend بعد الإقلاع.',
      );
    }
  }

  Future<void> openTermuxSettings() async {
    try {
      await _channel.invokeMethod<void>('openTermuxSettings');
    } on PlatformException catch (error) {
      throw RhmAndroidRuntimeException(
        error.code,
        error.message ?? 'تعذر فتح إعدادات Termux.',
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
