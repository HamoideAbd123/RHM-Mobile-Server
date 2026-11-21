import 'package:material_ui/material_ui.dart';

/// Bridges theme and localization data for dependencies that still use the
/// legacy Flutter Material library.
///
/// TODO: Remove this wrapper once flutter_markdown_plus migrates to
/// package:material_ui.
Widget wrapLegacyMaterialWidgets(Widget child) {
  // flutter_markdown_plus 1.0.12 still reads the legacy Material context.
  // This is the official temporary bridge; suppress its deprecation only here.
  // ignore: deprecated_member_use
  return MaterialUiCompatibilityBridge(child: child);
}
