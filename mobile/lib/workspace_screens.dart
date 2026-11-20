
import 'package:material_ui/material_ui.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'api_client.dart';
import 'rhm_theme.dart';

String _errorText(Object e) => e is RhmApiException ? e.message : 'تعذر إكمال العملية.';

Widget _loadingWidget() => const Center(child: CircularProgressIndicator());

Widget _empty(BuildContext context, String title, String subtitle, IconData icon) => Center(
  child: Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 12),
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      const SizedBox(height: 6),
      Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5)),
    ]),
  ),
);

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
    } catch (e) { if (mounted) setState(() => _error = _errorText(e)); }
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
    } catch (e) { if (mounted) setState(() => _error = _errorText(e)); }
    name.dispose(); description.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المشاريع'), actions: [
      IconButton(onPressed: _create, tooltip: 'مشروع جديد', icon: const Icon(Icons.add)),
      IconButton(onPressed: _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh)),
    ]),
    body: _loading ? _loadingWidget() : RefreshIndicator(
      onRefresh: _load,
      child: _items.isEmpty
        ? ListView(children: [_empty(context, 'لا توجد مشاريع بعد', 'أنشئ مشروعًا لتنظيم العمل والمهام والذاكرة.', Icons.folder_open_outlined)])
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
    } catch (e) { if (mounted) setState(() => _error = _errorText(e)); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    final tasks = _data?['open_tasks'] as List? ?? const [];
    final memories = _data?['memories'] as List? ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(widget.project.name), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading ? _loadingWidget() : _error != null ? _empty(context, 'تعذر تحميل السياق', _error!, Icons.error_outline) : RefreshIndicator(
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
    } catch (e) { if (mounted) setState(() => _error = _errorText(e)); }
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
    } catch (e) { if (mounted) setState(() => _error = _errorText(e)); }
    title.dispose(); description.dispose();
  }

  Future<void> _status(RhmTask task, String status) async {
    try {
      final updated = await widget.api.updateTask(task.id, status: status);
      if (mounted) setState(() => _items = _items.map((x) => x.id == task.id ? updated : x).toList());
    } catch (e) { if (mounted) setState(() => _error = _errorText(e)); }
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
    body: _loading ? _loadingWidget() : Column(
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
              ? ListView(children: [_empty(context, 'لا توجد مهام', 'أنشئ مهمة واربطها بمشروع أو اتركها مهمة عامة.', Icons.task_alt)])
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
    } catch (e) { if (mounted) setState(() => _error = _errorText(e)); }
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
    } catch (e) { if (mounted) setState(() => _error = _errorText(e)); }
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
      if (mounted) setState(() => _error = _errorText(e));
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
    } catch (e) { if (mounted) setState(() => _error = _errorText(e)); }
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
        child: _loading ? _loadingWidget() : RefreshIndicator(
          onRefresh: () => _load(query: _query.text),
          child: _items.isEmpty
            ? ListView(children: [_empty(context, 'لا توجد ذكريات مطابقة', 'أضف معلومة أو ابحث في الذاكرة.', Icons.psychology_outlined)])
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

class RhmAgentScreen extends StatefulWidget {
  const RhmAgentScreen({super.key, required this.api, this.preferredProvider, this.preferredModel});
  final RhmApiClient api;
  final String? preferredProvider;
  final String? preferredModel;
  @override
  State<RhmAgentScreen> createState() => _RhmAgentScreenState();
}

class _RhmAgentScreenState extends State<RhmAgentScreen> {
  final _prompt = TextEditingController();
  RhmAgentReply? _reply;
  bool _running = false;
  String? _error;
  @override
  void dispose() { _prompt.dispose(); super.dispose(); }

  Future<void> _run() async {
    if (_prompt.text.trim().isEmpty || _running) return;
    setState(() { _running = true; _error = null; _reply = null; });
    FocusScope.of(context).unfocus();
    try {
      final result = await widget.api.runAgent(
        _prompt.text.trim(),
        preferredProvider: widget.preferredProvider,
        preferredModel: widget.preferredModel,
      );
      if (mounted) setState(() => _reply = result);
    } catch (e) { if (mounted) setState(() => _error = _errorText(e)); }
    finally { if (mounted) setState(() => _running = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('وكيل RHM')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        color: Theme.of(context).extension<RhmUiTokens>()!.accentSoft,
        elevation: 0,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.shield_outlined, color: Theme.of(context).colorScheme.primary), SizedBox(width: 8), Text('أدوات قراءة آمنة', style: TextStyle(fontWeight: FontWeight.bold))]),
            SizedBox(height: 8),
            Text('يمكن للوكيل الاستعلام عن المشاريع والمهام والذاكرة. لا يملك هذا المسار صلاحية تشغيل أوامر النظام أو حذف البيانات أو تعديلها.', style: TextStyle(height: 1.55)),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _prompt,
        minLines: 3,
        maxLines: 7,
        decoration: const InputDecoration(
          labelText: 'ما الذي تريد من الوكيل فعله؟',
          hintText: 'مثال: راجع مشاريعي والمهام المفتوحة والذكريات المرتبطة بها.',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _running ? null : _run,
        icon: _running ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.play_arrow_rounded),
        label: Text(_running ? 'الوكيل يعمل…' : 'تشغيل الوكيل'),
      ),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      if (_reply != null) Card(
        margin: const EdgeInsets.only(top: 16),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('النتيجة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('${_reply!.provider} · ${_reply!.model} · ${_reply!.toolCalls} استدعاء أداة', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const Divider(height: 22),
            SelectableText(_reply!.content, style: const TextStyle(height: 1.6)),
          ]),
        ),
      ),
    ]),
  );
}


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
      if (mounted) setState(() => _error = _errorText(e));
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
    body: _loading ? _loadingWidget() : RefreshIndicator(
      onRefresh: _load,
      child: _events.isEmpty
        ? ListView(children: [_empty(context, 'لا توجد أحداث بعد', 'ستظهر هنا الأحداث المهمة مثل إنشاء المحادثات وتحديث المهام وحذف الذكريات.', Icons.receipt_long_outlined)])
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
                  leading: const CircleAvatar(
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

class RhmDevicesScreen extends StatefulWidget {
  const RhmDevicesScreen({super.key, required this.api});
  final RhmApiClient api;
  @override
  State<RhmDevicesScreen> createState() => _RhmDevicesScreenState();
}

class _RhmDevicesScreenState extends State<RhmDevicesScreen> {
  List<RhmDevice> _devices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final devices = await widget.api.listDevices();
      if (mounted) setState(() => _devices = devices);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revoke(RhmDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء اعتماد الجهاز؟'),
        content: Text('لن يتمكن "${device.name}" من استخدام هوية الجهاز المسجلة بعد هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إلغاء الاعتماد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.revokeDevice(device.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء اعتماد الجهاز.')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    }
  }

  String _lastSeen(DateTime? value) {
    if (value == null) return 'لم يتصل بعد';
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الأجهزة المسجلة'), actions: [
      IconButton(onPressed: _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh)),
    ]),
    body: _loading ? _loadingWidget() : RefreshIndicator(
      onRefresh: _load,
      child: _devices.isEmpty
        ? ListView(children: [_empty(context, 'لا توجد أجهزة مسجلة', 'ستظهر هنا الأجهزة التي سجلت هويتها مع RHM.', Icons.devices_other_outlined)])
        : ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _devices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final device = _devices[index];
              final active = device.status == 'active';
              final inventory = device.inventory;
              final platform = inventory?['platform']?.toString();
              final architecture = inventory?['architecture']?.toString();
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Theme.of(context).extension<RhmUiTokens>()!.border),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: active ? Theme.of(context).extension<RhmUiTokens>()!.accentSoft : Theme.of(context).colorScheme.errorContainer,
                    child: Icon(active ? Icons.devices : Icons.phonelink_erase, color: active ? Theme.of(context).extension<RhmUiTokens>()!.success : Theme.of(context).colorScheme.error),
                  ),
                  title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${active ? 'نشط' : 'ملغى'} · ${platform ?? 'منصة غير محددة'} ${architecture ?? ''}\nآخر اتصال: ${_lastSeen(device.lastSeenAt)}\nبصمة: ${device.fingerprint}',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: active
                      ? IconButton(
                          tooltip: 'إلغاء اعتماد الجهاز',
                          onPressed: () => _revoke(device),
                          icon: Icon(Icons.block, color: Theme.of(context).colorScheme.error),
                        )
                      : null,
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


