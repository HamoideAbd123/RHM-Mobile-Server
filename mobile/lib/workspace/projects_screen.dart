import 'package:material_ui/material_ui.dart';
import '../api_client.dart';
import '../rhm_theme.dart';
import '../workspace_shared.dart';

class RhmProjectsScreen extends StatefulWidget {
  const RhmProjectsScreen({super.key, required this.api});
  final RhmApiClient api;
  @override
  State<RhmProjectsScreen> createState() => _RhmProjectsScreenState();
}

class _RhmProjectsScreenState extends State<RhmProjectsScreen> {
  List<RhmProject> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await widget.api.listProjects();
      if (mounted) setState(() => _items = items);
    } catch (e) { if (mounted) setState(() => _error = workspaceErrorText(e)); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنشاء مشروع'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المشروع')),
          const SizedBox(height: 8),
          TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'الوصف (اختياري)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) { name.dispose(); description.dispose(); return; }
    try {
      await widget.api.createProject(name.text.trim(), description: description.text.trim().isEmpty ? null : description.text.trim());
      await _load();
    } catch (e) { if (mounted) setState(() => _error = workspaceErrorText(e)); }
    name.dispose(); description.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المشاريع'), actions: [
      IconButton(onPressed: _create, tooltip: 'مشروع جديد', icon: const Icon(Icons.add)),
      IconButton(onPressed: _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh)),
    ]),
    body: _loading ? workspaceLoadingWidget() : RefreshIndicator(
      onRefresh: _load,
      child: _items.isEmpty
        ? ListView(children: [workspaceEmpty(context, 'لا توجد مشاريع بعد', 'أنشئ مشروعًا لتنظيم العمل والمهام والذاكرة.', Icons.folder_open_outlined)])
        : ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final p = _items[i];
              return Card(elevation: 0, child: ListTile(
                leading: CircleAvatar(backgroundColor: Theme.of(ctx).extension<RhmUiTokens>()!.accentSoft, child: Icon(Icons.folder_outlined, color: Theme.of(ctx).colorScheme.primary)),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(p.description?.isNotEmpty == true ? p.description! : 'الحالة: ${p.status}'),
                onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => RhmProjectDetailsScreen(api: widget.api, project: p))),
              ));
            },
          ),
    ),
    bottomSheet: _error == null ? null : Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(padding: const EdgeInsets.all(10), child: Text(_error!)),
    ),
  );
}

class RhmProjectDetailsScreen extends StatefulWidget {
  const RhmProjectDetailsScreen({super.key, required this.api, required this.project});
  final RhmApiClient api;
  final RhmProject project;
  @override
  State<RhmProjectDetailsScreen> createState() => _RhmProjectDetailsScreenState();
}

class _RhmProjectDetailsScreenState extends State<RhmProjectDetailsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.api.getProjectContext(widget.project.name);
      if (mounted) setState(() => _data = result);
    } catch (e) { if (mounted) setState(() => _error = workspaceErrorText(e)); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    final tasks = _data?['open_tasks'] as List? ?? const [];
    final memories = _data?['memories'] as List? ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(widget.project.name), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading ? workspaceLoadingWidget() : _error != null ? workspaceEmpty(context, 'تعذر تحميل السياق', _error!, Icons.error_outline) : RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(widget.project.description ?? 'سياق المشروع في RHM', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          _detailCard('المهام المفتوحة', tasks, (x) => '${x['title'] ?? 'مهمة'} · ${x['status'] ?? 'open'}', Icons.checklist),
          const SizedBox(height: 12),
          _detailCard('الذكريات المرتبطة', memories, (x) => x['content']?.toString() ?? '', Icons.psychology_outlined),
        ]),
      ),
    );
  }

  Widget _detailCard(String title, List values, String Function(dynamic) label, IconData icon) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const Divider(),
        if (values.isEmpty) Text('لا توجد عناصر مرتبطة.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ...values.map((v) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(icon, color: Theme.of(context).colorScheme.primary), title: Text(label(v)))),
      ]),
    ),
  );
}
