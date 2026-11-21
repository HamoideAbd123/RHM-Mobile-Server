import 'package:material_ui/material_ui.dart';

import '../api_client.dart';
import '../rhm_theme.dart';

class RhmChatComposer extends StatelessWidget {
  const RhmChatComposer({
    super.key,
    required this.controller,
    required this.projects,
    required this.selectedProjectName,
    required this.projectScopeInitialized,
    required this.hasPendingRequest,
    required this.isBusy,
    required this.isListening,
    required this.isSpeaking,
    required this.onProjectChanged,
    required this.onTextChanged,
    required this.directionFor,
    required this.onToggleRecording,
    required this.onSend,
    required this.onStopSpeaking,
  });

  final TextEditingController controller;
  final List<RhmProject> projects;
  final String? selectedProjectName;
  final bool projectScopeInitialized;
  final bool hasPendingRequest;
  final bool isBusy;
  final bool isListening;
  final bool isSpeaking;
  final ValueChanged<String?> onProjectChanged;
  final ValueChanged<String> onTextChanged;
  final TextDirection Function(String) directionFor;
  final VoidCallback onToggleRecording;
  final VoidCallback onSend;
  final VoidCallback onStopSpeaking;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedProjectName,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: projectScopeInitialized
                    ? 'سياق المشروع (مثبّت للمحادثة)'
                    : 'ربط المحادثة بمشروع',
                prefixIcon: const Icon(Icons.folder_outlined),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('بدون مشروع محدد'),
                ),
                ...projects.map(
                  (project) => DropdownMenuItem<String>(
                    value: project.name,
                    child: Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (projectScopeInitialized || hasPendingRequest)
                  ? null
                  : onProjectChanged,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Theme.of(context).extension<RhmUiTokens>()!.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withValues(alpha: .08),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: isListening ? 'إيقاف التسجيل' : 'تسجيل صوتي',
                    onPressed: isBusy ? null : onToggleRecording,
                    style: IconButton.styleFrom(
                      backgroundColor: isListening
                          ? Theme.of(context).colorScheme.errorContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      foregroundColor: isListening
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                    icon: Icon(isListening ? Icons.stop_rounded : Icons.mic_none_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 48000,
                      textDirection: directionFor(controller.text),
                      onChanged: onTextChanged,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالتك…',
                        counterText: '',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  IconButton.filled(
                    tooltip: 'إرسال الرسالة',
                    onPressed: isBusy || isListening ? null : onSend,
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      disabledBackgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      minimumSize: const Size(
                        RhmDesignTokens.minimumTouchTarget,
                        RhmDesignTokens.minimumTouchTarget,
                      ),
                    ),
                    icon: isBusy
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'إيقاف القراءة الصوتية',
                  visualDensity: VisualDensity.standard,
                  onPressed: isSpeaking ? onStopSpeaking : null,
                  icon: Icon(
                    Icons.volume_off_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Flexible(
                  child: Text(
                    'قد تحتاج الردود إلى اتصال بخادم RHM.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}
