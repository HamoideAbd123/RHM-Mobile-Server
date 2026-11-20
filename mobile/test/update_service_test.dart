import 'package:flutter_test/flutter_test.dart';
import 'package:rhm_mobile/update_service.dart';

Map<String, dynamic> stableRelease({
  String tag = 'v0.1.5',
  bool draft = false,
  bool prerelease = false,
  List<Map<String, dynamic>>? assets,
}) =>
    {
      'tag_name': tag,
      'draft': draft,
      'prerelease': prerelease,
      'name': 'RHM 0.1.5',
      'body': '## What is new?\\n- Safer update flow.',
      'published_at': '2026-11-06T20:00:00Z',
      'html_url':
          'https://github.com/HamoideAbd123/rhm-personal-ai-core/releases/tag/v0.1.5',
      'assets': assets ??
          [
            {'id': 501, 'name': 'app-release.apk', 'size': 2048},
            {'id': 502, 'name': 'app-release.apk.sha256', 'size': 84},
          ],
    };

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
    test('parses a newer stable release and its change log', () {
      final update = RhmUpdateService.parseRelease(
        stableRelease(),
        currentVersion: '0.1.4',
      );

      expect(update, isNotNull);
      expect(update!.version, '0.1.5');
      expect(update.apkAssetId, 501);
      expect(update.checksumAssetId, 502);
      expect(update.apkSize, 2048);
      expect(update.releaseNotes, contains('Safer update flow'));
      expect(update.publishedAt, DateTime.utc(2026, 11, 6, 20));
      expect(update.releaseUrl, contains('/releases/tag/v0.1.5'));
    });

    test('returns null when the installed version is current', () {
      expect(
        RhmUpdateService.parseRelease(
          stableRelease(tag: 'v0.1.4'),
          currentVersion: '0.1.4',
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

    test('rejects oversized APK assets', () {
      expect(
        () => RhmUpdateService.parseRelease(
          stableRelease(
            assets: [
              {'id': 501, 'name': 'app-release.apk', 'size': 200 * 1024 * 1024},
              {'id': 502, 'name': 'app-release.apk.sha256', 'size': 84},
            ],
          ),
          currentVersion: '0.1.4',
        ),
        throwsFormatException,
      );
    });
  });
}
