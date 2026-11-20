import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhm_mobile/settings_screen.dart';

void main() {
  testWidgets('settings remain accessible when the backend is offline', (tester) async {
    var connectionOpened = false;
    var voiceDiagnosticsOpened = false;

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
          onOpenConnectionSettings: () => connectionOpened = true,
          onOpenVoiceDiagnostics: () => voiceDiagnosticsOpened = true,
          onCheckAppUpdates: () {},
          onProviderChanged: (_) {},
          onModelChanged: (_) {},
          onLocaleChanged: (_) {},
          onOfflineRecognitionChanged: (_) {},
        ),
      ),
    );

    expect(find.text('إعدادات RHM'), findsOneWidget);
    expect(find.text('الخادم غير متصل'), findsOneWidget);
    expect(find.text('http://127.0.0.1:8000'), findsOneWidget);
    expect(find.text('التعرّف دون اتصال'), findsOneWidget);

    await tester.tap(find.text('الخادم غير متصل'));
    expect(connectionOpened, isTrue);

    await tester.ensureVisible(find.text('تشخيص الصوت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تشخيص الصوت'));
    expect(voiceDiagnosticsOpened, isTrue);
  });
}
