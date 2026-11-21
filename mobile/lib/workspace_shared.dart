import 'package:material_ui/material_ui.dart';

import 'api_client.dart';

String workspaceErrorText(Object error) =>
    error is RhmApiException ? error.message : 'تعذر إكمال العملية.';

Widget workspaceLoadingWidget() =>
    const Center(child: CircularProgressIndicator());

Widget workspaceEmpty(
  BuildContext context,
  String title,
  String subtitle,
  IconData icon,
) => Center(
  child: Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 12),
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      const SizedBox(height: 6),
      Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5)),
    ]),
  ),
);
