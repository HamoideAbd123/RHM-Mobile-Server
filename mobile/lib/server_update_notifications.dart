import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';

import 'api_client.dart';

const _backgroundTaskName = 'rhmServerNotificationPoll';
const _backgroundTaskUniqueName = 'rhm-server-notification-poll';

int? parseRhmClockMinutes(Object? value) {
  if (value is! String || !RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) {
    return null;
  }
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour > 23 || minute > 59) {
    return null;
  }
  return hour * 60 + minute;
}

bool isRhmQuietHoursActive(Object? value, {required DateTime now}) {
  if (value is! Map<String, dynamic> || value['enabled'] != true) {
    return false;
  }
  final start = parseRhmClockMinutes(value['start']);
  final end = parseRhmClockMinutes(value['end']);
  if (start == null || end == null || start == end) return false;
  final current = now.hour * 60 + now.minute;
  if (start < end) return current >= start && current < end;
  return current >= start || current < end;
}

@pragma('vm:entry-point')
void rhmServerUpdateCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _backgroundTaskName) return true;
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(
          resetOnError: false,
          migrateOnAlgorithmChange: true,
          migrateWithBackup: true,
        ),
      );
      final serverUrl = await storage.read(key: 'rhm_server_url');
      final token = await storage.read(key: 'rhm_mobile_token');
      if (serverUrl == null ||
          token == null ||
          serverUrl.trim().isEmpty ||
          token.trim().isEmpty) {
        return true;
      }
      final api = RhmApiClient(serverUrl: serverUrl, token: token);
      try {
        await RhmServerUpdateNotifications.instance.poll(api);
      } finally {
        api.close();
      }
      return true;
    } catch (_) {
      return false;
    }
  });
}

Future<void> initializeRhmBackgroundNotifications() async {
  await Workmanager().initialize(rhmServerUpdateCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _backgroundTaskUniqueName,
    _backgroundTaskName,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

class RhmServerUpdateNotifications {
  RhmServerUpdateNotifications._();

  static final RhmServerUpdateNotifications instance =
      RhmServerUpdateNotifications._();

  static const _seenEventIdsKey = 'rhm.notifications.seen_event_ids';
  static const _primedKey = 'rhm.notifications.cursor_primed';
  static const _channelId = 'rhm_notifications';
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      migrateOnAlgorithmChange: true,
      migrateWithBackup: true,
    ),
  );
  bool _initialized = false;
  bool _polling = false;

  Future<void> initialize({bool requestPermission = true}) async {
    if (!_initialized) {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          'RHM Notifications',
          description: 'Updates, chat, workspace, system and security activity.',
          importance: Importance.high,
        ),
      );
      _initialized = true;
    }
    if (requestPermission) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    }
  }

  Future<void> prime(RhmApiClient api) async {
    try {
      final isPrimed = await _storage.read(key: _primedKey) == 'true';
      if (isPrimed) {
        await poll(api);
        return;
      }
      final data = await api.getNotifications(limit: 100);
      final items = data['items'];
      if (items is List) {
        await _saveSeenIds(items
            .whereType<Map<String, dynamic>>()
            .map((item) => item['id'])
            .whereType<String>());
        await _storage.write(key: _primedKey, value: 'true');
      }
    } catch (_) {
      // Notification discovery must never interrupt connection recovery.
    }
  }

  Future<void> poll(RhmApiClient api) async {
    if (_polling) return;
    _polling = true;
    try {
      await initialize(requestPermission: false);
      final data = await api.getNotifications(limit: 100);
      final rawPreferences = data['preferences'];
      final preferences = rawPreferences is Map<String, dynamic>
          ? rawPreferences
          : const <String, dynamic>{};
      final channels = preferences['channels'] is Map<String, dynamic>
          ? preferences['channels'] as Map<String, dynamic>
          : const <String, dynamic>{};
      if (preferences['enabled'] != true || channels['android'] != true) {
        return;
      }

      final items = data['items'];
      if (items is! List || items.isEmpty) return;
      final isPrimed = await _storage.read(key: _primedKey) == 'true';
      if (!isPrimed) {
        await _saveSeenIds(items
            .whereType<Map<String, dynamic>>()
            .map((item) => item['id'])
            .whereType<String>());
        await _storage.write(key: _primedKey, value: 'true');
        return;
      }
      final seen = await _readSeenIds();

      final fresh = items
          .whereType<Map<String, dynamic>>()
          .where((item) {
            final id = item['id'];
            final category = item['category'];
            return id is String &&
                !seen.contains(id) &&
                item['read'] != true &&
                item['should_notify'] == true &&
                category is String;
          })
          .toList()
          .reversed
          .toList();

      for (var i = 0; i < fresh.length; i++) {
        if (_isQuietNow(preferences['quiet_hours'])) continue;
        await _show(fresh[i], i);
      }
      await _saveSeenIds(items
          .whereType<Map<String, dynamic>>()
          .map((item) => item['id'])
          .whereType<String>());
    } catch (_) {
      // Temporary network or notification errors must not break RHM.
    } finally {
      _polling = false;
    }
  }

  Future<Set<String>> _readSeenIds() async {
    final raw = await _storage.read(key: _seenEventIdsKey);
    if (raw == null) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toSet();
    } on FormatException {
      // Reset only the notification cursor, never credentials.
    }
    return <String>{};
  }

  Future<void> _saveSeenIds(Iterable<String> ids) async {
    final current = await _readSeenIds();
    current.addAll(ids);
    final bounded = current.toList();
    if (bounded.length > 1000) {
      bounded.removeRange(0, bounded.length - 1000);
    }
    await _storage.write(key: _seenEventIdsKey, value: jsonEncode(bounded));
  }

  bool _isQuietNow(Object? value) =>
      isRhmQuietHoursActive(value, now: DateTime.now());
  Future<void> _show(Map<String, dynamic> item, int offset) async {
    final id = item['id']?.toString() ?? '';
    final title = item['title'] is String
        ? item['title'] as String
        : 'إشعار من RHM';
    final message = item['message'] is String
        ? item['message'] as String
        : 'حدث جديد في منظومة RHM.';
    await _plugin.show(
      (id.hashCode & 0x7fffffff) + offset,
      title,
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'RHM Notifications',
          channelDescription: 'Updates, chat, workspace, system and security activity.',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'RHM notification',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: item['id']?.toString(),
    );
  }
}
