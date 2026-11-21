import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhm_mobile/conversation/chat_composer.dart';
import 'package:rhm_mobile/rhm_theme.dart';

void main() {
  testWidgets('composer forwards text, recording, send and stop-reading actions', (tester) async {
    final controller = TextEditingController();
    var changedText = '';
    var recorded = false;
    var sent = false;
    var stopped = false;

    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: RhmTheme.light,
        home: Scaffold(
          body: RhmChatComposer(
            controller: controller,
            projects: const [],
            selectedProjectName: null,
            projectScopeInitialized: false,
            hasPendingRequest: false,
            isBusy: false,
            isListening: false,
            isSpeaking: true,
            onProjectChanged: (_) {},
            onTextChanged: (value) => changedText = value,
            directionFor: (_) => TextDirection.rtl,
            onToggleRecording: () => recorded = true,
            onSend: () => sent = true,
            onStopSpeaking: () => stopped = true,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'مرحبًا RHM');
    expect(changedText, 'مرحبًا RHM');
    await tester.tap(find.byTooltip('تسجيل صوتي'));
    await tester.tap(find.byTooltip('إرسال الرسالة'));
    await tester.tap(find.byTooltip('إيقاف القراءة الصوتية'));
    expect(recorded, isTrue);
    expect(sent, isTrue);
    expect(stopped, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('composer disables send while a request is active', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        theme: RhmTheme.dark,
        home: Scaffold(
          body: RhmChatComposer(
            controller: controller,
            projects: const [],
            selectedProjectName: null,
            projectScopeInitialized: false,
            hasPendingRequest: true,
            isBusy: true,
            isListening: false,
            isSpeaking: false,
            onProjectChanged: (_) {},
            onTextChanged: (_) {},
            directionFor: (_) => TextDirection.rtl,
            onToggleRecording: () {},
            onSend: () {},
            onStopSpeaking: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('إرسال الرسالة'));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
