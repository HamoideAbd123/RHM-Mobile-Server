import 'package:material_ui/material_ui.dart';

import 'api_client.dart';

const _categoryLabels = <String, String>{
  'chat': 'الدردشة والردود',
  'conversations': 'المحادثات',
  'projects': 'المشاريع',
  'tasks': 'المهام',
  'memory': 'الذاكرة',
  'agents': 'الوكلاء الذكيون',
  'models': 'مزودو ونماذج الذكاء الاصطناعي',
  'tools': 'الأدوات',
  'devices': 'الأجهزة',
  'security': 'الأمان والصلاحيات',
  'server_updates': 'تحديثات السيرفر',
  'app_updates': 'تحديثات التطبيق',
  'system': 'النظام والتشغيل',
};

const _categoryIcons = <String, IconData>{
  'chat': Icons.chat_bubble_outline,
  'conversations': Icons.forum_outlined,
  'projects': Icons.folder_outlined,
  'tasks': Icons.task_alt_outlined,
  'memory': Icons.psychology_outlined,
  'agents': Icons.smart_toy_outlined,
  'models': Icons.memory_outlined,
  'tools': Icons.build_outlined,
  'devices': Icons.devices_other_outlined,
  'security': Icons.shield_outlined,
  'server_updates': Icons.dns_outlined,
  'app_updates': Icons.system_update_alt,
  'system': Icons.settings_outlined,
};

class RhmNotificationsScreen extends StatefulWidget {
  const RhmNotificationsScreen({
    super.key,
    required this.api,
    this.onUnreadChanged,
  });

  final RhmApiClient api;
  final ValueChanged<int>? onUnreadChanged;

  @override
  State<RhmNotificationsScreen> createState() => _RhmNotificationsScreenState();
}