class RhmVoiceDiagnosticsScreen extends StatefulWidget {
  const RhmVoiceDiagnosticsScreen({
    super.key,
    required this.tts,
    required this.speech,
    required this.locale,
  });

  final FlutterTts tts;
  final SpeechToText speech;
  final String locale;

  @override
  State<RhmVoiceDiagnosticsScreen> createState() => _RhmVoiceDiagnosticsScreenState();
}

class _RhmVoiceDiagnosticsScreenState extends State<RhmVoiceDiagnosticsScreen> {
  @override
  void initState() {
    super.initState();
    _inspect();
  }

  bool _loading = true;
  bool _testing = false;
  bool _requestingPermission = false;
  bool _speechReady = false;
  bool _ttsLanguageAvailable = false;
  bool _ttsLanguageInstalled = false;
  String? _defaultEngine;
  List<String> _engines = [];
  List<Map<dynamic, dynamic>> _matchingVoices = [];
  List<LocaleName> _speechLocales = [];
  String? _error;
  String? _ttsError;
  String? _speechError;
  bool _speechPermissionGranted = false;
  String _status = 'جارٍ فحص خدمات الصوت على هذا الجهاز…';

  String get _language => widget.locale.split('-').first.toLowerCase();

  bool _isOffline(Map<dynamic, dynamic> voice) {
    final value = voice['network_required'];
    return value == false ||
        value == 0 ||
        value == '0' ||
        value == 'false';
  }

