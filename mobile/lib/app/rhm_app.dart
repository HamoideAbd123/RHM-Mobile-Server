import 'package:material_ui/material_ui.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/chat/chat_screen.dart';
import '../legacy_material_compatibility.dart';
import '../rhm_theme.dart';

class RhmApp extends StatefulWidget {
  const RhmApp({super.key});

  @override
  State<RhmApp> createState() => _RhmAppState();
}

class _RhmAppState extends State<RhmApp> {
  static const _themeModeKey = 'rhm_theme_mode';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      migrateOnAlgorithmChange: true,
      migrateWithBackup: true,
    ),
  );

  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreThemeMode());
  }

  Future<void> _restoreThemeMode() async {
    try {
      final saved = await _storage.read(key: _themeModeKey);
      final restored = switch (saved) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.dark,
      };
      if (mounted) setState(() => _themeMode = restored);
    } catch (error) {
      debugPrint('RHM appearance preference could not be restored: $error');
    }
  }

  Future<void> _setThemeMode(ThemeMode value) async {
    setState(() => _themeMode = value);
    final storedValue = switch (value) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
    try {
      await _storage.write(key: _themeModeKey, value: storedValue);
    } catch (error) {
      debugPrint('RHM appearance preference could not be saved: $error');
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'RHM',
        debugShowCheckedModeBanner: false,
        theme: RhmTheme.light,
        darkTheme: RhmTheme.dark,
        themeMode: _themeMode,
        builder: (context, child) => wrapLegacyMaterialWidgets(child!),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ChatScreen(
            themeMode: _themeMode,
            onThemeModeChanged: _setThemeMode,
          ),
        ),
      );
}
