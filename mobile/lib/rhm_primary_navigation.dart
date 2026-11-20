import 'package:material_ui/material_ui.dart';

class RhmPrimaryNavigation extends StatelessWidget {
  const RhmPrimaryNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.useRail = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool useRail;

  static const _items = [
    (
      icon: Icons.chat_bubble_outline_rounded,
      selected: Icons.chat_rounded,
      label: 'المحادثات',
    ),
    (
      icon: Icons.folder_outlined,
      selected: Icons.folder_rounded,
      label: 'المشاريع',
    ),
    (
      icon: Icons.bolt_outlined,
      selected: Icons.bolt_rounded,
      label: 'النشاط',
    ),
    (
      icon: Icons.grid_view_outlined,
      selected: Icons.grid_view_rounded,
      label: 'المزيد',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (useRail) {
      return NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        labelType: NavigationRailLabelType.all,
        destinations: [
          for (final item in _items)
            NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selected),
              label: Text(item.label),
            ),
        ],
      );
    }

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: [
        for (final item in _items)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selected),
            label: item.label,
          ),
      ],
    );
  }
}
