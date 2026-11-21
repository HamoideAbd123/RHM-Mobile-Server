import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhm_mobile/settings_screen.dart';

void main() {
  testWidgets('settings remain accessible when the backend is offline', (tester) async {
    var connectionOpened = false;
    var voiceDiagnosticsOpened = false;
    ThemeMode? selectedThemeMode;

    await tester.pumpWidget(
      MaterialApp(
        home: RhmSettingsScreen(
          serverUrl: 'http://127.0.0.1:8000',
          connectionReady: false,
          providers: const [],
          preferredProvider: null,
          preferredModel: null,
          locale: 'ar-SA',
          offlineRecognition: false,
          themeMode: ThemeMode.dark,
          onOpenConnectionSettings: () => connectionOpened = true,
          onOpenAndroidRuntime: () {},
          onOpenVoiceDiagnostics: () => voiceDiagnosticsOpened = true,
          onCheckAppUpdates: () {},
          onProviderChanged: (_) {},
          onModelChanged: (_) {},
          onLocaleChanged: (_) {},
          onOfflineRecognitionChanged: (_) {},
          onThemeModeChanged: (value) => selectedThemeMode = value,
        ),
      ),
    );

    expect(find.text('إعدادات RHM'), findsOneWidget);
    expect(find.text('الخادم غير متصل'), findsOneWidget);
    expect(find.text('http://127.0.0.1:8000'), findsOneWidget);
    expect(find.text('سمة التطبيق'), findsOneWidget);
    expect(find.text('تتطابق ألوان الهاتف مع نظام RHM على الويب.'), findsOneWidget);
    expect(find.text('داكن'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فاتح').last);
    await tester.pumpAndSettle();
    expect(selectedThemeMode, ThemeMode.light);

    await tester.tap(find.text('الخادم غير متصل'));
    expect(connectionOpened, isTrue);

    final settingsScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('التعرّف دون اتصال'),
      240,
      scrollable: settingsScrollable,
    );
    expect(find.text('التعرّف دون اتصال'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('تشخيص الصوت'),
      180,
      scrollable: settingsScrollable,
    );
    await tester.ensureVisible(find.text('تشخيص الصوت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تشخيص الصوت'));
    expect(voiceDiagnosticsOpened, isTrue);
  });
}
