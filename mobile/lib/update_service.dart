import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class RhmUpdate {
  const RhmUpdate({
    required this.version,
    required this.tagName,
    required this.apkDownloadUri,
    required this.checksumDownloadUri,
    required this.apkSize,
    required this.checksumSize,
    required this.releaseNotes,
    required this.releaseUrl,
    required this.publishedAt,
  });

  final String version;
  final String tagName;
  final Uri apkDownloadUri;
  final Uri checksumDownloadUri;
  final int apkSize;
  final int checksumSize;
  final String releaseNotes;
  final String releaseUrl;
  final DateTime? publishedAt;
}

class RhmUpdateException implements Exception {
  const RhmUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RhmUpdateCancelledException implements Exception {
  const RhmUpdateCancelledException();

  @override
  String toString() => 'تم إلغاء تنزيل التحديث.';
}

typedef RhmUpdateProgressCallback = void Function(
  int receivedBytes,
  int totalBytes,
);

class RhmUpdateService {
  static const int maxApkBytes = 100 * 1024 * 1024;
  static const int maxChecksumBytes = 1024;
  static const String repositoryOwner = 'HamoideAbd123';
  static const String repositoryName = 'RHM-Mobile-Server';
  static final Uri latestReleaseApiUri = Uri.https(
    'api.github.com',
    '/repos/$repositoryOwner/$repositoryName/releases/latest',
  );

  RhmUpdateService({
    http.Client? httpClient,
    Directory? downloadDirectory,
  })  : _http = httpClient ?? http.Client(),
        _downloadDirectory = downloadDirectory;

  final http.Client _http;
  final Directory? _downloadDirectory;
  StreamSubscription<List<int>>? _activeDownloadSubscription;
  IOSink? _activeDownloadSink;
  Completer<void>? _activeDownloadCompleter;
  bool _cancelRequested = false;
  bool _closed = false;

  static bool isNewerVersion(String latest, String current) {
    List<int>? parts(String value) {
      final normalized = value.replaceFirst(RegExp(r'^[vV]'), '');
      if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(normalized)) {
        return null;
      }
      return normalized.split('.').map(int.parse).toList();
    }

    final left = parts(latest);
    final right = parts(current);
    if (left == null || right == null) return false;
    for (var i = 0; i < 3; i++) {
      if (left[i] != right[i]) return left[i] > right[i];
    }
    return false;
  }

