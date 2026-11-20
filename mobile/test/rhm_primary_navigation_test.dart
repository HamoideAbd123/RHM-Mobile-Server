import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhm_mobile/rhm_primary_navigation.dart';

void main() {
  testWidgets('phone navigation exposes the four approved destinations', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: RhmPrimaryNavigation(
            selectedIndex: selected,
            onDestinationSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('المحادثات'), findsOneWidget);
    expect(find.text('المشاريع'), findsOneWidget);
    expect(find.text('النشاط'), findsOneWidget);
    expect(find.text('المزيد'), findsOneWidget);
    expect(find.text('MCP'), findsNothing);

    await tester.tap(find.text('المشاريع'));
    expect(selected, 1);
    await tester.tap(find.text('النشاط'));
    expect(selected, 2);
    await tester.tap(find.text('المزيد'));
    expect(selected, 3);
    await tester.tap(find.text('المحادثات'));
    expect(selected, 0);
  });

  testWidgets('wide navigation uses a NavigationRail with four destinations', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RhmPrimaryNavigation(
            selectedIndex: selected,
            onDestinationSelected: (value) => selected = value,
            useRail: true,
          ),
        ),
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).destinations.length, 4);
    await tester.tap(find.byIcon(Icons.folder_outlined));
    expect(selected, 1);
  });
}