  String _normalizeLocale(String value) =>
      value.toLowerCase().replaceAll('_', '-');

  bool _matchesLocale(String value) {
    final normalized = _normalizeLocale(value);
    return normalized == _normalizeLocale(widget.locale) ||
        normalized == _language ||
        normalized.startsWith('$_language-');
  }

  Future<void> _inspect() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _ttsError = null;
      _speechError = null;
      _status = 'جارٍ فحص محركات النطق والتعرف…';
    });

    var engines = <String>[];
    String? defaultEngine;
    var voices = <Map<dynamic, dynamic>>[];
    var ttsLanguageAvailable = false;
    var ttsLanguageInstalled = false;
    String? ttsError;

    // TTS diagnostics must remain useful even when speech recognition is
    // missing, denied, or temporarily unavailable on the Android device.
    try {
      final dynamic rawEngines = await widget.tts.getEngines;
      final dynamic rawDefaultEngine = await widget.tts.getDefaultEngine;
      final dynamic rawVoices = await widget.tts.getVoices;
      final dynamic available = await widget.tts.isLanguageAvailable(widget.locale);
      final dynamic installed = await widget.tts.isLanguageInstalled(widget.locale);

      engines = (rawEngines as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList();
      defaultEngine = rawDefaultEngine?.toString();
      voices = (rawVoices as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .where((voice) => voice['locale'] is String)
          .where((voice) => _matchesLocale(voice['locale'] as String))
          .toList()
        ..sort((left, right) {
          final leftOffline = _isOffline(left) ? 0 : 1;
          final rightOffline = _isOffline(right) ? 0 : 1;
          final offlineOrder = leftOffline.compareTo(rightOffline);
          if (offlineOrder != 0) return offlineOrder;
          final leftExact = _normalizeLocale(left['locale'].toString()) ==
                  _normalizeLocale(widget.locale)
              ? 0
              : 1;
          final rightExact = _normalizeLocale(right['locale'].toString()) ==
                  _normalizeLocale(widget.locale)
              ? 0
              : 1;
          return leftExact.compareTo(rightExact);
        });
      ttsLanguageAvailable = available == true;
      ttsLanguageInstalled = installed == true;
    } catch (_) {
      ttsError = 'تعذر قراءة معلومات محرك النطق. تحقق من محرك تحويل النص إلى كلام في إعدادات Android.';
    }

    var speechPermissionGranted = false;
    var speechReady = false;
    var speechLocales = <LocaleName>[];
    String? speechError;

    // Query speech locales only after initialization, and never request a
    // microphone permission simply because the diagnostics page was opened.
    try {
      speechPermissionGranted = await widget.speech.hasPermission;
      if (!speechPermissionGranted) {
        speechError = 'إذن الميكروفون غير ممنوح. اضغط زر طلب الإذن لفحص خدمة التعرف.';
      } else {
        speechReady = await widget.speech.initialize(
          onError: (error) {
            if (mounted) {
              setState(() {
                _speechReady = false;
                _speechError = 'خدمة التعرف أبلغت عن خطأ: ${error.errorMsg}';
              });
            }
          },
          onStatus: (_) {},
        );
        if (speechReady) {
          final locales = await widget.speech.locales();
          speechLocales = locales
              .where((item) => _matchesLocale(item.localeId))
              .toList()
            ..sort((left, right) {
              final leftExact = _normalizeLocale(left.localeId) ==
                      _normalizeLocale(widget.locale)
                  ? 0
                  : 1;
              final rightExact = _normalizeLocale(right.localeId) ==
                      _normalizeLocale(widget.locale)
                  ? 0
                  : 1;
              return leftExact.compareTo(rightExact);
            });
          if (speechLocales.isEmpty) {
            speechError = 'خدمة التعرف جاهزة، لكنها لم تُرجع لغة مطابقة. تحقق من حزم اللغات في Android.';
          }
        } else {
          speechError = 'تعذر تهيئة خدمة التعرف رغم منح إذن الميكروفون. تحقق من تثبيت خدمة كلام متوافقة.';
        }
      }
    } catch (_) {
      speechError = 'تعذر فحص خدمة التعرف. تحقق من إذن الميكروفون وخدمة الكلام المثبتة في Android.';
    }

    if (!mounted) return;
    setState(() {
      _engines = engines;
      _defaultEngine = defaultEngine;
      _matchingVoices = voices;
      _speechLocales = speechLocales;
      _ttsLanguageAvailable = ttsLanguageAvailable;
      _ttsLanguageInstalled = ttsLanguageInstalled;
      _speechPermissionGranted = speechPermissionGranted;
      _speechReady = speechReady;
      _ttsError = ttsError;
      _speechError = speechError;
      _status = 'اكتمل فحص خدمات الصوت المتاحة. يمكنك اختبار النطق وطلب إذن الميكروفون بصورة مستقلة.';
    });
  }

  Future<void> _requestSpeechPermission() async {
    if (_requestingPermission) return;
    setState(() {
      _requestingPermission = true;
      _speechError = null;
      _status = 'جارٍ طلب إذن الميكروفون وتهيئة خدمة التعرف…';
    });
    try {
      final ready = await widget.speech.initialize(
        onError: (error) {
          if (mounted) {
            setState(() {
              _speechReady = false;
              _speechError = 'خدمة التعرف أبلغت عن خطأ: ${error.errorMsg}';
            });
          }
        },
        onStatus: (status) {
          if (mounted) setState(() => _status = 'حالة خدمة التعرف: $status');
        },
      );
      final permissionGranted = await widget.speech.hasPermission;
      final locales = ready ? await widget.speech.locales() : <LocaleName>[];
      if (!mounted) return;
      final matchingLocales = locales
          .where((item) => _matchesLocale(item.localeId))
          .toList()
        ..sort((left, right) {
          final leftExact = _normalizeLocale(left.localeId) ==
                  _normalizeLocale(widget.locale)
              ? 0
              : 1;
          final rightExact = _normalizeLocale(right.localeId) ==
                  _normalizeLocale(widget.locale)
              ? 0
              : 1;
          return leftExact.compareTo(rightExact);
        });
      setState(() {
        _speechPermissionGranted = permissionGranted;
        _speechReady = ready;
        _speechLocales = matchingLocales;
        _speechError = !permissionGranted
            ? 'لم يمنح Android إذن الميكروفون. راجع أذونات التطبيق.'
            : !ready
                ? 'لم تصبح خدمة التعرف جاهزة. راجع خدمة الكلام المثبتة في Android.'
                : matchingLocales.isEmpty
                    ? 'خدمة التعرف جاهزة، لكن لا توجد لغة مطابقة للغة المختارة.'
                    : null;
        _status = _speechError == null
            ? 'خدمة التعرف جاهزة. اللغات المطابقة: ${matchingLocales.length}.'
            : 'لم يكتمل إعداد التعرف على الكلام.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _speechPermissionGranted = false;
          _speechReady = false;
          _speechError = 'فشلت تهيئة خدمة التعرف. تأكد من منح إذن الميكروفون وتثبيت خدمة كلام متوافقة.';
          _status = 'تعذر إعداد التعرف على الكلام.';
        });
      }
    } finally {
      if (mounted) setState(() => _requestingPermission = false);
    }
  }

  Future<void> _testSpeechOutput() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _error = null;
      _status = 'جارٍ تشغيل عينة صوتية للغة ${widget.locale}…';
    });
    try {
      final offlineVoices = _matchingVoices.where(_isOffline).toList();
      final selected = offlineVoices.isNotEmpty
          ? offlineVoices.first
          : (_matchingVoices.isNotEmpty ? _matchingVoices.first : null);
      if (selected != null) {
        await widget.tts.setVoice({
          'name': selected['name'].toString(),
          'locale': selected['locale'].toString(),
        });
      } else {
        final available = await widget.tts.isLanguageAvailable(widget.locale);
        if (available != true) {
          throw StateError('No voice is available for ${widget.locale}.');
        }
        await widget.tts.setLanguage(widget.locale);
      }
      await widget.tts.setSpeechRate(0.48);
      await widget.tts.setVolume(1);
      await widget.tts.setPitch(1);
      await widget.tts.awaitSpeakCompletion(true);
      final result = await widget.tts.speak(
        widget.locale.toLowerCase().startsWith('ar')
            ? 'مرحبًا، هذا اختبار لصوت مساعد RHM. إذا سمعت هذه الجملة بوضوح، فمحرك النطق يعمل.'
            : 'Hello. This is a test of the RHM assistant voice. If you can hear this sentence clearly, speech output is working.',
        focus: true,
      );
      if (!mounted) return;
      setState(() {
        _status = result == 1
            ? (selected != null && _isOffline(selected)
                ? 'نجح الاختبار باستخدام صوت محلي مثبت.'
                : 'بدأ الاختبار باستخدام محرك الصوت المتاح؛ قد يتطلب اتصالًا.')
            : 'لم يبدأ محرك النطق القراءة. تحقق من إعدادات تحويل النص إلى كلام في Android.';
        if (result != 1) _error = 'لم يقبل محرك النطق طلب القراءة.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'فشل اختبار النطق. قد تكون حزمة اللغة غير مثبتة أو قد لا يدعم المحرك اللغة المحددة.';
          _status = 'تعذر تشغيل عينة الصوت.';
        });
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _stopSpeechOutput() async {
    await widget.tts.stop();
    if (mounted) setState(() => _status = 'تم إيقاف القراءة الصوتية.');
  }

  @override
  Widget build(BuildContext context) {
    final offlineCount = _matchingVoices.where(_isOffline).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تشخيص الصوت'),
        actions: [
          IconButton(
            tooltip: 'إعادة الفحص',
            onPressed: _loading ? null : _inspect,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? _loadingWidget()
          : RefreshIndicator(
              onRefresh: _inspect,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
                children: [
                  Card(
                    elevation: 0,
                    color: Theme.of(context).extension<RhmUiTokens>()!.accentSoft,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(_status, style: const TextStyle(height: 1.5)),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  if (_ttsError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _ttsError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _diagnosticCard(
                    title: 'محرك تحويل النص إلى كلام',
                    icon: Icons.record_voice_over_outlined,
                    children: [
                      _diagnosticLine('المحرك الافتراضي', _defaultEngine ?? 'غير متاح'),
                      _diagnosticLine('محركات مثبتة', '${_engines.length}'),
                      ..._engines.map((engine) => _diagnosticLine('محرك', engine)),
                      _diagnosticLine(
                        'دعم اللغة ${widget.locale}',
                        _ttsLanguageAvailable ? 'متاحة للمحرك' : 'غير متاحة للمحرك',
                      ),
                      _diagnosticLine(
                        'حزمة اللغة المحلية',
                        _ttsLanguageInstalled ? 'مثبتة' : 'غير مؤكدة/غير مثبتة',
                      ),
                      _diagnosticLine('أصوات مطابقة', '${_matchingVoices.length}'),
                      _diagnosticLine('أصوات محلية', '$offlineCount'),
                      const SizedBox(height: 8),
                      if (_matchingVoices.isEmpty)
                        const Text(
                          'لا توجد أصوات مطابقة للغة المختارة. افتح إعدادات تحويل النص إلى كلام في Android وثبّت صوتًا عربيًا أو إنجليزيًا.',
                          style: TextStyle(height: 1.5),
                        )
                      else
                        ..._matchingVoices.map((voice) {
                          final locale = voice['locale']?.toString() ?? '';
                          final name = voice['name']?.toString() ?? 'صوت بلا اسم';
                          return _diagnosticLine(
                            name,
                            '$locale · ${_isOffline(voice) ? 'محلي' : 'قد يحتاج الإنترنت'}',
                          );
                        }),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _testing ? null : _testSpeechOutput,
                            icon: const Icon(Icons.play_arrow),
                            label: Text(_testing ? 'جارٍ التشغيل…' : 'اختبار القراءة'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _stopSpeechOutput,
                            icon: const Icon(Icons.stop),
                            label: const Text('إيقاف'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _diagnosticCard(
                    title: 'التعرف على الكلام والميكروفون',
                    icon: Icons.mic_none_rounded,
                    children: [
                      if (_speechError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _speechError!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error, height: 1.45),
                          ),
                        ),
                      _diagnosticLine(
                        'إذن الميكروفون',
                        _speechPermissionGranted ? 'ممنوح' : 'غير ممنوح',
                      ),
                      _diagnosticLine(
                        'خدمة التعرف',
                        _speechReady ? 'متاحة' : 'غير مهيأة',
                      ),
                      _diagnosticLine(
                        'لغة ${widget.locale}',
                        '${_speechLocales.length} لغة/منطقة مطابقة',
                      ),
                      if (_speechLocales.isEmpty)
                        const Text(
                          'لم تُرجع خدمة التعرف لغة مطابقة. ثبّت خدمة كلام مثل Google Speech Services وحزمة اللغة في إعدادات Android.',
                          style: TextStyle(height: 1.5),
                        )
                      else
                        ..._speechLocales.map(
                          (locale) => _diagnosticLine(locale.name, locale.localeId),
                        ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: _requestingPermission ? null : _requestSpeechPermission,
                        icon: _requestingPermission
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.mic),
                        label: Text(
                          _requestingPermission
                              ? 'جارٍ التحقق…'
                              : 'طلب إذن الميكروفون وفحص التعرف',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ملاحظة: تطبيق RHM يستخدم محركات Android المثبتة ولا يضمّن أصواتًا أو نموذج تعرف صوتي داخل APK. عدم توفر صوت محلي لا يعني بالضرورة تعذر استخدام صوت متصل بالشبكة.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _diagnosticCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) =>
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: Color(0xffe8ebf3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 22),
              ...children,
            ],
          ),
        ),
      );

  Widget _diagnosticLine(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}
