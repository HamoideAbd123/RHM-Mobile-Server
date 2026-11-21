import 'package:material_ui/material_ui.dart';

import '../rhm_theme.dart';

class RhmSuggestionChip extends StatelessWidget {
  const RhmSuggestionChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
        onPressed: onTap,
        avatar: Icon(
          icon,
          size: 17,
          color: Theme.of(context).colorScheme.primary,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        side: BorderSide(
          color: Theme.of(context).extension<RhmUiTokens>()!.border,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      );
}
