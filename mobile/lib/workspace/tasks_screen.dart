import 'package:material_ui/material_ui.dart';
import '../api_client.dart';
import '../rhm_theme.dart';
import '../workspace_shared.dart';

class RhmTasksScreen extends StatefulWidget {
  const RhmTasksScreen({super.key, required this.api});
  final RhmApiClient api;
  @override
  State<RhmTasksScreen> createState() => _RhmTasksScreenState();
}

class _RhmTasksScreenState extends State<RhmTasksScreen> {
  List<RhmTask> _items = [];
  List<RhmProject> _projects = [];
  bool _loading = true;
  String? _error;
  String? _filterProjectName;
  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([widget.api.listTasks(projectName: _filterProjectName), widget.api.listProjects()]);
      if (mounted) setState(() { _items = results[0] as List<RhmTask>; _projects = results[1] as List<RhmProject>; });
    } catch (e) { if (mounted) setState(() => _error = workspaceErrorText(e)); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _create() async {
    final title = TextEditingController();
    final description = TextEditingController();
    String? projectName;
    String priority = 'normal';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: const Text('إنشاء مهمة'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'عنوان المهمة')),
          const SizedBox(height: 8),
          TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'الوصف')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: projectName,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'المشروع'),
            items: [const DropdownMenuItem<String>(value: null, child: Text('مهمة عامة')), ..._projects.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name)))],
            onChanged: (v) => update(() => projectName = v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: priority,
            decoration: const InputDecoration(labelText: 'الأولوية'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('منخفضة')),
              DropdownMenuItem(value: 'normal', child: Text('عادية')),
              DropdownMenuItem(value: 'high', child: Text('عالية')),
              DropdownMenuItem(value: 'urgent', child: Text('عاجلة')),
            ],
            onChanged: (v) => update(() => priority = v ?? 'normal'),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنشاء')),
        ],
      )),
    );
    if (ok != true || title.text.trim().isEmpty) { title.dispose(); description.dispose(); return; }
    try {
      await widget.api.createTask(title.text.trim(), projectName: projectName, description: description.text.trim().isEmpty ? null : description.text.trim(), priority: priority);
      await _load();
    } catch (e) { if (mounted) setState(() => _error = workspaceErrorText(e)); }
    title.dispose(); description.dispose();
  }

  Future<void> _status(RhmTask task, String status) async {
    try {
      final updated = await widget.api.updateTask(task.id, status: status);
      if (mounted) setState(() => _items = _items.map((x) => x.id == task.id ? updated : x).toList());
    } catch (e) { if (mounted) setState(() => _error = workspaceErrorText(e)); }
  }

  String _label(String v) => switch (v) {
    'done' => 'مكتملة',
    'in_progress' => 'قيد التنفيذ',
    'cancelled' => 'ملغاة',
    _ => 'مفتوحة',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المهام'), actions: [
      IconButton(onPressed: _create, tooltip: 'مهمة جديدة', icon: const Icon(Icons.add)),
      IconButton(onPressed: _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh)),
    ]),
    body: _loading ? workspaceLoadingWidget() : Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: DropdownButtonFormField<String>(
            initialValue: _filterProjectName,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'تصفية المهام حسب المشروع',
              prefixIcon: Icon(Icons.filter_list),
            ),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('كل المهام')),
              ..._projects.map((project) => DropdownMenuItem<String>(
                value: project.name,
                child: Text(project.name, overflow: TextOverflow.ellipsis),
              )),
            ],
            onChanged: (value) {
              setState(() => _filterProjectName = value);
              _load();
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _items.isEmpty
              ? ListView(children: [workspaceEmpty(context, 'لا توجد مهام', 'أنشئ مهمة واربطها بمشروع أو اتركها مهمة عامة.', Icons.task_alt)])
        : ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final task = _items[i];
            return Card(elevation: 0, child: ListTile(
              title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${_label(task.status)} · أولوية ${task.priority}${task.description?.isNotEmpty == true ? '\n${task.description}' : ''}'),
              trailing: PopupMenuButton<String>(
                tooltip: 'تغيير الحالة',
                onSelected: (v) => _status(task, v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'open', child: Text('مفتوحة')),
                  PopupMenuItem(value: 'in_progress', child: Text('قيد التنفيذ')),
                  PopupMenuItem(value: 'done', child: Text('مكتملة')),
                  PopupMenuItem(value: 'cancelled', child: Text('ملغاة')),
                ],
                child: Chip(label: Text(_label(task.status)), side: BorderSide.none, backgroundColor: Theme.of(context).extension<RhmUiTokens>()!.accentSoft),
              ),
            ));
          },
          ),
        ),
        ),
      ],
    ),
    bottomSheet: _error == null ? null : Material(color: Theme.of(context).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(10), child: Text(_error!))),
  );
}
