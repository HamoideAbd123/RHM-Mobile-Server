import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rhm_mobile/update_service.dart';

const _repository = 'https://github.com/HamoideAbd123/RHM-Mobile-Server';
const _releaseTag = 'v0.1.5';

List<int> _apkBytes() => [
  0x50, 0x4b, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00,
  0x08, 0x00, 0x44, 0x41, 0x54, 0x41, 0x2d, 0x52,
  0x48, 0x4d, 0x2d, 0x41, 0x50, 0x4b,
];

String _checksum(List<int> bytes) => sha256.convert(bytes).toString();

Map<String, dynamic> stableRelease({
  String tag = _releaseTag,
  bool draft = false,
  bool prerelease = false,
  String? htmlUrl,
  String? apkUrl,
  String? checksumUrl,
  List<Map<String, dynamic>>? assets,
}) {
  final releasePath = '$_repository/releases/tag/$tag';
  return {
    'tag_name': tag,
    'draft': draft,
    'prerelease': prerelease,
    'name': 'RHM 0.1.5',
    'body': '## What is new?\n- Independent verified updates.',
    'published_at': '2026-11-21T20:00:00Z',
    'html_url': htmlUrl ?? releasePath,
    'assets': assets ??
        [
          {
            'id': 501,
            'name': 'app-release.apk',
            'size': 2048,
            'browser_download_url': apkUrl ??
                '$_repository/releases/download/$tag/app-release.apk',
          },
          {
            'id': 502,
            'name': 'app-release.apk.sha256',
            'size': 84,
            'browser_download_url': checksumUrl ??
                '$_repository/releases/download/$tag/app-release.apk.sha256',
          },
        ],
  };
}

Map<String, dynamic> _releaseForApk(
  List<int> bytes,
  String checksumText, {
  String tag = 'v0.1.6',
}) {
  final release = stableRelease(tag: tag);
  final assets = release['assets'] as List<Map<String, dynamic>>;
  assets[0]['size'] = bytes.length;
  assets[1]['size'] = utf8.encode(checksumText).length;
  release['body'] = 'Verified RHM mobile update.';
  return release;
}

