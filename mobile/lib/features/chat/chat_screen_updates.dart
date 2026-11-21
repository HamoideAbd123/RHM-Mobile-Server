part of 'chat_screen.dart';

extension _ChatScreenUpdates on _ChatScreenState {
  Future<void> _checkForUpdates({bool silent = false}) async {
    if (_checkingUpdate) return;
    _setState(() => _checkingUpdate = true);
    final updater = RhmUpdateService();
    try {
      // App releases are discovered directly from the dedicated public
      // mobile repository. This path does not use RhmApiClient or its token.
      final update = await updater.checkForUpdate();
      _lastUpdateCheckAt = DateTime.now();
      if (!mounted) return;
      if (update == null) {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تطبيق RHM محدّث إلى آخر إصدار.')),
          );
        }
        return;
      }

      final publishedDate = update.publishedAt == null
          ? 'غير متاح'
          : update.publishedAt!.toLocal().toString().split(' ').first;
      final sizeMb = (update.apkSize / (1024 * 1024)).toStringAsFixed(1);
      final notes = update.releaseNotes.trim();
      final install = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('يتوفر تحديث جديد لـ RHM'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('الإصدار: ${update.version}'),
                  Text('تاريخ النشر: $publishedDate'),
                  Text('حجم التنزيل: $sizeMb MB'),
                  const SizedBox(height: 8),
                  const Text(
                    'مصدر التحديث: مستودع تطبيق RHM على GitHub. لا يحتاج فحص الإصدار إلى تشغيل خادم المحادثات المحلي.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'ما الجديد؟',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    notes.isEmpty ? 'لم يرفق المطور سجل تغييرات لهذا الإصدار.' : notes,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'سيُتحقق من SHA-256 وحجم APK قبل فتح مثبت Android. يجب الموافقة على التثبيت من نافذة Android.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('لاحقًا'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تنزيل وتثبيت'),
            ),
          ],
        ),
      );
      if (install != true || !mounted) return;

      final progress = ValueNotifier<double?>(0);
      var downloadDialogOpen = true;
      final downloadDialog = showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تنزيل تحديث RHM'),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (context, value, _) {
              final percent = value == null
                  ? ''
                  : ' ${(value * 100).clamp(0, 100).toStringAsFixed(0)}%';
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: value),
                  const SizedBox(height: 12),
                  Text('جارٍ تنزيل الإصدار ${update.version}$percent'),
                  const SizedBox(height: 4),
                  const Text(
                    'يمكن استكمال التنزيل عند انقطاع الاتصال. لن يُفتح المثبت قبل اكتمال التحقق.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                unawaited(updater.cancelDownload());
                Navigator.pop(dialogContext);
              },
              child: const Text('إلغاء التنزيل'),
            ),
          ],
        ),
      ).whenComplete(() => downloadDialogOpen = false);

      try {
        await updater.downloadAndInstall(
          update,
          onProgress: (receivedBytes, totalBytes) {
            progress.value = totalBytes <= 0
                ? null
                : receivedBytes / totalBytes;
          },
        );
        if (mounted && downloadDialogOpen) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        await downloadDialog;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم التحقق من التحديث. أكمل التثبيت من نافذة Android.'),
            ),
          );
        }
      } on RhmUpdateCancelledException {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إلغاء تنزيل التحديث. يمكنك استكماله لاحقًا.')),
          );
        }
      } finally {
        if (downloadDialogOpen && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        progress.dispose();
      }
    } on RhmUpdateException catch (error) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } on FormatException catch (error) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر إكمال تحديث RHM. تحقق من الإنترنت ومساحة التخزين وأذونات تثبيت التطبيقات.'),
          ),
        );
      }
    } finally {
      updater.close();
      if (mounted) _setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _pollServerUpdateNotifications() async {
    final api = _api;
    if (api == null || !_connectionReady ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    await RhmServerUpdateNotifications.instance.poll(api);
    try {
      final feed = await api.getNotifications(limit: 1);
      final preferences = feed['preferences'];
      final channels = preferences is Map<String, dynamic> &&
              preferences['channels'] is Map<String, dynamic>
          ? preferences['channels'] as Map<String, dynamic>
          : const <String, dynamic>{};
      if (!mounted) return;
      _setState(() {
        _unreadNotifications = channels['in_app'] == true &&
                feed['unread_count'] is int
            ? feed['unread_count'] as int
            : 0;
      });
    } catch (_) {
      // Notification badge failures must not affect chat or background notifications.
    }
  }

  Future<void> _syncAndroidHealthToken(String token) async {
    try {
      await RhmAndroidRuntimeBridge().setHealthToken(token);
    } catch (_) {
      // The primary Flutter secure-storage credential remains authoritative.
      // Native health monitoring will show token_missing until synchronization works.
    }
  }

  Future<void> _clearAndroidHealthToken() async {
    try {
      await RhmAndroidRuntimeBridge().clearHealthToken();
    } catch (_) {
      // The Android host now checks only local server liveness via /health.
      // Flutter remains responsible for authenticated API requests.
    }
  }
}
