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
    final portReachable = _status.apiPortReachable;

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
                        portReachable
                            ? 'منفذ RHM المحلي متاح عبر TCP.'
                            : 'لا توجد استجابة على 127.0.0.1:8000.',
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
                        'هذا يشغّل خدمة المراقبة فقط. لا يشغّل Python أو Termux تلقائياً في هذه المرحلة.',
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
                          onPressed: _busy || running
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
                            'الخدمة تعرض إشعاراً دائماً وتفحص اتصال TCP بمنفذ 8000 كل 15 ثانية. هذا لا يثبت أن API يقبل رمز الوصول أو أن PostgreSQL والوكيل يعملان.',
                          ),
                          SizedBox(height: 8),
                          Text(
                            'لم يُربط تشغيل أو إيقاف عمليات Python/Termux بعد. سنضيف ذلك عبر تكامل محدود واختياري بعد التحقق من بيئة Termux وصلاحياتها.',
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
                      'آخر فحص: ' + _status.lastApiCheckAt!.toLocal().toString(),
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