void main() {
  group('RhmUpdateService.isNewerVersion', () {
    test('detects newer stable versions with or without a v prefix', () {
      expect(RhmUpdateService.isNewerVersion('v0.1.2', '0.1.1'), isTrue);
      expect(RhmUpdateService.isNewerVersion('0.2.0', '0.1.9'), isTrue);
      expect(RhmUpdateService.isNewerVersion('0.1.7', '0.1.6'), isTrue);
    });

    test('rejects same or older versions', () {
      expect(RhmUpdateService.isNewerVersion('0.1.1', '0.1.1'), isFalse);
      expect(RhmUpdateService.isNewerVersion('0.1.0', '0.1.1'), isFalse);
    });

    test('rejects malformed versions instead of coercing them to zero', () {
      expect(RhmUpdateService.isNewerVersion('latest', '0.1.1'), isFalse);
      expect(RhmUpdateService.isNewerVersion('0.2', '0.1.1'), isFalse);
    });
  });

  group('RhmUpdateService.parseRelease', () {
    test('parses a newer stable release from the dedicated mobile repository', () {
      final update = RhmUpdateService.parseRelease(
        stableRelease(),
        currentVersion: '0.1.4',
      );

      expect(update, isNotNull);
      expect(update!.version, '0.1.5');
      expect(update.tagName, 'v0.1.5');
      expect(update.apkDownloadUri.pathSegments.last, 'app-release.apk');
      expect(
        update.checksumDownloadUri.pathSegments.last,
        'app-release.apk.sha256',
      );
      expect(update.apkSize, 2048);
      expect(update.releaseNotes, contains('Independent verified updates'));
      expect(update.publishedAt, DateTime.utc(2026, 11, 21, 20));
      expect(update.releaseUrl, contains('/releases/tag/v0.1.5'));
    });

    test('returns null when the installed version is current', () {
      expect(
        RhmUpdateService.parseRelease(
          stableRelease(tag: 'v0.1.5'),
          currentVersion: '0.1.5',
        ),
        isNull,
      );
    });

    test('rejects draft and prerelease metadata', () {
      expect(
        () => RhmUpdateService.parseRelease(
          stableRelease(draft: true),
          currentVersion: '0.1.4',
        ),
        throwsFormatException,
      );
      expect(
        () => RhmUpdateService.parseRelease(
          stableRelease(prerelease: true),
          currentVersion: '0.1.4',
        ),
        throwsFormatException,
      );
    });

    test('rejects malformed tags and missing release assets', () {
      expect(
        () => RhmUpdateService.parseRelease(
          stableRelease(tag: 'latest'),
          currentVersion: '0.1.4',
        ),
        throwsFormatException,
      );
      expect(
        () => RhmUpdateService.parseRelease(
          stableRelease(assets: const []),
          currentVersion: '0.1.4',
        ),
        throwsFormatException,
      );
    });

    test('rejects an untrusted release page and asset host', () {
      expect(
        () => RhmUpdateService.parseRelease(
          stableRelease(htmlUrl: 'https://example.com/releases/tag/v0.1.5'),
          currentVersion: '0.1.4',
        ),
        throwsFormatException,
      );
      expect(
        () => RhmUpdateService.parseRelease(
          stableRelease(
            apkUrl: 'https://example.com/app-release.apk',
          ),
          currentVersion: '0.1.4',
        ),
        throwsFormatException,
      );
    });

    test('rejects duplicate, malformed and oversized release assets', () {
      expect(
        () => RhmUpdateService.parseRelease(
          stableRelease(
            assets: [
              {
                'name': 'app-release.apk',
                'size': 2048,
                'browser_download_url':
                    '$_repository/releases/download/v0.1.5/app-release.apk',
              },
              {
                'name': 'app-release.apk',
                'size': 2048,
                'browser_download_url':
                    '$_repository/releases/download/v0.1.5/app-release.apk',
              },
              {
                'name': 'app-release.apk.sha256',
                'size': 84,
                'browser_download_url':
                    '$_repository/releases/download/v0.1.5/app-release.apk.sha256',
              },
            ],
          ),
          currentVersion: '0.1.4',
        ),
        throwsFormatException,
      );
      expect(
        () => RhmUpdateService.parseRelease(
          stableRelease(
            assets: [
              {
                'name': 'app-release.apk',
                'size': 200 * 1024 * 1024,
                'browser_download_url':
                    '$_repository/releases/download/v0.1.5/app-release.apk',
              },
              {
                'name': 'app-release.apk.sha256',
                'size': 84,
                'browser_download_url':
                    '$_repository/releases/download/v0.1.5/app-release.apk.sha256',
              },
            ],
          ),
          currentVersion: '0.1.4',
        ),
        throwsFormatException,
      );
    });
  });

  group('RhmUpdateService GitHub transport', () {
    test('checks GitHub Releases directly without a backend token', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url, RhmUpdateService.latestReleaseApiUri);
        expect(request.headers.containsKey('authorization'), isFalse);
        expect(request.headers['accept'], 'application/vnd.github+json');
        return http.Response(
          jsonEncode(stableRelease()),
          200,
          request: request,
        );
      });
      final updater = RhmUpdateService(httpClient: client);

      final update = await updater.checkForUpdate(currentVersion: '0.1.4');

      expect(update?.version, '0.1.5');
      updater.close();
    });

    test('treats a missing latest stable release as no published release', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({'message': 'Not Found'}),
            404,
            request: request,
          ));
      final updater = RhmUpdateService(httpClient: client);

      await expectLater(
        updater.checkForUpdate(currentVersion: '0.1.4'),
        throwsA(isA<RhmUpdateException>()),
      );
      updater.close();
    });
  });

  group('RhmUpdateService verified streamed downloads', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('rhm-update-test-');
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test('streams APK to disk, reports progress and verifies SHA-256', () async {
      final bytes = _apkBytes();
      final checksumText = '${_checksum(bytes)}  app-release.apk\n';
      final release = _releaseForApk(bytes, checksumText);
      final update = RhmUpdateService.parseRelease(
        release,
        currentVersion: '0.1.5',
      )!;
      final client = MockClient((request) async {
        if (request.url == update.checksumDownloadUri) {
          return http.Response(
            checksumText,
            200,
            request: request,
          );
        }
        if (request.url == update.apkDownloadUri) {
          return http.Response.bytes(
            bytes,
            200,
            request: request,
            headers: {'content-length': bytes.length.toString()},
          );
        }
        fail('Unexpected update request: ${request.url}');
      });
      final updater = RhmUpdateService(
        httpClient: client,
        downloadDirectory: directory,
      );
      final progress = <int>[];

      final file = await updater.downloadVerifiedApk(
        update,
        onProgress: (received, total) {
          expect(total, bytes.length);
          progress.add(received);
        },
      );

      expect(await file.readAsBytes(), Uint8List.fromList(bytes));
      expect(progress, isNotEmpty);
      expect(progress.last, bytes.length);
      expect(file.path, endsWith('rhm-update-0.1.6.apk'));
      updater.close();
    });

    test('rejects a checksum mismatch and deletes the corrupt partial APK', () async {
      final bytes = _apkBytes();
      final checksumText = '${List.filled(64, '0').join()}  app-release.apk\n';
      final release = _releaseForApk(bytes, checksumText);
      final update = RhmUpdateService.parseRelease(
        release,
        currentVersion: '0.1.5',
      )!;
      final client = MockClient((request) async {
        if (request.url == update.checksumDownloadUri) {
          return http.Response(checksumText, 200, request: request);
        }
        return http.Response.bytes(bytes, 200, request: request);
      });
      final updater = RhmUpdateService(
        httpClient: client,
        downloadDirectory: directory,
      );

      await expectLater(
        updater.downloadVerifiedApk(update),
        throwsA(isA<RhmUpdateException>()),
      );
      expect(
        await File('${directory.path}/rhm-update-0.1.6.apk.part').exists(),
        isFalse,
      );
      updater.close();
    });

    test('resumes a partial APK using an HTTP Range request', () async {
      final bytes = _apkBytes();
      final checksumText = '${_checksum(bytes)}  app-release.apk\n';
      final release = _releaseForApk(bytes, checksumText);
      final update = RhmUpdateService.parseRelease(
        release,
        currentVersion: '0.1.5',
      )!;
      final partial = File('${directory.path}/rhm-update-0.1.6.apk.part');
      await partial.writeAsBytes(bytes.sublist(0, 5));
      final client = MockClient((request) async {
        if (request.url == update.checksumDownloadUri) {
          return http.Response(checksumText, 200, request: request);
        }
        expect(request.headers['range'], 'bytes=5-');
        final remaining = bytes.sublist(5);
        return http.Response.bytes(
          remaining,
          206,
          request: request,
          headers: {
            'content-range': 'bytes 5-${bytes.length - 1}/${bytes.length}',
            'content-length': remaining.length.toString(),
          },
        );
      });
      final updater = RhmUpdateService(
        httpClient: client,
        downloadDirectory: directory,
      );

      final file = await updater.downloadVerifiedApk(update);

      expect(await file.readAsBytes(), Uint8List.fromList(bytes));
      updater.close();
    });

    test('restarts from zero when the server ignores a Range request', () async {
      final bytes = _apkBytes();
      final checksumText = '${_checksum(bytes)}  app-release.apk\n';
      final update = RhmUpdateService.parseRelease(
        _releaseForApk(bytes, checksumText),
        currentVersion: '0.1.5',
      )!;
      final partial = File('${directory.path}/rhm-update-0.1.6.apk.part');
      await partial.writeAsBytes([1, 2, 3]);
      final client = MockClient((request) async {
        if (request.url == update.checksumDownloadUri) {
          return http.Response(checksumText, 200, request: request);
        }
        expect(request.headers['range'], 'bytes=3-');
        return http.Response.bytes(bytes, 200, request: request);
      });
      final updater = RhmUpdateService(
        httpClient: client,
        downloadDirectory: directory,
      );

      final file = await updater.downloadVerifiedApk(update);

      expect(await file.readAsBytes(), Uint8List.fromList(bytes));
      updater.close();
    });
  });
}
