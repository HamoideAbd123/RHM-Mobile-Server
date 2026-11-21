import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import 'api_client.dart';
import 'rhm_theme.dart';

class RhmMcpStatusChip extends StatefulWidget {
  const RhmMcpStatusChip({
    super.key,
    required this.api,
    required this.onPressed,
  });

  final RhmApiClient? api;
  final VoidCallback onPressed;

  @override
  State<RhmMcpStatusChip> createState() => _RhmMcpStatusChipState();
}

class _RhmMcpStatusChipState extends State<RhmMcpStatusChip> {
  Future<List<RhmMcpServer>>? _serversFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant RhmMcpStatusChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) _refresh();
  }

  void _refresh() {
    _serversFuture = widget.api?.listMcpServers();
  }

  @override
  Widget build(BuildContext context) {
    final future = _serversFuture;
    if (future == null) {
      return ActionChip(
        avatar: const Icon(Icons.hub_outlined, size: 17),
        label: const Text('MCP'),
        tooltip: 'اتصل بخادم RHM لقراءة حالة تكامل MCP.',
        onPressed: null,
      );
    }

    return FutureBuilder<List<RhmMcpServer>>(
      future: future,
      builder: (context, snapshot) {
        final servers = snapshot.data ?? const <RhmMcpServer>[];
        final readyCount = servers.where((server) => server.readyForDiscovery).length;
        final String detail;
        if (snapshot.connectionState == ConnectionState.waiting) {
          detail = 'جارٍ قراءة إعداد MCP';
        } else if (snapshot.hasError) {
          detail = 'تعذر قراءة إعداد MCP من الخادم';
        } else if (servers.isEmpty) {
          detail = 'لا توجد خوادم MCP مهيأة';
        } else if (readyCount == 0) {
          detail = 'توجد خوادم MCP لكنها غير مفعّلة أو غير معتمدة أو ينقصها اعتماد';
        } else {
          detail = '$readyCount خادم MCP مهيأ؛ لم يُختبر الاتصال البعيد بعد';
        }
        return ActionChip(
          avatar: Icon(
            Icons.hub_outlined,
            size: 17,
            color: snapshot.hasError
                ? Theme.of(context).colorScheme.error
                : readyCount > 0
                    ? Theme.of(context).extension<RhmUiTokens>()!.success
                    : null,
          ),
          label: const Text('MCP'),
          tooltip: detail,
          onPressed: widget.onPressed,
        );
      },
    );
  }
}

class RhmMcpScreen extends StatefulWidget {
  const RhmMcpScreen({super.key, required this.api});

  final RhmApiClient api;

  @override
  State<RhmMcpScreen> createState() => _RhmMcpScreenState();
}

