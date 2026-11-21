import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'app/rhm_app.dart';
import 'server_update_notifications.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      initializeRhmBackgroundNotifications().catchError((Object error) {
        debugPrint('RHM background notification setup failed: $error');
      }),
    );
  });
  runApp(const RhmApp());
}
