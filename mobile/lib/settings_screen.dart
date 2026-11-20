import 'package:material_ui/material_ui.dart';

import 'api_client.dart';
import 'rhm_theme.dart';

class RhmSettingsScreen extends StatelessWidget {
  const RhmSettingsScreen({
    super.key,
    required this.serverUrl,
    required this.connectionReady,
    required this.providers,
    required this.preferredProvider,
    required this.preferredModel,
    required this.locale,
    required this.offlineRecognition,
    required this.themeMode,
    required this.onOpenConnectionSettings,
    required this.onOpenAndroidRuntime,
    required this.onOpenVoiceDiagnostics,
    required this.onCheckAppUpdates,
    required this.onProviderChanged,
    required this.onModelChanged,
    required this.onLocaleChanged,
    required this.onOfflineRecognitionChanged,
    required this.onThemeModeChanged,
    this.onRefreshProviders,
  });

  final String serverUrl;
  final bool connectionReady;
  final List<RhmProviderInfo> providers;
  final String? preferredProvider;
  final String? preferredModel;
  final String locale;
  final bool offlineRecognition;
  final ThemeMode themeMode;
  final VoidCallback onOpenConnectionSettings;
  final VoidCallback onOpenAndroidRuntime;
  final VoidCallback onOpenVoiceDiagnostics;
  final VoidCallback onCheckAppUpdates;
  final VoidCallback? onRefreshProviders;
  final ValueChanged<String?> onProviderChanged;
  final ValueChanged<String?> onModelChanged;
  final ValueChanged<String> onLocaleChanged;
  final ValueChanged<bool> onOfflineRecognitionChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final available = <RhmProviderInfo>[];
    final seenProviders = <String>{};
    for (final provider in providers) {
      if (provider.configured &&
          provider.models.isNotEmpty &&
          seenProviders.add(provider.provider)) {
        available.add(provider);
      }
    }
    final selected = available.where((provider) => provider.provider == preferredProvider);
    final models = selected.isEmpty
        ? <String>[]
        : selected.first.models.toSet().toList(growable: false);
    final selectedProvider = available.any((provider) => provider.provider == preferredProvider)
        ? preferredProvider
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات RHM')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const Text('المظهر', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: DropdownButtonFormField<ThemeMode>(
                initialValue: themeMode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'سمة التطبيق',
                  helperText: 'تتطابق ألوان الهاتف مع نظام RHM على الويب.',
                ),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('داكن'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('فاتح'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('حسب إعدادات Android'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onThemeModeChanged(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('الاتصال', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Card(
            child: ListTile(
              leading: Icon(
                connectionReady ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                color: connectionReady
                    ? Theme.of(context).extension<RhmUiTokens>()!.success
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(connectionReady ? 'الخادم متصل' : 'الخادم غير متصل'),
              subtitle: Text(serverUrl, textDirection: TextDirection.ltr),
              trailing: const Icon(Icons.chevron_left),
              onTap: onOpenConnectionSettings,
            ),
          ),
          const SizedBox(height: 18),
          const Text('النظام المحلي', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Card(
            child: ListTile(
              leading: const Icon(Icons.memory_outlined),
              title: const Text('مضيف Android المحلي'),
              subtitle: const Text('مراقبة وإدارة خادم RHM على هذا الهاتف، حتى دون اتصال حالي.'),
              trailing: const Icon(Icons.chevron_left),
              onTap: onOpenAndroidRuntime,
            ),
          ),
          const SizedBox(height: 18),
          const Text('الذكاء الاصطناعي', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedProvider,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'المزوّد'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('اختيار تلقائي من الخادم'),
                      ),
                      ...available.map(
                        (provider) => DropdownMenuItem<String>(
                          value: provider.provider,
                          child: Text(provider.provider),
                        ),
                      ),
                    ],
                    onChanged: connectionReady ? onProviderChanged : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: models.contains(preferredModel) ? preferredModel : null,
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
                    onChanged: connectionReady && selectedProvider != null ? onModelChanged : null,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: onRefreshProviders,
                      icon: const Icon(Icons.refresh),
                      label: const Text('تحديث قائمة المزوّدين والنماذج'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('الصوت', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: locale,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'لغة التعرّف والنطق'),
                    items: const [
                      DropdownMenuItem(value: 'ar-SA', child: Text('العربية')),
                      DropdownMenuItem(value: 'en-US', child: Text('English')),
                    ],
                    onChanged: (value) {
                      if (value != null) onLocaleChanged(value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('التعرّف دون اتصال'),
                    subtitle: const Text('يتطلب محرك تعرّف وحزمة لغة محلية على الهاتف.'),
                    value: offlineRecognition,
                    onChanged: onOfflineRecognitionChanged,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: onOpenVoiceDiagnostics,
                      icon: const Icon(Icons.graphic_eq),
                      label: const Text('تشخيص الصوت'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('التحديثات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Card(
            child: ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: const Text('فحص تحديثات تطبيق RHM'),
              subtitle: const Text('يتطلب اتصال التطبيق بخادم RHM.'),
              trailing: const Icon(Icons.chevron_left),
              onTap: connectionReady ? onCheckAppUpdates : null,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'لا تُعرض رموز الوصول أو مفاتيح المزوّدين داخل هذه الصفحة. تبقى بيانات الاعتماد محفوظة في التخزين الآمن على الهاتف أو في إعدادات الخادم.',
            style: TextStyle(fontSize: 12, height: 1.6, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
