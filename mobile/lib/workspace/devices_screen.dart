import 'package:material_ui/material_ui.dart';
import '../api_client.dart';
import '../rhm_theme.dart';
import '../workspace_shared.dart';

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
      if (mounted) setState(() => _error = workspaceErrorText(e));
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
      if (mounted) setState(() => _error = workspaceErrorText(e));
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
    body: _loading ? workspaceLoadingWidget() : RefreshIndicator(
      onRefresh: _load,
      child: _devices.isEmpty
        ? ListView(children: [workspaceEmpty(context, 'لا توجد أجهزة مسجلة', 'ستظهر هنا الأجهزة التي سجلت هويتها مع RHM.', Icons.devices_other_outlined)])
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
