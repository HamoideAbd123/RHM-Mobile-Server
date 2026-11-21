import 'package:material_ui/material_ui.dart';
import '../api_client.dart';
import '../workspace_shared.dart';

class RhmMemoriesScreen extends StatefulWidget {
  const RhmMemoriesScreen({super.key, required this.api});
  final RhmApiClient api;
  @override
  State<RhmMemoriesScreen> createState() => _RhmMemoriesScreenState();
}

class _RhmMemoriesScreenState extends State<RhmMemoriesScreen> {
  List<RhmMemory> _items = [];
  List<RhmProject> _projects = [];
  final _query = TextEditingController();
  bool _loading = true;
  String? _error;
  @override
  void initState() { super.initState(); _load(); _loadProjects(); }
  @override
  void dispose() { _query.dispose(); super.dispose(); }

  Future<void> _loadProjects() async {
    try {
      final projects = await widget.api.listProjects();
      if (mounted) setState(() => _projects = projects);
    } catch (_) {
      // Memory browsing remains available when projects cannot be loaded.
    }
  }

  Future<void> _load({String? query}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = query == null || query.trim().isEmpty
        ? await widget.api.listMemories()
        : await widget.api.searchMemories(query.trim());
      if (mounted) setState(() => _items = items);
    } catch (e) { if (mounted) setState(() => _error = workspaceErrorText(e)); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _create() async {
    final content = TextEditingController();
    String kind = 'semantic';
    String? projectName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: const Text('حفظ معلومة في الذاكرة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: content, autofocus: true, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'المعلومة')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: kind,
            decoration: const InputDecoration(labelText: 'النوع'),
            items: const [
              DropdownMenuItem(value: 'semantic', child: Text('معرفة')),
              DropdownMenuItem(value: 'episodic', child: Text('حدث')),
              DropdownMenuItem(value: 'procedural', child: Text('إجراء')),
              DropdownMenuItem(value: 'preference', child: Text('تفضيل')),
              DropdownMenuItem(value: 'fact', child: Text('حقيقة')),
            ],
            onChanged: (v) => update(() => kind = v ?? 'semantic'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: projectName,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'ربط بمشروع (اختياري)'),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('ذاكرة عامة')),
              ..._projects.map((project) => DropdownMenuItem<String>(
                value: project.name,
                child: Text(project.name, overflow: TextOverflow.ellipsis),
              )),
            ],
            onChanged: (value) => update(() => projectName = value),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      )),
    );
    if (ok != true || content.text.trim().isEmpty) { content.dispose(); return; }
    try {
      await widget.api.createMemory(content.text.trim(), kind: kind, projectName: projectName);
      await _load(query: _query.text);
    } catch (e) { if (mounted) setState(() => _error = workspaceErrorText(e)); }
    content.dispose();
  }

  Future<void> _edit(RhmMemory memory) async {
    final content = TextEditingController(text: memory.content);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل الذاكرة'),
        content: TextField(
          controller: content,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'المعلومة المحفوظة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, content.text.trim()),
            child: const Text('حفظ التعديل'),
          ),
        ],
      ),
    );
    content.dispose();
    if (value == null || value.isEmpty || value == memory.content) return;
    try {
      final updated = await widget.api.updateMemory(memory.id, content: value);
      if (mounted) {
        setState(() {
          _items = _items.map((item) => item.id == memory.id ? updated : item).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = workspaceErrorText(e));
    }
  }

  Future<void> _delete(RhmMemory memory) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف هذه الذاكرة؟'),
        content: const Text('سيتم حذف المعلومة من ذاكرة RHM الدائمة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await widget.api.deleteMemory(memory.id);
      if (mounted) setState(() => _items.removeWhere((x) => x.id == memory.id));
    } catch (e) { if (mounted) setState(() => _error = workspaceErrorText(e)); }
  }

  String _kind(String v) => switch (v) {
    'episodic' => 'حدث',
    'procedural' => 'إجراء',
    'preference' => 'تفضيل',
    'fact' => 'حقيقة',
    _ => 'معرفة',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الذاكرة'), actions: [
      IconButton(onPressed: _create, tooltip: 'إضافة ذاكرة', icon: const Icon(Icons.add)),
      IconButton(onPressed: () => _load(query: _query.text), tooltip: 'تحديث', icon: const Icon(Icons.refresh)),
    ]),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) => _load(query: v),
          decoration: InputDecoration(
            hintText: 'ابحث في الذكريات…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(onPressed: () => _load(query: _query.text), icon: const Icon(Icons.arrow_forward)),
          ),
        ),
      ),
      if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      Expanded(
        child: _loading ? workspaceLoadingWidget() : RefreshIndicator(
          onRefresh: () => _load(query: _query.text),
          child: _items.isEmpty
            ? ListView(children: [workspaceEmpty(context, 'لا توجد ذكريات مطابقة', 'أضف معلومة أو ابحث في الذاكرة.', Icons.psychology_outlined)])
            : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final memory = _items[i];
                final linkedProjects = _projects
                    .where((project) => project.id == memory.projectId)
                    .toList();
                final projectLabel = linkedProjects.isEmpty
                    ? 'مشروع مرتبط'
                    : linkedProjects.first.name;
                return Card(elevation: 0, child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: Text(_kind(memory.kind), style: TextStyle(color: Theme.of(ctx).colorScheme.primary, fontWeight: FontWeight.bold))),
                      IconButton(onPressed: () => _edit(memory), tooltip: 'تعديل', icon: const Icon(Icons.edit_outlined, size: 20)),
                      IconButton(onPressed: () => _delete(memory), tooltip: 'حذف', icon: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error)),
                    ]),
                    SelectableText(memory.content, style: const TextStyle(height: 1.55)),
                    if (memory.projectId != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.folder_outlined, size: 14, color: Theme.of(ctx).colorScheme.primary),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              projectLabel,
                              style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text('الأهمية ${(memory.importance * 100).round()}% · الثقة ${(memory.confidence * 100).round()}%', style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                  ]),
                ));
              },
            ),
        ),
      ),
    ]),
  );
}