class _RhmMcpScreenState extends State<RhmMcpScreen> {
  List<RhmMcpServer> _servers = [];
  final Map<String, List<RhmMcpTool>> _tools = {};
  bool _loading = true;
  String? _error;
  String? _busyServer;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _tools.clear();
    });
    try {
      final servers = await widget.api.listMcpServers();
      if (!mounted) return;
      setState(() => _servers = servers);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _discover(RhmMcpServer server) async {
    setState(() {
      _busyServer = server.id;
      _error = null;
    });
    try {
      final tools = await widget.api.discoverMcpTools(server.id);
      if (mounted) setState(() => _tools[server.id] = tools);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busyServer = null);
    }
  }

  Future<void> _invoke(RhmMcpServer server, RhmMcpTool tool) async {
    final controller = TextEditingController(text: '{}');
    final argumentsText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('مراجعة مدخلات ${tool.name}'),
        content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tool.description.isEmpty ? 'لا يوجد وصف للأداة.' : tool.description),
                const SizedBox(height: 10),
                const Text('مخطط المدخلات (Input Schema)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                SelectableText(
                  const JsonEncoder.withIndent('  ').convert(tool.inputSchema),
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 12),
                Text(
                  'ستُرسل هذه المدخلات إلى خادم MCP الخارجي. لا تضع كلمات مرور أو رموز وصول أو بيانات خاصة.',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).extension<RhmUiTokens>()!.warning),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: 'Arguments بصيغة JSON',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
            ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('مراجعة التنفيذ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (argumentsText == null || !mounted) return;

    Map<String, dynamic> arguments;
    try {
      final decoded = jsonDecode(argumentsText);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('يجب أن تكون المدخلات كائن JSON.');
      }
      arguments = decoded;
    } on FormatException catch (error) {
      setState(() => _error = error.message);
      return;
    }

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد استدعاء أداة MCP'),
        content: Text(
          'الأداة: ${server.id} / ${tool.name}\n'
          'نوع التنفيذ: قراءة فقط حسب تعريف الخادم وسياسة RHM.\n\n'
          'المدخلات التي ستُرسل:\n${const JsonEncoder.withIndent('  ').convert(arguments)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('أوافق على الإرسال'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    setState(() {
      _busyServer = server.id;
      _error = null;
    });
    try {
      final result = await widget.api.invokeMcpTool(server.id, tool.name, arguments);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('نتيجة أداة MCP'),
          content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(result),
                ),
              ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busyServer = null);
    }
  }

  String _host(String endpoint) {
    final uri = Uri.tryParse(endpoint);
    return uri?.host.isNotEmpty == true ? uri!.host : 'عنوان غير صالح';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تكاملات MCP'),
        actions: [
          IconButton(
            tooltip: 'تحديث خوادم MCP',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.hub_outlined, color: Theme.of(context).colorScheme.primary),
                              SizedBox(width: 8),
                              Text('Model Context Protocol', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'تعرض هذه الصفحة خوادم MCP التي أُعدّت على خادم RHM. لا تُخزّن بيانات الاعتماد في التطبيق، ولا يمكن تشغيل الأدوات إلا إذا كان الخادم مفعّلًا ومعتمدًا وكانت الأداة ضمن قائمة السماح للقراءة فقط.',
                            style: TextStyle(height: 1.55),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!),
                      ),
                    ),
                  if (_servers.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'لا توجد خوادم MCP مُعرّفة حاليًا. أضف إعداد الخادم وقائمة الأدوات المسموح بها في بيئة Backend عبر RHM_MCP_SERVERS_JSON، ثم أعد تشغيل Backend. لا تضع الأسرار في التطبيق أو GitHub.',
                          style: TextStyle(height: 1.6),
                        ),
                      ),
                    ),
                  for (final server in _servers)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.dns_outlined),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(server.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                Chip(
                                  label: Text(
                                    !server.enabled
                                        ? 'متوقف'
                                        : !server.approved
                                            ? 'غير معتمد'
                                            : server.credentialConfigured
                                                ? 'جاهز'
                                                : 'بيانات الاعتماد ناقصة',
                                  ),
                                ),
                              ],
                            ),
                            Text(_host(server.endpoint), style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 8),
                            Text('الأدوات المسموح بها: ${server.allowedTools.length}'),
                            const SizedBox(height: 10),
                            if (!server.enabled || !server.approved || !server.credentialConfigured)
                              Text(
                                'يلزم تفعيل الخادم واعتماده وإعداد بيانات اعتماده في Backend قبل اكتشاف الأدوات.',
                                style: TextStyle(fontSize: 12, color: Theme.of(context).extension<RhmUiTokens>()!.warning),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: _busyServer == server.id ? null : () => _discover(server),
                                icon: _busyServer == server.id
                                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.search),
                                label: const Text('اكتشاف الأدوات المسموح بها'),
                              ),
                            for (final tool in _tools[server.id] ?? const <RhmMcpTool>[])
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.build_circle_outlined, color: Theme.of(context).colorScheme.primary),
                                title: Text(tool.name),
                                subtitle: Text(tool.description.isEmpty ? 'أداة قراءة فقط' : tool.description),
                                trailing: const Icon(Icons.play_arrow_rounded),
                                onTap: _busyServer == server.id ? null : () => _invoke(server, tool),
                              ),
                            if (_tools.containsKey(server.id) && _tools[server.id]!.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('لم يُرجع الخادم أي أداة تستوفي قائمة السماح وشرط readOnlyHint.'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'تنبيه أمني: لا تُرسل إلى أدوات MCP بيانات اعتماد RHM أو مفاتيح المزودين أو محتوى خاصًا إلا بعد مراجعة الحاجة والموافقة الصريحة.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
                  ),
                ],
              ),
            ),
    );
  }
}
