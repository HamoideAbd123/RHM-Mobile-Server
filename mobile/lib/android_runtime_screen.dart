import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'android_runtime_bridge.dart';

class RhmAndroidRuntimeScreen extends StatefulWidget {
  const RhmAndroidRuntimeScreen({super.key});

  @override
  State<RhmAndroidRuntimeScreen> createState() =>
      _RhmAndroidRuntimeScreenState();
}

class _RhmAndroidRuntimeScreenState extends State<RhmAndroidRuntimeScreen>
    with WidgetsBindingObserver {
  final RhmAndroidRuntimeBridge _bridge = RhmAndroidRuntimeBridge();
  RhmAndroidRuntimeStatus _status =
      RhmAndroidRuntimeStatus.unsupported();
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      if (mounted) {
        setState(() {
          _status = RhmAndroidRuntimeStatus.unsupported();
          _loading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _loading = true);
    try {
      final status = await _bridge.getStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _error = status.lastError;
      });
    } on RhmAndroidRuntimeException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _refresh();
    } on RhmAndroidRuntimeException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      if (error.code == 'notifications_permission_required') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('افتح إعدادات الإشعارات وامنح RHM الإذن، ثم أعد المحاولة.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر تنفيذ الإجراء على خدمة Android.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAutostart(bool enabled) async {
    await _run(() => _bridge.setAutostartEnabled(enabled));
  }

  Future<void> _setBackendAutostart(bool enabled) async {
    await _run(() => _bridge.setBackendAutostartEnabled(enabled));
  }

  Future<void> _runBackend(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_status.managerRunning) await _bridge.startManager();
      await action();
      await Future<void>.delayed(const Duration(seconds: 2));
      await _refresh();
    } on RhmAndroidRuntimeException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      if (error.code == 'termux_permission_required' ||
          error.code == 'termux_not_ready') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تحقق من تثبيت Termux ومنح إذن RUN_COMMAND وإعداد allow-external-apps.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إرسال أمر Backend إلى Termux.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _healthLabel => switch (_status.apiHealthState) {
        'healthy' => 'FastAPI سليم والمصادقة ناجحة',
        'unauthorized' => 'FastAPI رفض رمز الوصول المحفوظ',
        'token_missing' => 'رمز فحص الصحة غير مُزامن بعد',
        'invalid_response' => 'استجابة فحص FastAPI غير صالحة',
        'unsupported' => 'غير مدعوم على هذا الجهاز',
        _ => 'FastAPI غير متاح أو لم يؤكد الجاهزية',
      };

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return Scaffold(
        appBar: AppBar(title: const Text('مضيف Android المحلي')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('هذه الصفحة متاحة في نسخة Android فقط.'),
          ),
        ),
      );
    }

    final running = _status.managerRunning;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مضيف Android المحلي'),
        actions: [
          IconButton(
            tooltip: 'تحديث الحالة',
            onPressed: _loading || _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && !_status.supported
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Card(
                    child: ListTile(
                      leading: Icon(
                        running ? Icons.monitor_heart : Icons.pause_circle_outline,
                        color: running ? Colors.green : Colors.grey,
                        size: 30,
                      ),
                      title: Text(running ? 'مراقبة Android تعمل' : 'مراقبة Android متوقفة'),
                      subtitle: Text(
                        '$_healthLabel\\nمحاولات استعادة الخادم: ${_status.recoveryAttempts}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: SwitchListTile(
                      value: _status.autostartEnabled,
                      onChanged: _busy ? null : _setAutostart,
                      title: const Text('تشغيل المراقبة بعد إقلاع الهاتف'),
                      subtitle: const Text(
                        'يشغّل خدمة المراقبة بعد إقلاع الهاتف. عند تفعيل تشغيل Backend أدناه، تحاول الخدمة تشغيل Python عبر Termux أيضاً.',
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('خادم Python / FastAPI عبر Termux',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(_status.termuxInstalled
                              ? 'تم العثور على خدمة Termux RUN_COMMAND.'
                              : 'لم يتم العثور على Termux أو خدمة RUN_COMMAND.'),
                          Text(_status.termuxPermissionGranted
                              ? 'إذن RHM لتشغيل أوامر Termux ممنوح.'
                              : 'إذن RUN_COMMAND غير ممنوح لـ RHM.'),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _status.backendAutostartEnabled,
                            onChanged: _busy || !_status.termuxInstalled ||
                                    !_status.termuxPermissionGranted
                                ? null
                                : _setBackendAutostart,
                            title: const Text('تشغيل Backend بعد إقلاع الهاتف'),
                            subtitle: const Text(
                              'يتطلب إعداد Termux وتثبيت سكربت التحكم. هذا الخيار يفعّل بدء خدمة المراقبة أيضاً.',
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _busy || !_status.termuxInstalled ||
                                          !_status.termuxPermissionGranted
                                      ? null
                                      : () => _runBackend(_bridge.startBackend),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('تشغيل Backend'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _busy || !_status.termuxInstalled ||
                                          !_status.termuxPermissionGranted
                                      ? null
                                      : () => _runBackend(_bridge.restartBackend),
                                  icon: const Icon(Icons.restart_alt),
                                  label: const Text('إعادة التشغيل'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _busy || !_status.termuxInstalled ||
                                    !_status.termuxPermissionGranted
                                ? null
                                : () => _runBackend(_bridge.stopBackend),
                            icon: const Icon(Icons.stop),
                            label: const Text('إيقاف Backend'),
                          ),
                          TextButton.icon(
                            onPressed: _busy ? null : () => _run(_bridge.openTermuxSettings),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('فتح إعدادات Termux'),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'يلزم تثبيت سكربت rhm-runtime-control داخل مجلد Termux الخاص، وضبط allow-external-apps=true يدوياً. RHM لا يغيّر إعدادات Termux ولا يقبل أوامر shell حرة؛ يرسل فقط start/stop/restart.',
                            style: TextStyle(fontSize: 12, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!_status.notificationPermissionGranted) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'إذن الإشعارات مطلوب',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'تحتاج خدمة Android إلى إشعار ظاهر حتى تعرض حالة المراقبة بوضوح.',
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _run(_bridge.openNotificationSettings),
                              icon: const Icon(Icons.notifications_active_outlined),
                              label: const Text('فتح إعدادات الإشعارات'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy || running || !_status.notificationPermissionGranted
                              ? null
                              : () => _run(_bridge.startManager),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('تشغيل المراقبة'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy || !running
                              ? null
                              : () => _run(_bridge.stopManager),
                          icon: const Icon(Icons.stop),
                          label: const Text('إيقاف المراقبة'),
                        ),
                      ),
                    ],
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حدود المرحلة الحالية',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'الخدمة تفحص GET /mobile/health كل 20 ثانية باستخدام Bearer token محفوظ في Android Keystore. هذا لا يثبت جاهزية PostgreSQL أو مزوّد النماذج.',
                          ),
                          SizedBox(height: 8),
                          Text(
                            'تشغيل وإيقاف Python يمران عبر سكربت ثابت داخل Termux. هذه مرحلة تكامل Termux وليست Python مدمجاً داخل APK؛ توافق جميع مكتبات RHM مع Chaquopy ما زال قيد الإثبات.',
                          ),
                          SizedBox(height: 8),
                          Text(
                            'لا يمكن ضمان بقاء أي تطبيق Android عاملاً إلى الأبد؛ يستطيع النظام أو المستخدم إيقافه.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_status.lastApiCheckAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'آخر فحص: ${_status.lastApiCheckAt!.toLocal()}',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
