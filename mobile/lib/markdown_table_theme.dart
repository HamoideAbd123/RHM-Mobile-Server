import 'package:material_ui/material_ui.dart';

/// Preserves the visible cell grid used by assistant Markdown tables.
TableBorder buildRhmMarkdownTableBorder(ThemeData theme) {
  return TableBorder.all(color: theme.dividerColor);
}
