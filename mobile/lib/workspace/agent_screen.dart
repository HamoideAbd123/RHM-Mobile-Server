import 'package:material_ui/material_ui.dart';
import '../api_client.dart';
import '../rhm_theme.dart';
import '../workspace_shared.dart';

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
    } catch (e) { if (mounted) setState(() => _error = workspaceErrorText(e)); }
    finally { if (mounted) setState(() => _running = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('وكيل RHM')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        color: Theme.of(context).extension<RhmUiTokens>()!.accentSoft,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
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
        icon: _running
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : const Icon(Icons.play_arrow_rounded),
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