  static bool _isTrustedReleasePage(Uri uri, String tag) {
    return uri.scheme == 'https' &&
        uri.host == 'github.com' &&
        uri.userInfo.isEmpty &&
        uri.port == 443 &&
        uri.pathSegments.length == 5 &&
        uri.pathSegments[0] == repositoryOwner &&
        uri.pathSegments[1] == repositoryName &&
        uri.pathSegments[2] == 'releases' &&
        uri.pathSegments[3] == 'tag' &&
        uri.pathSegments[4] == tag &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  static bool _isTrustedAssetUri(Uri uri, String tag, String fileName) {
    return uri.scheme == 'https' &&
        uri.host == 'github.com' &&
        uri.userInfo.isEmpty &&
        uri.port == 443 &&
        uri.pathSegments.length == 6 &&
        uri.pathSegments[0] == repositoryOwner &&
        uri.pathSegments[1] == repositoryName &&
        uri.pathSegments[2] == 'releases' &&
        uri.pathSegments[3] == 'download' &&
        uri.pathSegments[4] == tag &&
        uri.pathSegments[5] == fileName &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  static bool _isTrustedAssetResponse(Uri uri) {
    const allowedHosts = {
      'github.com',
      'release-assets.githubusercontent.com',
      'objects.githubusercontent.com',
      'github-releases.githubusercontent.com',
    };
    return uri.scheme == 'https' &&
        allowedHosts.contains(uri.host) &&
        uri.userInfo.isEmpty;
  }

  static RhmUpdate? parseRelease(
    Object? value, {
    required String currentVersion,
  }) {
    if (value is! Map<String, dynamic> ||
        value['draft'] == true ||
        value['prerelease'] == true ||
        value['tag_name'] is! String ||
        value['assets'] is! List) {
      throw const FormatException('بيانات إصدار RHM غير صالحة.');
    }

    final tag = value['tag_name'] as String;
    if (!RegExp(r'^v?\d+\.\d+\.\d+$').hasMatch(tag)) {
      throw const FormatException('صيغة رقم إصدار RHM غير صالحة.');
    }
    final version = tag.replaceFirst(RegExp(r'^[vV]'), '');
    if (!isNewerVersion(version, currentVersion)) return null;

    final rawReleaseUrl = value['html_url'];
    final releaseUri = rawReleaseUrl is String
        ? Uri.tryParse(rawReleaseUrl)
        : null;
    if (releaseUri == null || !_isTrustedReleasePage(releaseUri, tag)) {
      throw const FormatException('مصدر إصدار RHM غير موثوق.');
    }

    Map<String, dynamic>? findAsset(String name) {
      final matches = (value['assets'] as List)
          .whereType<Map>()
          .where((asset) => asset['name'] == name)
          .toList();
      if (matches.length != 1) return null;
      return Map<String, dynamic>.from(matches.single);
    }

    final apk = findAsset('app-release.apk');
    final checksum = findAsset('app-release.apk.sha256');
    final apkSize = apk?['size'];
    final checksumSize = checksum?['size'];
    final apkUriValue = apk?['browser_download_url'];
    final checksumUriValue = checksum?['browser_download_url'];
    final apkUri = apkUriValue is String ? Uri.tryParse(apkUriValue) : null;
    final checksumUri = checksumUriValue is String
        ? Uri.tryParse(checksumUriValue)
        : null;

    if (apk == null ||
        checksum == null ||
        apkSize is! int ||
        apkSize <= 0 ||
        apkSize > maxApkBytes ||
        checksumSize is! int ||
        checksumSize <= 0 ||
        checksumSize > maxChecksumBytes ||
        apkUri == null ||
        checksumUri == null ||
        !_isTrustedAssetUri(apkUri, tag, 'app-release.apk') ||
        !_isTrustedAssetUri(checksumUri, tag, 'app-release.apk.sha256')) {
      throw const FormatException('الإصدار لا يحتوي على ملفات تحديث صالحة وآمنة.');
    }

    final rawPublishedAt = value['published_at'];
    final rawNotes = value['body'];
    final releaseNotes = rawNotes is String
        ? rawNotes.substring(0, rawNotes.length > 20000 ? 20000 : rawNotes.length)
        : '';

    return RhmUpdate(
      version: version,
      tagName: tag,
      apkDownloadUri: apkUri,
      checksumDownloadUri: checksumUri,
      apkSize: apkSize,
      checksumSize: checksumSize,
      releaseNotes: releaseNotes,
      releaseUrl: releaseUri.toString(),
      publishedAt: rawPublishedAt is String
          ? DateTime.tryParse(rawPublishedAt)?.toUtc()
          : null,
    );
  }

  Future<RhmUpdate?> checkForUpdate({String? currentVersion}) async {
    if (_closed) throw const RhmUpdateException('خدمة التحديث مغلقة.');
    final installedVersion = currentVersion ??
        (await PackageInfo.fromPlatform()).version;
    final request = http.Request('GET', latestReleaseApiUri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers['accept'] = 'application/vnd.github+json'
      ..headers['x-github-api-version'] = '2022-11-28'
      ..headers['user-agent'] = 'RHM-Android-Updater';
    final response = await _send(request, timeout: const Duration(seconds: 20));
    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        throw const RhmUpdateException('لا يوجد إصدار مستقر منشور لتطبيق RHM حتى الآن.');
      }
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw const RhmUpdateException('وصل فحص GitHub إلى حد الطلبات المؤقت. سيُعاد الفحص لاحقًا.');
      }
      throw RhmUpdateException('تعذر جلب إصدار RHM من GitHub (HTTP ${response.statusCode}).');
    }

    final finalUri = response.request?.url ?? latestReleaseApiUri;
    if (finalUri != latestReleaseApiUri) {
      throw const RhmUpdateException('تم رفض تحويل غير متوقع أثناء فحص التحديث.');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const RhmUpdateException('استجابة GitHub الخاصة بالتحديث غير صالحة.');
    }
    try {
      return parseRelease(decoded, currentVersion: installedVersion);
    } on FormatException catch (error) {
      throw RhmUpdateException(error.message);
    }
  }

  Future<http.Response> _send(
    http.Request request, {
    required Duration timeout,
  }) async {
    try {
      final streamed = await _http.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const RhmUpdateException('انتهت مهلة الاتصال بخدمة تحديث RHM.');
    } on RhmUpdateException {
      rethrow;
    } on http.ClientException {
      throw const RhmUpdateException('تعذر الاتصال بـ GitHub. تحقق من الإنترنت ثم أعد المحاولة.');
    } on SocketException {
      throw const RhmUpdateException('لا يوجد اتصال إنترنت متاح لفحص تحديث RHM.');
    }
  }

