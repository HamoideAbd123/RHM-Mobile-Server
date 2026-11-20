import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

class RhmUpdate {
  const RhmUpdate({
    required this.version,
    required this.apkAssetId,
    required this.checksumAssetId,
    required this.apkSize,
    required this.releaseNotes,
    required this.releaseUrl,
    required this.publishedAt,
  });

  final String version;
  final int apkAssetId;
  final int checksumAssetId;
  final int apkSize;
  final String releaseNotes;
  final String? releaseUrl;
  final DateTime? publishedAt;
}

class RhmUpdateService {
  static const int maxApkBytes = 100 * 1024 * 1024;

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

    int? assetId(String name) {
      for (final item in value['assets'] as List) {
        if (item is! Map<String, dynamic> || item['name'] != name) continue;
        final id = item['id'];
        final size = item['size'];
        if (id is int && id > 0 && size is int && size >= 0) return id;
      }
      return null;
    }

    int? assetSize(String name) {
      for (final item in value['assets'] as List) {
        if (item is! Map<String, dynamic> || item['name'] != name) continue;
        final size = item['size'];
        if (size is int && size >= 0) return size;
      }
      return null;
    }

    final apkId = assetId('app-release.apk');
    final checksumId = assetId('app-release.apk.sha256');
    final apkSize = assetSize('app-release.apk');
    final checksumSize = assetSize('app-release.apk.sha256');
    if (apkId == null ||
        checksumId == null ||
        apkSize == null ||
        checksumSize == null ||
        apkSize <= 0 ||
        apkSize > maxApkBytes ||
        checksumSize <= 0 ||
        checksumSize > 1024) {
      throw const FormatException('الإصدار لا يحتوي على ملفات تحديث صالحة.');
    }

    final rawReleaseUrl = value['html_url'];
    final releaseUrl = rawReleaseUrl is String &&
            rawReleaseUrl.startsWith(
              'https://github.com/HamoideAbd123/rhm-personal-ai-core/releases/tag/',
            )
        ? rawReleaseUrl
        : null;
    final rawPublishedAt = value['published_at'];
    return RhmUpdate(
      version: version,
      apkAssetId: apkId,
      checksumAssetId: checksumId,
      apkSize: apkSize,
      releaseNotes: value['body'] is String ? value['body'] as String : '',
      releaseUrl: releaseUrl,
      publishedAt: rawPublishedAt is String
          ? DateTime.tryParse(rawPublishedAt)?.toUtc()
          : null,
    );
  }

  Future<RhmUpdate?> checkForUpdate(RhmApiClient api) async {
    if (!Platform.isAndroid) return null;
    final package = await PackageInfo.fromPlatform();
    final release = await api.fetchLatestUpdate();
    final update = parseRelease(release, currentVersion: package.version);
    if (update != null) {
      try {
        await api.reportAppUpdateAvailable(update.version);
      } on RhmApiException {
        // App update discovery must remain functional if event reporting is unavailable.
      }
    }
    return update;
  }

  Future<void> downloadAndInstall(
    RhmUpdate update,
    RhmApiClient api,
  ) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('تحديث APK متاح على Android فقط.');
    }

    final apkBytes = await api.downloadUpdateAsset(update.apkAssetId);
    final checksumBytes = await api.downloadUpdateAsset(update.checksumAssetId);
    if (apkBytes.isEmpty ||
        apkBytes.length != update.apkSize ||
        apkBytes.length > maxApkBytes ||
        checksumBytes.isEmpty ||
        checksumBytes.length > 1024) {
      throw const FormatException('حجم ملف APK غير صالح.');
    }

    final checksumText = utf8.decode(checksumBytes, allowMalformed: false).trim();
    final checksumMatch = RegExp(r'^([a-fA-F0-9]{64})(?:\s+.*)?$')
        .firstMatch(checksumText);
    if (checksumMatch == null) {
      throw const FormatException('ملف SHA-256 المنشور غير صالح.');
    }
    final expected = checksumMatch.group(1)!.toLowerCase();
    final actual = sha256.convert(apkBytes).toString();
    if (expected != actual) {
      throw const FormatException('فشل التحقق من سلامة ملف التحديث (SHA-256).');
    }

    final directory = await getTemporaryDirectory();
    final apk = File('${directory.path}/rhm-update-${update.version}.apk');
    await apk.writeAsBytes(apkBytes, flush: true);
    final result = await OpenFilex.open(apk.path);
    if (result.type != ResultType.done) {
      throw FileSystemException(
        'تعذر فتح مثبت Android: ${result.message}',
        apk.path,
      );
    }
  }
}
