import 'package:material_ui/material_ui.dart';

import 'api_client.dart';

class RhmServerUpdateScreen extends StatefulWidget {
  const RhmServerUpdateScreen({super.key, required this.api});

  final RhmApiClient api;

  @override
  State<RhmServerUpdateScreen> createState() => _RhmServerUpdateScreenState();
}

class _RhmServerUpdateScreenState extends State<RhmServerUpdateScreen> {
  RhmServerUpdateSnapshot? _snapshot;
  List<RhmServerUpdateEvent> _events = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.api.getServerUpdateStatus(),
        widget.api.getServerUpdateEvents(limit: 50),
      ]);
      if (!mounted) return;
      setState(() {
        _snapshot = results[0] as RhmServerUpdateSnapshot;
        _events = results[1] as List<RhmServerUpdateEvent>;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setAutoUpdate(bool value) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final snapshot = await widget.api.setServerAutoUpdate(value);
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _notice = value
              ? 'تم تفعيل التحديث التلقائي. يجب أن يكون مشرف السيرفر يعمل.'
              : 'تم إيقاف التحديث التلقائي.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await widget.api.checkServerUpdates();
      if (mounted) setState(() => _notice = result['message']?.toString());
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد طلب التحديث'),
        content: const Text(
          'سيُرسل طلب التحديث إلى مشرف السيرفر. سيطبّق المشرف التحديثات المعتمدة فقط، مع فحص الصحة والاستعادة عند الفشل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد الطلب'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.api.requestServerUpdate();
      if (mounted) setState(() => _notice = 'تم إرسال طلب التحديث إلى المشرف.');
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _date(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}  ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _short(String? value) =>
      value == null || value.isEmpty ? '—' : value.substring(0, value.length > 12 ? 12 : value.length);

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final runtime = snapshot?.runtime ?? const <String, dynamic>{};
    final frontend = snapshot?.frontend ?? const <String, dynamic>{};
    final frontendState = frontend['state']?.toString() ?? 'غير متاحة';
    final frontendPort = frontend['port']?.toString() ?? '—';
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة تحديث السيرفر'),
        actions: [
          IconButton(
            tooltip: 'تحديث الحالة',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && snapshot == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    _MessageCard(text: _error!, color: Theme.of(context).colorScheme.errorContainer),
                  if (_notice != null)
                    _MessageCard(text: _notice!, color: Theme.of(context).colorScheme.secondaryContainer),
                  Card(
                    child: SwitchListTile(
                      secondary: const Icon(Icons.autorenew),
                      title: const Text('التحديث التلقائي'),
                      subtitle: Text(snapshot?.autoUpdate == true ? 'مفعّل · كل 5 دقائق' : 'متوقف'),
                      value: snapshot?.autoUpdate ?? false,
                      onChanged: snapshot == null || _busy ? null : _setAutoUpdate,
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        snapshot?.supervisorRunning == true
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                      ),
                      title: const Text('مشرف السيرفر'),
                      subtitle: Text(snapshot?.supervisorRunning == true ? 'يعمل' : 'غير مشغّل'),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _MetricRow(label: 'الحالة', value: runtime['message']?.toString() ?? runtime['state']?.toString() ?? 'غير معروفة'),
                          _MetricRow(label: 'الإصدار الحالي', value: _short(runtime['current_sha']?.toString())),
                          _MetricRow(label: 'الإصدار المتاح', value: _short(runtime['target_sha']?.toString())),
                          _MetricRow(label: 'آخر فحص', value: _date(DateTime.tryParse(runtime['last_check_at']?.toString() ?? ''))),
                          _MetricRow(label: 'آخر تحديث ناجح', value: _date(DateTime.tryParse(runtime['last_success_at']?.toString() ?? ''))),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.web_outlined),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'واجهة الويب (Next.js)',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Chip(label: Text(frontendState.replaceAll('_', ' '))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _MetricRow(
                            label: 'منفذ الواجهة',
                            value: frontendPort == '—' ? 'غير معروف' : '127.0.0.1:$frontendPort',
                          ),
                          _MetricRow(
                            label: 'Commit الواجهة',
                            value: _short(frontend['current_sha']?.toString()),
                          ),
                          _MetricRow(
                            label: 'آخر تشغيل ناجح',
                            value: _date(DateTime.tryParse(frontend['last_success_at']?.toString() ?? '')),
                          ),
                          if (frontend['message'] is String)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                frontend['message'] as String,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          if (frontend['last_error'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'آخر خطأ: ${frontend['last_error']}',
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                            ),
                          if (frontend.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'إصدار السيرفر الحالي لا يرسل حالة واجهة الويب بعد.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _check,
                    icon: const Icon(Icons.search),
                    label: const Text('فحص التحديثات'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy || snapshot?.supervisorRunning != true ||
                        runtime['state'] != 'update_available'
                    ? null
                    : _apply,
                    icon: const Icon(Icons.system_update_alt),
                    label: const Text('طلب تثبيت التحديث'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'المركز موحّد: فحص واحد وطلب تحديث واحد يدير Backend وواجهة Next.js عبر المشرف نفسه. التحديثات غير المعتمدة لا تُطبّق، وتغييرات قاعدة البيانات والتبعيات تتطلب مراجعة يدوية.',
                      style: TextStyle(fontSize: 12, height: 1.6),
                    ),
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('سجل التحديثات والإشعارات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  if (_events.isEmpty)
                    const ListTile(title: Text('لا توجد إشعارات حتى الآن.'))
                  else
                    ..._events.reversed.map((event) => ListTile(
                          leading: Icon(_iconFor(event.state)),
                          title: Text(event.state.replaceAll('_', ' ')),
                          subtitle: Text(event.message),
                          trailing: Text(_date(event.createdAt), style: const TextStyle(fontSize: 10)),
                        )),
                ],
              ),
            ),
    );
  }

  IconData _iconFor(String state) => switch (state) {
        'updated' => Icons.check_circle_outline,
        'rolled_back' || 'error' || 'startup_failed' => Icons.warning_amber_rounded,
        'update_available' => Icons.system_update_alt,
        _ => Icons.info_outline,
      };
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 112, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
            Expanded(child: Text(value, textAlign: TextAlign.end)),
          ],
        ),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(text),
        ),
      );
}