  Future<String> _fetchExpectedChecksum(RhmUpdate update) async {
    final request = http.Request('GET', update.checksumDownloadUri)
      ..followRedirects = true
      ..maxRedirects = 5
      ..headers['accept'] = 'text/plain'
      ..headers['user-agent'] = 'RHM-Android-Updater';
    final response = await _send(request, timeout: const Duration(seconds: 30));
    final finalUri = response.request?.url ?? update.checksumDownloadUri;
    if (!_isTrustedAssetResponse(finalUri) ||
        response.statusCode != 200 ||
        response.bodyBytes.isEmpty ||
        response.bodyBytes.length > maxChecksumBytes ||
        response.bodyBytes.length != update.checksumSize) {
      throw const RhmUpdateException('تعذر تحميل ملف التحقق SHA-256 أو أن حجمه غير صحيح.');
    }

    final text = utf8.decode(response.bodyBytes, allowMalformed: false).trim();
    final lines = text.split(RegExp(r'[\r\n]+'));
    if (lines.length != 1) {
      throw const FormatException('ملف SHA-256 المنشور غير صالح.');
    }
    final fields = lines.single.trim().split(RegExp(r'\s+'));
    if (fields.isEmpty ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(fields.first) ||
        fields.length > 2 ||
        (fields.length == 2 &&
            fields[1] != 'app-release.apk' &&
            fields[1] != '*app-release.apk')) {
      throw const FormatException('ملف SHA-256 المنشور غير صالح.');
    }
    return fields.first.toLowerCase();
  }

  Future<File> downloadVerifiedApk(
    RhmUpdate update, {
    RhmUpdateProgressCallback? onProgress,
  }) async {
    if (_closed) throw const RhmUpdateException('خدمة التحديث مغلقة.');
    _cancelRequested = false;
    final expectedDigest = await _fetchExpectedChecksum(update);
    final directory = _downloadDirectory ?? await getTemporaryDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final apk = File('${directory.path}/rhm-update-${update.version}.apk');
    final partial = File('${apk.path}.part');
    var offset = await partial.exists() ? await partial.length() : 0;
    if (offset > update.apkSize) {
      await partial.delete();
      offset = 0;
    }

    if (offset < update.apkSize) {
      final request = http.Request('GET', update.apkDownloadUri)
        ..followRedirects = true
        ..maxRedirects = 5
        ..headers['accept'] = 'application/vnd.android.package-archive'
        ..headers['user-agent'] = 'RHM-Android-Updater';
      if (offset > 0) {
        request.headers['range'] = 'bytes=$offset-';
      }

      http.StreamedResponse response;
      try {
        response = await _http.send(request).timeout(const Duration(minutes: 5));
      } on TimeoutException {
        throw const RhmUpdateException('انتهت مهلة تنزيل تحديث RHM. يمكنك إعادة المحاولة واستكمال التنزيل.');
      } on http.ClientException {
        throw const RhmUpdateException('انقطع الاتصال أثناء تنزيل تحديث RHM. يمكنك إعادة المحاولة.');
      } on SocketException {
        throw const RhmUpdateException('انقطع اتصال الإنترنت أثناء تنزيل تحديث RHM.');
      }

      final finalUri = response.request?.url ?? update.apkDownloadUri;
      if (!_isTrustedAssetResponse(finalUri)) {
        await response.stream.drain<void>();
        throw const RhmUpdateException('تم رفض وجهة تنزيل APK غير موثوقة.');
      }

      var append = false;
      if (response.statusCode == 206) {
        final contentRange = response.headers['content-range'];
        final match = contentRange == null
            ? null
            : RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(contentRange);
        if (match == null ||
            int.parse(match.group(1)!) != offset ||
            int.parse(match.group(3)!) != update.apkSize) {
          await response.stream.drain<void>();
          throw const RhmUpdateException('استجابة استكمال التنزيل غير متوافقة مع حجم الإصدار.');
        }
        append = offset > 0;
      } else if (response.statusCode == 200) {
        offset = 0;
      } else {
        await response.stream.drain<void>();
        throw RhmUpdateException('فشل تنزيل APK (HTTP ${response.statusCode}).');
      }

      final expectedRemaining = update.apkSize - offset;
      if (response.contentLength != null &&
          response.contentLength! >= 0 &&
          response.contentLength != expectedRemaining) {
        await response.stream.drain<void>();
        throw const RhmUpdateException('حجم استجابة APK لا يطابق بيانات الإصدار.');
      }

      await _streamApkToFile(
        response,
        partial,
        append: append,
        initialBytes: offset,
        totalBytes: update.apkSize,
        onProgress: onProgress,
      );
    }

    final actualSize = await partial.length();
    if (actualSize != update.apkSize) {
      throw const RhmUpdateException('اكتمل الاتصال لكن حجم APK غير مكتمل. أعد المحاولة لاستكمال التنزيل.');
    }

    final header = await partial.openRead(0, 4).first;
    if (header.length < 4 ||
        header[0] != 0x50 ||
        header[1] != 0x4b ||
        header[2] != 0x03 ||
        header[3] != 0x04) {
      await partial.delete();
      throw const RhmUpdateException('الملف الذي تم تنزيله ليس حزمة APK صالحة.');
    }

    final actualDigest = (await sha256.bind(partial.openRead()).first).toString();
    if (actualDigest != expectedDigest) {
      await partial.delete();
      throw const RhmUpdateException('فشل التحقق من سلامة ملف APK (SHA-256). حُذف الملف غير المطابق.');
    }

    if (await apk.exists()) await apk.delete();
    return partial.rename(apk.path);
  }

