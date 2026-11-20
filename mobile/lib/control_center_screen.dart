import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'api_client.dart';
import 'android_runtime_screen.dart';
import 'notifications_screen.dart';
import 'mcp_screen.dart';
import 'server_update_screen.dart';
import 'update_service.dart';
import 'workspace_screens.dart';

class RhmControlCenterScreen extends StatefulWidget {
  const RhmControlCenterScreen({
    super.key,
    required this.api,
    required this.tts,
    required this.speech,
    required this.locale,
    this.preferredProvider,
    this.preferredModel,
  });

  final RhmApiClient api;
  final FlutterTts tts;
  final SpeechToText speech;
  final String locale;
  final String? preferredProvider;
  final String? preferredModel;

  @override
  State<RhmControlCenterScreen> createState() => _RhmControlCenterScreenState();
}

class _RhmControlCenterScreenState extends State<RhmControlCenterScreen> {
  bool _loading = true;
  bool _connected = false;
  String? _error;
  List<RhmProviderInfo> _providers = [];
  List<RhmConversation> _conversations = [];
  List<RhmProject> _projects = [];
  List<RhmTask> _tasks = [];
  List<RhmMemory> _memories = [];
  List<RhmDevice> _devices = [];
  int _unreadNotifications = 0;
  RhmServerUpdateSnapshot? _serverUpdate;
  String _appVersion = '—';
  RhmUpdate? _appUpdate;
  bool _checkingAppUpdate = false;
  bool _installingAppUpdate = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    String? installedVersion;
    try {
      installedVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // System status remains available even if package metadata is unavailable.
    }
    try {
      final results = await Future.wait([
        widget.api.checkConnection(),
        widget.api.getProviders(),
        widget.api.listConversations(limit: 100),
        widget.api.listProjects(),
        widget.api.listTasks(),
        widget.api.listMemories(limit: 100),
        widget.api.listDevices(),
        widget.api.getNotifications(limit: 1),
        widget.api.getServerUpdateStatus(),
      ]);
      if (!mounted) return;
      final notifications = results[7] as Map<String, dynamic>;
      setState(() {
        _connected = true;
        _providers = results[1] as List<RhmProviderInfo>;
        _conversations = results[2] as List<RhmConversation>;
        _projects = results[3] as List<RhmProject>;
        _tasks = results[4] as List<RhmTask>;
        _memories = results[5] as List<RhmMemory>;
        _devices = results[6] as List<RhmDevice>;
        _unreadNotifications = notifications['unread_count'] is int
            ? notifications['unread_count'] as int
            : 0;
        _serverUpdate = results[8] as RhmServerUpdateSnapshot;
        if (installedVersion != null) _appVersion = installedVersion;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _connected = false;
          _error = error is RhmApiException
              ? error.message
              : 'تعذر جمع حالة جميع مكونات RHM.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkAppUpdate() async {
    if (_checkingAppUpdate) return;
    setState(() {
      _checkingAppUpdate = true;
      _error = null;
    });
    try {
      final info = await PackageInfo.fromPlatform();
      final update = await RhmUpdateService().checkForUpdate(widget.api);
      if (!mounted) return;
      setState(() {
        _appVersion = info.version;
        _appUpdate = update;
      });
      if (update == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تطبيق RHM محدّث إلى آخر إصدار.')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is RhmApiException
            ? error.message
            : 'تعذر فحص تحديثات تطبيق RHM.');
      }
    } finally {
      if (mounted) setState(() => _checkingAppUpdate = false);
    }
  }

  Future<void> _installAppUpdate() async {
    final update = _appUpdate;
    if (update == null || _installingAppUpdate) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تحديث تطبيق RHM'),
        content: Text(
          'سيتم تنزيل الإصدار ${update.version} والتحقق من SHA-256 قبل فتح مثبت Android. ستحتاج إلى تأكيد التثبيت من نافذة النظام.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('لاحقًا'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تنزيل وتثبيت'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      _installingAppUpdate = true;
      _error = null;
    });
    try {
      await RhmUpdateService().downloadAndInstall(update, widget.api);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is RhmApiException
            ? error.message
            : 'تعذر تثبيت تحديث التطبيق.');
      }
    } finally {
      if (mounted) setState(() => _installingAppUpdate = false);
    }
  }

  int get _availableProviders => _providers
      .where((provider) =>
          provider.configured &&
          provider.models.isNotEmpty &&
          !['unavailable', 'timeout', 'not_configured']
              .contains(provider.status))
      .length;

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) _refresh();
  }

  Widget _metric({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _module({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? count,
  }) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xffe5f5ef),
          child: Icon(icon, color: const Color(0xff159b72)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: count == null
            ? const Icon(Icons.chevron_right)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(count, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Icon(Icons.chevron_right, size: 16),
                ],
              ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final update = _serverUpdate;
    final serverState = update?.runtime['state']?.toString() ?? 'غير معروف';
    final frontendRuntime = update?.frontend ?? const <String, dynamic>{};
    final frontendState = frontendRuntime['state']?.toString() ?? 'غير متاحة';
    final frontendPort = frontendRuntime['port']?.toString();
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم RHM'),
        actions: [
          IconButton(
            tooltip: 'تحديث كل البيانات',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && _providers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                children: [
                  if (_error != null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!),
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 8, 4, 4),
                    child: Text(
                      'حالة النظام',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.35,
                    children: [
                      _metric(
                        icon: Icons.dns_outlined,
                        title: 'خادم RHM',
                        value: _connected ? 'متصل' : 'غير متصل',
                        subtitle: 'API · 127.0.0.1:8000',
                      ),
                      _metric(
                        icon: Icons.psychology_outlined,
                        title: 'مزودو الذكاء الاصطناعي',
                        value: '$_availableProviders / ${_providers.length}',
                        subtitle: 'مزودون متاحون',
                      ),
                      _metric(
                        icon: Icons.notifications_active_outlined,
                        title: 'إشعارات غير مقروءة',
                        value: '$_unreadNotifications',
                        onTap: () => _open(RhmNotificationsScreen(api: widget.api)),
                      ),
                      _metric(
                        icon: Icons.system_update_alt,
                        title: 'تحديث السيرفر',
                        value: serverState.replaceAll('_', ' '),
                        subtitle: update?.supervisorRunning == true
                            ? 'المشرف يعمل'
                            : 'المشرف غير مشغّل',
                        onTap: () => _open(RhmServerUpdateScreen(api: widget.api)),
                      ),
                      _metric(
                        icon: Icons.web_outlined,
                        title: 'واجهة الويب',
                        value: frontendState.replaceAll('_', ' '),
                        subtitle: frontendPort == null
                            ? 'Next.js · الحالة غير متاحة'
                            : 'Next.js · المنفذ :$frontendPort',
                        onTap: () => _open(RhmServerUpdateScreen(api: widget.api)),
                      ),
                      _metric(
                        icon: Icons.phone_android,
                        title: 'إصدار تطبيق RHM',
                        value: _appVersion,
                        subtitle: _appUpdate == null
                            ? 'إصدار مثبت'
                            : 'يتوفر ${_appUpdate!.version}',
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 18, 4, 4),
                    child: Text(
                      'مساحة العمل والتطبيقات',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.35,
                    children: [
                      _metric(
                        icon: Icons.chat_bubble_outline,
                        title: 'المحادثات',
                        value: '${_conversations.length}',
                        onTap: () => Navigator.pop(context),
                      ),
                      _metric(
                        icon: Icons.folder_outlined,
                        title: 'المشاريع',
                        value: '${_projects.length}',
                        onTap: () => _open(RhmProjectsScreen(api: widget.api)),
                      ),
                      _metric(
                        icon: Icons.task_alt,
                        title: 'المهام',
                        value: '${_tasks.length}',
                        onTap: () => _open(RhmTasksScreen(api: widget.api)),
                      ),
                      _metric(
                        icon: Icons.psychology_outlined,
                        title: 'الذاكرة',
                        value: '${_memories.length}',
                        onTap: () => _open(RhmMemoriesScreen(api: widget.api)),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 18, 4, 4),
                    child: Text(
                      'إدارة وحدات RHM',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                    _module(
                      icon: Icons.dns_outlined,
                      title: 'مضيف Android المحلي',
                      subtitle: 'مراقبة منفذ RHM وخيار التشغيل بعد الإقلاع',
                      onTap: () => _open(const RhmAndroidRuntimeScreen()),
                    ),
                  _module(
                    icon: Icons.smart_toy_outlined,
                    title: 'وكيل RHM',
                    subtitle: 'تشغيل الوكيل ومراجعة ناتج الأدوات الآمنة',
                    onTap: () => _open(RhmAgentScreen(
                      api: widget.api,
                      preferredProvider: widget.preferredProvider,
                      preferredModel: widget.preferredModel,
                    )),
                  ),
                  _module(
                    icon: Icons.hub_outlined,
                    title: 'تكاملات MCP',
                    subtitle: 'الخوادم المعتمدة والأدوات الخارجية المسموح بها',
                    onTap: () => _open(RhmMcpScreen(api: widget.api)),
                  ),
                  _module(
                    icon: Icons.build_outlined,
                    title: 'الأدوات والسياسات',
                    subtitle: 'سجل سماح ورفض الأدوات عبر الوكيل وسجل التدقيق',
                    onTap: () => _open(RhmAuditScreen(api: widget.api)),
                  ),
                  _module(
                    icon: Icons.devices_other_outlined,
                    title: 'الأجهزة',
                    subtitle: 'عرض الأجهزة وإلغاء اعتماد جهاز مسجل',
                    count: '${_devices.length}',
                    onTap: () => _open(RhmDevicesScreen(api: widget.api)),
                  ),
                  _module(
                    icon: Icons.receipt_long_outlined,
                    title: 'سجل التدقيق والأمان',
                    subtitle: 'أحداث النظام وعمليات الصلاحيات',
                    onTap: () => _open(RhmAuditScreen(api: widget.api)),
                  ),
                  _module(
                    icon: Icons.notifications_active_outlined,
                    title: 'مركز الإشعارات',
                    subtitle: 'كل فئات الإشعارات والقنوات وساعات الهدوء',
                    count: '$_unreadNotifications',
                    onTap: () => _open(RhmNotificationsScreen(api: widget.api)),
                  ),
                  _module(
                    icon: Icons.system_update_alt,
                    title: 'تحديثات تطبيق RHM',
                    subtitle: _appUpdate == null
                        ? 'الإصدار المثبت: $_appVersion · فحص الإصدار الجديد'
                        : 'الإصدار ${_appUpdate!.version} متاح للتثبيت',
                    onTap: _checkingAppUpdate || _installingAppUpdate
                        ? () {}
                        : _appUpdate == null
                            ? _checkAppUpdate
                            : _installAppUpdate,
                  ),
                  OutlinedButton.icon(
                    onPressed: _checkingAppUpdate || _installingAppUpdate
                        ? null
                        : _appUpdate == null
                            ? _checkAppUpdate
                            : _installAppUpdate,
                    icon: _checkingAppUpdate || _installingAppUpdate
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_appUpdate == null
                            ? Icons.refresh
                            : Icons.download_for_offline_outlined),
                    label: Text(_checkingAppUpdate
                        ? 'جارٍ فحص تحديث التطبيق…'
                        : _installingAppUpdate
                            ? 'جارٍ فتح مثبت Android…'
                            : _appUpdate == null
                                ? 'فحص تحديثات التطبيق'
                                : 'تثبيت ${_appUpdate!.version}'),
                  ),
                  _module(
                    icon: Icons.system_update_alt,
                    title: 'تحديثات السيرفر',
                    subtitle: 'الفحص والتثبيت المعتمد وسجل التحديثات',
                    onTap: () => _open(RhmServerUpdateScreen(api: widget.api)),
                  ),
                  _module(
                    icon: Icons.graphic_eq_rounded,
                    title: 'الصوت',
                    subtitle: 'تشخيص النطق والميكروفون واللغات المثبتة',
                    onTap: () => _open(RhmVoiceDiagnosticsScreen(
                      tts: widget.tts,
                      speech: widget.speech,
                      locale: widget.locale,
                    )),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'لا تعرض اللوحة مفاتيح API أو رموز الوصول أو بيانات الاعتماد. الإجراءات غير المدعومة لا تظهر كأزرار وهمية.',
                    style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.6),
                  ),
                ],
              ),
            ),
    );
  }
}
