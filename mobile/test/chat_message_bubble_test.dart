import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhm_mobile/conversation/chat_message.dart';
import 'package:rhm_mobile/conversation/chat_message_bubble.dart';
import 'package:rhm_mobile/rhm_theme.dart';

void main() {
  testWidgets('assistant message bubble renders Markdown and exposes actions', (tester) async {
    var spoken = false;
    var copied = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: RhmTheme.light,
        home: Scaffold(
          body: RhmChatMessageBubble(
            message: const RhmChatMessage(false, '**رد تجريبي**', provider: 'Gemini'),
            textDirection: TextDirection.rtl,
            onSpeak: () => spoken = true,
            onCopy: () => copied = true,
          ),
        ),
      ),
    );

    expect(find.text('رد تجريبي'), findsOneWidget);
    expect(find.text('Gemini'), findsOneWidget);
    await tester.tap(find.byTooltip('قراءة الرد'));
    await tester.tap(find.byTooltip('نسخ الرسالة'));
    expect(spoken, isTrue);
    expect(copied, isTrue);
  });

  testWidgets('user message bubble is selectable and does not show assistant voice action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RhmTheme.dark,
        home: Scaffold(
          body: RhmChatMessageBubble(
            message: const RhmChatMessage(true, 'رسالة المستخدم'),
            textDirection: TextDirection.rtl,
            onCopy: () {},
          ),
        ),
      ),
    );

    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text('رسالة المستخدم'), findsOneWidget);
    expect(find.byTooltip('قراءة الرد'), findsNothing);
    expect(find.byTooltip('نسخ الرسالة'), findsOneWidget);
  });
}
