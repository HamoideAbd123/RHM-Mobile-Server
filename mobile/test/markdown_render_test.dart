import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhm_mobile/legacy_material_compatibility.dart';
import 'package:rhm_mobile/markdown_table_theme.dart';

void main() {
  testWidgets('renders formatted assistant Markdown as selectable content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => wrapLegacyMaterialWidgets(child!),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownBody(
              data: '# RHM response\n\n**Important**\n\n- First item\n- Second item',
              selectable: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('RHM response'), findsOneWidget);
    expect(find.text('Important'), findsOneWidget);
    expect(find.text('First item'), findsOneWidget);
    expect(find.text('Second item'), findsOneWidget);
  });

  testWidgets('renders Markdown tables and fenced code blocks', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => wrapLegacyMaterialWidgets(child!),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownBody(
              data: '| Provider | State |\n| --- | --- |\n| Gemini | Ready |\n\n```python\nprint("RHM")\n```',
              selectable: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Provider'), findsOneWidget);
    expect(find.text('Gemini'), findsOneWidget);
    expect(find.textContaining('print'), findsOneWidget);
  });

  test('assistant Markdown table border uses the active theme divider color', () {
    const dividerColor = Color(0xffaabbcc);
    final border = buildRhmMarkdownTableBorder(
      ThemeData(dividerColor: dividerColor),
    );

    expect(border.top.color, dividerColor);
    expect(border.left.color, dividerColor);
    expect(border.horizontalInside.color, dividerColor);
    expect(border.verticalInside.color, dividerColor);
  });
}
