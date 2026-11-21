part of 'chat_screen.dart';

extension _ChatScreenNavigation on _ChatScreenState {
  Future<void> _openWorkspace(String section, {bool closeDrawer = false}) async {
    if (closeDrawer) Navigator.pop(context);

    // Settings are a local application surface and must remain usable offline.
    if (section == 'settings') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RhmSettingsScreen(
            serverUrl: _activeServerUrl ?? _serverUrl.text,
            connectionReady: _connectionReady,
            providers: _providers,
            preferredProvider: _preferredProvider,
            preferredModel: _preferredModel,
            locale: _locale,
            offlineRecognition: _offlineRecognition,
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
            onOpenConnectionSettings: _showConnectionSettings,
            onOpenAndroidRuntime: () => _openWorkspace('android-runtime'),
            onOpenVoiceDiagnostics: () => _openWorkspace('voice'),
            onCheckAppUpdates: () => _checkForUpdates(),
            onRefreshProviders: _connectionReady ? _loadProviders : null,
            onProviderChanged: (value) {
              this._setState(() {
                _preferredProvider = value;
                _preferredModel = null;
              });
              _persistAppPreferences();
            },
            onModelChanged: (value) {
              this._setState(() => _preferredModel = value);
              _persistAppPreferences();
            },
            onLocaleChanged: (value) {
              this._setState(() => _locale = value);
              _persistAppPreferences();
            },
            onOfflineRecognitionChanged: (value) {
              this._setState(() => _offlineRecognition = value);
              _persistAppPreferences();
            },
          ),
        ),
      );
      return;
    }

    if (section == 'android-runtime') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const RhmAndroidRuntimeScreen()),
      );
      return;
    }

    final api = _api;
    if (api == null) {
      await _showConnectionSettings();
      return;
    }
    final Widget screen = switch (section) {
      'projects' => RhmProjectsScreen(api: api),
      'tasks' => RhmTasksScreen(api: api),
      'memories' => RhmMemoriesScreen(api: api),
      'audit' => RhmAuditScreen(api: api),
      'devices' => RhmDevicesScreen(api: api),
      'control' => RhmControlCenterScreen(
          api: api,
          tts: _tts,
          speech: _speech,
          locale: _locale,
          preferredProvider: _preferredProvider,
          preferredModel: _preferredModel,
        ),
      'server-update' => RhmServerUpdateScreen(api: api),
      'mcp' => RhmMcpScreen(api: api),
      'notifications' => RhmNotificationsScreen(api: api),
      'voice' => RhmVoiceDiagnosticsScreen(
          tts: _tts,
          speech: _speech,
          locale: _locale,
        ),
      'agent' => RhmAgentScreen(
          api: api,
          preferredProvider: _preferredProvider,
          preferredModel: _preferredModel,
        ),
      _ => const SizedBox.shrink(),
    };
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  TextDirection _directionFor(String value) {
    if (value.trim().isEmpty) return TextDirection.rtl;
    return RegExp(r'[\u0600-\u06ff]').hasMatch(value)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  Widget _buildSidebar() {
    final available = <RhmProviderInfo>[];
    final seenProviders = <String>{};
    for (final provider in _providers) {
      if (provider.configured &&
          provider.models.isNotEmpty &&
          seenProviders.add(provider.provider)) {
        available.add(provider);
      }
    }
    final selectedProvider = available.any(
      (provider) => provider.provider == _preferredProvider,
    )
        ? _preferredProvider
        : null;
    final selected = available.where(
      (provider) => provider.provider == selectedProvider,
    );
    final models = selected.isEmpty
        ? <String>[]
        : selected.first.models.toSet().toList(growable: false);
    final query = _conversationSearch.text.trim().toLowerCase();
    final visibleConversations = _conversations.where((conversation) {
      return query.isEmpty ||
          conversation.title.toLowerCase().contains(query);
    }).toList(growable: false);
    final tokens = Theme.of(context).extension<RhmUiTokens>()!;

    return Drawer(
      width: 320,
      child: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RHM',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: .3,
                              ),
                        ),
                        Text(
                          'مساعدك الشخصي',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: tokens.muted,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _newConversation();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('محادثة جديدة'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: AlignmentDirectional.centerStart,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'النموذج',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedProvider,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المزوّد'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('تلقائي حسب الخادم'),
                  ),
                  ...available.map(
                    (provider) => DropdownMenuItem<String>(
                      value: provider.provider,
                      child: Text(
                        provider.provider == 'gemini'
                            ? 'Google Gemini'
                            : provider.provider == 'ollama'
                                ? 'Ollama محلي'
                                : provider.provider,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  this._setState(() {
                    _preferredProvider = value;
                    _preferredModel = null;
                  });
                  _persistAppPreferences();
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: models.contains(_preferredModel)
                    ? _preferredModel
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'النموذج'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('اختيار تلقائي'),
                  ),
                  ...models.map(
                    (model) => DropdownMenuItem<String>(
                      value: model,
                      child: Text(model, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: selectedProvider == null
                    ? null
                    : (value) {
                        this._setState(() => _preferredModel = value);
                        _persistAppPreferences();
                      },
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _api == null || _loadingProviders
                    ? null
                    : _loadProviders,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  _loadingProviders ? 'جارٍ التحديث…' : 'تحديث النماذج',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(RhmDesignTokens.minimumTouchTarget),
                ),
              ),
              const SizedBox(height: 18),
              Divider(color: tokens.border),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'المحادثات الأخيرة',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'تحديث سجل المحادثات',
                    onPressed: _loadingConversations
                        ? null
                        : _refreshConversationList,
                    icon: _loadingConversations
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _conversationSearch,
                onChanged: (_) => this._setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'ابحث في عناوين المحادثات',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _conversationSearch.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'مسح البحث',
                          onPressed: () {
                            _conversationSearch.clear();
                            this._setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              if (_loadingConversations && _conversations.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (visibleConversations.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    _conversations.isEmpty
                        ? 'ستظهر محادثاتك المحفوظة هنا.'
                        : 'لا توجد محادثات تطابق البحث.',
                    style: TextStyle(color: tokens.muted),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...visibleConversations.map(
                  (conversation) => ListTile(
                    dense: true,
                    minLeadingWidth: 24,
                    leading: const Icon(Icons.chat_bubble_outline_rounded),
                    title: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: conversation.id == _conversationId
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    selected: conversation.id == _conversationId,
                    selectedTileColor: tokens.accentSoft,
                    onTap: () {
                      Navigator.pop(context);
                      _openConversation(conversation);
                    },
                    trailing: PopupMenuButton<String>(
                      tooltip: 'خيارات المحادثة',
                      onSelected: (value) {
                        if (value == 'rename') _renameConversation(conversation);
                        if (value == 'delete') _deleteConversation(conversation);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text('إعادة تسمية'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('حذف المحادثة'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionRequiredScreen(String destination) => Scaffold(
        appBar: AppBar(title: Text(destination)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.link_off_rounded,
                  size: 42,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 14),
                const Text(
                  'اتصل بخادم RHM لفتح هذه المساحة.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _showConnectionSettings,
                  icon: const Icon(Icons.settings_ethernet_rounded),
                  label: const Text('إعداد الاتصال'),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _hubTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          minVerticalPadding: 12,
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).extension<RhmUiTokens>()!.accentSoft,
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: onTap,
        ),
      );

  Widget _buildActivityTab() {
    if (!shouldShowMoreServerModules(
      hasApiClient: _api != null,
      connectionReady: _connectionReady,
    )) {
      return _buildConnectionRequiredScreen('النشاط');
    }
    return Scaffold(
      appBar: AppBar(title: const Text('النشاط')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'تابع العمل والتنبيهات والأحداث المهمة في RHM.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          _hubTile(
            icon: Icons.checklist_rounded,
            title: 'المهام',
            subtitle: 'المهام المفتوحة وحالات التنفيذ والأولويات',
            onTap: () => _openWorkspace('tasks'),
          ),
          _hubTile(
            icon: Icons.notifications_active_outlined,
            title: 'الإشعارات',
            subtitle: 'تحديثات المحادثات والمهام والنظام',
            onTap: () => _openWorkspace('notifications'),
          ),
          _hubTile(
            icon: Icons.receipt_long_outlined,
            title: 'سجل التدقيق',
            subtitle: 'الأحداث والعمليات المسجلة في RHM',
            onTap: () => _openWorkspace('audit'),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreTab() {
    final showServerModules = shouldShowMoreServerModules(
      hasApiClient: _api != null,
      connectionReady: _connectionReady,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!showServerModules)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'بعض وحدات RHM تحتاج إلى اتصال بالخادم. يمكنك فتح الإعدادات حتى عندما يكون الخادم متوقفًا.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          _hubTile(
            icon: Icons.settings_outlined,
            title: 'إعدادات RHM',
            subtitle: 'الاتصال والمزوّد والصوت والتحديثات',
            onTap: () => _openWorkspace('settings'),
          ),
          if (showServerModules) ...[
            _hubTile(
              icon: Icons.psychology_outlined,
              title: 'الذاكرة',
              subtitle: 'استعراض الذكريات والبحث وإدارتها',
              onTap: () => _openWorkspace('memories'),
            ),
            _hubTile(
              icon: Icons.smart_toy_outlined,
              title: 'وكيل RHM والأدوات',
              subtitle: 'تشغيل الوكيل ومراجعة الأدوات المسموح بها',
              onTap: () => _openWorkspace('agent'),
            ),
            _hubTile(
              icon: Icons.devices_other_outlined,
              title: 'الأجهزة',
              subtitle: 'الأجهزة المسجلة وحالة اتصالها',
              onTap: () => _openWorkspace('devices'),
            ),
            _hubTile(
              icon: Icons.hub_outlined,
              title: 'تكاملات MCP',
              subtitle: 'خوادم MCP والأدوات المعتمدة والقراءة فقط',
              onTap: () => _openWorkspace('mcp'),
            ),
            _hubTile(
              icon: Icons.tune_rounded,
              title: 'مركز التحكم',
              subtitle: 'حالة النظام والتطبيقات والوحدات',
              onTap: () => _openWorkspace('control'),
            ),
            _hubTile(
              icon: Icons.system_update_alt_rounded,
              title: 'تحديثات الخادم',
              subtitle: 'حالة الخادم والتحديثات',
              onTap: () => _openWorkspace('server-update'),
            ),
            _hubTile(
              icon: Icons.graphic_eq_rounded,
              title: 'تشخيص الصوت',
              subtitle: 'محركات النطق والميكروفون واللغات',
              onTap: () => _openWorkspace('voice'),
            ),
          ],
        ],
      ),
    );
  }
}
