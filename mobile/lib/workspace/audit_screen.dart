import 'package:material_ui/material_ui.dart';
import '../api_client.dart';
import '../rhm_theme.dart';
import '../workspace_shared.dart';

class RhmAuditScreen extends StatefulWidget {
  const RhmAuditScreen({super.key, required this.api});
  final RhmApiClient api;
  @override
  State<RhmAuditScreen> createState() => _RhmAuditScreenState();
}

class _RhmAuditScreenState extends State<RhmAuditScreen> {
  List<RhmAuditEvent> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final events = await widget.api.listAuditEvents();
      if (mounted) setState(() => _events = events);
    } catch (e) {
      if (mounted) setState(() => _error = workspaceErrorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(DateTime? value) {
    if (value == null) return 'وقت غير متاح';
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}  ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('سجل التدقيق'), actions: [
      IconButton(onPressed: _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh)),
    ]),
    body: _loading ? workspaceLoadingWidget() : RefreshIndicator(
      onRefresh: _load,
      child: _events.isEmpty
        ? ListView(children: [workspaceEmpty(context, 'لا توجد أحداث بعد', 'ستظهر هنا الأحداث المهمة مثل إنشاء المحادثات وتحديث المهام وحذف الذكريات.', Icons.receipt_long_outlined)])
        : ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 7),
            itemBuilder: (context, index) {
              final event = _events[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Theme.of(context).extension<RhmUiTokens>()!.border),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).extension<RhmUiTokens>()!.accentSoft,
                    child: Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Text(event.action, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${event.eventType} · ${event.actor} · ${event.entityType}${event.entityId == null ? '' : ' · ${event.entityId}'}\n${_date(event.createdAt)}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          ),
    ),
    bottomSheet: _error == null ? null : Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(padding: const EdgeInsets.all(10), child: Text(_error!)),
    ),
  );
}