  Future<void> _streamApkToFile(
    http.StreamedResponse response,
    File partial, {
    required bool append,
    required int initialBytes,
    required int totalBytes,
    RhmUpdateProgressCallback? onProgress,
  }) async {
    final sink = partial.openWrite(mode: append ? FileMode.append : FileMode.write);
    final completer = Completer<void>();
    late final StreamSubscription<List<int>> subscription;
    var received = initialBytes;
    _activeDownloadSink = sink;
    _activeDownloadCompleter = completer;

    subscription = response.stream.listen(
      (chunk) {
        if (_cancelRequested) {
          unawaited(subscription.cancel());
          if (!completer.isCompleted) {
            completer.completeError(const RhmUpdateCancelledException());
          }
          return;
        }
        if (received + chunk.length > totalBytes) {
          unawaited(subscription.cancel());
          if (!completer.isCompleted) {
            completer.completeError(
              const RhmUpdateException('تجاوز تنزيل APK الحجم المعلن.'),
            );
          }
          return;
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, totalBytes);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );
    _activeDownloadSubscription = subscription;

    try {
      await completer.future;
      await sink.flush();
    } finally {
      await subscription.cancel();
      await sink.close();
      _activeDownloadSubscription = null;
      _activeDownloadSink = null;
      _activeDownloadCompleter = null;
    }
  }

  Future<void> cancelDownload() async {
    _cancelRequested = true;
    final subscription = _activeDownloadSubscription;
    final completer = _activeDownloadCompleter;
    if (subscription != null) await subscription.cancel();
    final sink = _activeDownloadSink;
    if (sink != null) {
      await sink.flush();
      await sink.close();
    }
    if (completer != null && !completer.isCompleted) {
      completer.completeError(const RhmUpdateCancelledException());
    }
    _activeDownloadSubscription = null;
    _activeDownloadSink = null;
    _activeDownloadCompleter = null;
  }

  Future<void> downloadAndInstall(
    RhmUpdate update, {
    RhmUpdateProgressCallback? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('تحديث APK متاح على Android فقط.');
    }
    final apk = await downloadVerifiedApk(update, onProgress: onProgress);
    final result = await OpenFilex.open(apk.path);
    if (result.type != ResultType.done) {
      throw RhmUpdateException(
        'تعذر فتح مثبت Android: ${result.message}. بقي الملف المحقق في مساحة التطبيق.',
      );
    }
  }

  void close() {
    _closed = true;
    _http.close();
  }
}

class RhmAppUpdateNotifications {
  RhmAppUpdateNotifications._();

  static final RhmAppUpdateNotifications instance =
      RhmAppUpdateNotifications._();

  static const _notifiedVersionKey = 'rhm.app_update.notified_version';
  static const _channelId = 'rhm_app_updates';
  static const _notificationId = 0x52484d;
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

  Future<void> initialize({bool requestPermission = false}) async {
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
          'RHM App Updates',
          description: 'Notifications about new RHM Android app releases.',
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

  Future<bool> notifyIfNew(RhmUpdate update) async {
    final lastNotified = await _storage.read(key: _notifiedVersionKey);
    if (lastNotified == update.version) return false;
    await initialize();
    await _plugin.show(
      _notificationId,
      'يتوفر تحديث جديد لتطبيق RHM',
      'الإصدار ${update.version} متاح. افتح RHM لمراجعة سجل التغييرات والتثبيت.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'RHM App Updates',
          channelDescription: 'Notifications about new RHM Android app releases.',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.status,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: update.releaseUrl,
    );
    await _storage.write(key: _notifiedVersionKey, value: update.version);
    return true;
  }
}
