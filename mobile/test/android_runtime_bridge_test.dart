import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/android_runtime_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(RhmAndroidRuntimeBridge.channelName);
  final bridge = RhmAndroidRuntimeBridge();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('decodes Android monitor status', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getStatus');
      return <String, Object?>{
        'supported': true,
        'managerRunning': true,
        'autostartEnabled': false,
        'notificationPermissionGranted': true,
        'apiPortReachable': true,
        'lastApiCheckAt': 1760000000000,
        'lastError': '',
      };
    });

    final status = await bridge.getStatus();

    expect(status.supported, isTrue);
    expect(status.managerRunning, isTrue);
    expect(status.autostartEnabled, isFalse);
    expect(status.notificationPermissionGranted, isTrue);
    expect(status.apiPortReachable, isTrue);
    expect(status.lastApiCheckAt, isNotNull);
    expect(status.lastError, isNull);
  });

  test('sends the explicit boot preference to Android', () async {
    bool? receivedValue;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'setAutostartEnabled');
      receivedValue = call.arguments as bool;
      return null;
    });

    await bridge.setAutostartEnabled(true);

    expect(receivedValue, isTrue);
  });

  test('maps Android platform errors to a typed exception', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'notifications_permission_required',
        message: 'Permission required',
      );
    });

    expect(
      bridge.startManager(),
      throwsA(
        isA<RhmAndroidRuntimeException>()
            .having((error) => error.code, 'code',
                'notifications_permission_required'),
      ),
    );
  });
}