class _RhmNotificationsScreenState extends State<RhmNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _preferences = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  bool _unreadOnly = false;

  List<Map<String, dynamic>> get _visibleItems => _items.where((item) {
        final category = item['category']?.toString() ?? '';
        if (_selectedCategory != 'all' && category != _selectedCategory) {
          return false;
        }
        if (_unreadOnly && item['read'] == true) return false;
        final query = _searchQuery.trim().toLowerCase();
        if (query.isNotEmpty) {
          final haystack =
              '${item['title'] ?? ''} ${item['message'] ?? ''} $category'
                  .toLowerCase();
          if (!haystack.contains(query)) return false;
        }
        return true;
      }).toList();

  Map<String, dynamic> get _categories =>
      _preferences['categories'] is Map<String, dynamic>
          ? _preferences['categories'] as Map<String, dynamic>
          : <String, dynamic>{};

  Map<String, dynamic> get _channels =>
      _preferences['channels'] is Map<String, dynamic>
          ? _preferences['channels'] as Map<String, dynamic>
          : <String, dynamic>{};

  Map<String, dynamic> get _quietHours =>
      _preferences['quiet_hours'] is Map<String, dynamic>
          ? _preferences['quiet_hours'] as Map<String, dynamic>
          : <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await widget.api.getNotifications(limit: 100);
      final items = data['items'];
      final preferences = data['preferences'];
      if (!mounted) return;
      setState(() {
        _items = items is List
            ? items.whereType<Map<String, dynamic>>().toList()
            : [];
        _preferences = preferences is Map<String, dynamic>
            ? preferences
            : {};
        _error = null;
      });
      final unread = data['unread_count'];
      widget.onUnreadChanged?.call(unread is int ? unread : 0);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePreferences(Map<String, dynamic> changes) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.updateNotificationPreferences(changes);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await widget.api.markNotificationsRead(eventIds: [id]);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.api.markNotificationsRead(markAll: true);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _chooseQuietTime(String key) async {
    final raw = _quietHours[key]?.toString() ?? (key == 'start' ? '22:00' : '07:00');
    final pieces = raw.split(':');
    final initial = TimeOfDay(
      hour: pieces.length == 2 ? int.tryParse(pieces[0]) ?? 22 : 22,
      minute: pieces.length == 2 ? int.tryParse(pieces[1]) ?? 0 : 0,
    );
    final selected = await showTimePicker(context: context, initialTime: initial);
    if (selected == null) return;
    final value =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    await _updatePreferences({
      'quiet_hours': {..._quietHours, key: value},
    });
  }

  String _formatDate(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}  ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('مركز الإشعارات'),
          actions: [
            IconButton(
              tooltip: 'تحديث الإشعارات',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(icon: Icon(Icons.notifications_active_outlined), text: 'الوارد'),
              Tab(icon: Icon(Icons.tune_outlined), text: 'التفضيلات'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_error != null)
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(_error!),
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildInbox(),
                  _buildPreferences(),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildInbox() {
    final unread = _items.where((item) => item['read'] != true).length;
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text('$unread إشعار غير مقروء'),
              subtitle: const Text('تجمع هذه القائمة أحداث الدردشة ومساحة العمل والأجهزة والنظام.'),
              trailing: TextButton(
                onPressed: unread == 0 ? null : _markAllRead,
                child: const Text('قراءة الكل'),
              ),
            ),
          ),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'بحث في الإشعارات',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'نوع الإشعار',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: 'all',
                child: Text('كل الأنواع'),
              ),
              ..._categoryLabels.entries.map((entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  )),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedCategory = value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('غير المقروء فقط'),
            value: _unreadOnly,
            onChanged: (value) => setState(() => _unreadOnly = value),
          ),
          if (_visibleItems.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: Text('لا توجد إشعارات تطابق عوامل التصفية.')),
            ),
          ..._visibleItems.map((item) {
            final category = item['category']?.toString() ?? 'system';
            final isRead = item['read'] == true;
            return Card(
              elevation: 0,
              child: ListTile(
                onTap: isRead ? null : () => _markRead(item['id'].toString()),
                leading: CircleAvatar(
                  backgroundColor: isRead
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    _categoryIcons[category] ?? Icons.notifications_outlined,
                    size: 20,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['title']?.toString() ?? 'إشعار من RHM',
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    '${item['message'] ?? ''}\\n${_categoryLabels[category] ?? category} · ${_formatDate(item['created_at'])}',
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
                isThreeLine: true,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPreferences() {
    if (_loading && _preferences.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: SwitchListTile(
            title: const Text('تفعيل الإشعارات'),
            subtitle: const Text('المفتاح العام لجميع إشعارات RHM.'),
            value: _preferences['enabled'] == true,
            onChanged: _saving
                ? null
                : (value) => _updatePreferences({'enabled': value}),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 18, 8, 6),
          child: Text('قنوات الإشعار', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('داخل تطبيق RHM'),
                subtitle: const Text('مركز الإشعارات والعداد داخل التطبيق.'),
                value: _channels['in_app'] == true,
                onChanged: _saving
                    ? null
                    : (value) => _updatePreferences({
                          'channels': {'in_app': value},
                        }),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('إشعارات الهاتف'),
                subtitle: const Text('تنبيهات Android في شريط الإشعارات.'),
                value: _channels['android'] == true,
                onChanged: _saving
                    ? null
                    : (value) => _updatePreferences({
                          'channels': {'android': value},
                        }),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('إشعارات سطح المكتب'),
                subtitle: const Text('تعمل من متصفح الويب عند السماح بها.'),
                value: _channels['desktop'] == true,
                onChanged: _saving
                    ? null
                    : (value) => _updatePreferences({
                          'channels': {'desktop': value},
                        }),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 18, 8, 6),
          child: Text('أنواع الإشعارات', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Card(
          child: Column(
            children: _categoryLabels.entries.map((entry) {
              return SwitchListTile(
                secondary: Icon(_categoryIcons[entry.key] ?? Icons.notifications_outlined),
                title: Text(entry.value),
                value: _categories[entry.key] == true,
                onChanged: _saving
                    ? null
                    : (value) => _updatePreferences({
                          'categories': {entry.key: value},
                        }),
              );
            }).toList(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 18, 8, 6),
          child: Text('التحكم في كثافة الإشعارات', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: DropdownButtonFormField<String>(
              initialValue: _preferences['min_priority']?.toString() ?? 'low',
              decoration: const InputDecoration(
                labelText: 'أقل أهمية يتم إشعارك بها',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('كل الإشعارات')),
                DropdownMenuItem(value: 'normal', child: Text('العادية فما فوق')),
                DropdownMenuItem(value: 'high', child: Text('المهمة فقط')),
                DropdownMenuItem(value: 'critical', child: Text('الحرجة فقط')),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        _updatePreferences({'min_priority': value});
                      }
                    },
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('ساعات الهدوء'),
                subtitle: const Text('إيقاف التنبيهات الصوتية مؤقتًا خلال فترة محددة.'),
                value: _quietHours['enabled'] == true,
                onChanged: _saving
                    ? null
                    : (value) => _updatePreferences({
                          'quiet_hours': {..._quietHours, 'enabled': value},
                        }),
              ),
              ListTile(
                enabled: _quietHours['enabled'] == true && !_saving,
                title: const Text('بداية الهدوء'),
                trailing: Text(_quietHours['start']?.toString() ?? '22:00'),
                onTap: () => _chooseQuietTime('start'),
              ),
              ListTile(
                enabled: _quietHours['enabled'] == true && !_saving,
                title: const Text('نهاية الهدوء'),
                trailing: Text(_quietHours['end']?.toString() ?? '07:00'),
                onTap: () => _chooseQuietTime('end'),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'تعتمد إشعارات الهاتف الخلفية على بقاء السيرفر وAndroid WorkManager متاحين. قد يؤخر نظام توفير الطاقة تسليمها.',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
        ),
      ],
    );
  }
}
