// App shell — the desktop's sectioned navigation, mobile-adapted.
//
// Desktop keeps a left sidebar (Sessions / Projects / Tree) plus a right rail
// of panels. On a phone the same sections live in a persistent bottom bar so
// the app reads as one product with four places to be, not a stack of pushes.
library;

import 'package:flutter/material.dart';

import '../../../core/connection/feature_flags.dart';
import '../../../design/theme.dart';
import '../../cron/screens/cron_screen.dart';
import '../../office/screens/office_screen.dart';
import '../../sessions/screens/home_screen.dart';
import '../../settings/screens/settings_screen.dart';

class AppShell extends StatefulWidget {
  final String activeHostId;
  const AppShell({super.key, required this.activeHostId});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  List<_Destination> get _destinations => [
        const _Destination(
          icon: Icons.forum_outlined,
          selectedIcon: Icons.forum,
          label: 'Sessions',
        ),
        if (FeatureFlags.enableCron)
          const _Destination(
            icon: Icons.schedule_outlined,
            selectedIcon: Icons.schedule,
            label: 'Tasks',
          ),
        if (FeatureFlags.enableOffice)
          const _Destination(
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups,
            label: 'Office',
          ),
        const _Destination(
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          label: 'Settings',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations;
    final index = _index.clamp(0, destinations.length - 1);
    final pages = <Widget>[
      HomeScreen(activeHostId: widget.activeHostId),
      if (FeatureFlags.enableCron) CronScreen(hostId: widget.activeHostId),
      if (FeatureFlags.enableOffice) OfficeScreen(hostId: widget.activeHostId),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: _PiNavBar(
        destinations: destinations,
        index: index,
        onSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _Destination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Desktop-token bottom bar: hairline top border, mono micro labels, accent
/// for the active section (the sidebar's active-row treatment).
class _PiNavBar extends StatelessWidget {
  final List<_Destination> destinations;
  final int index;
  final ValueChanged<int> onSelected;

  const _PiNavBar({
    required this.destinations,
    required this.index,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PiColors.surface,
        border: Border(top: BorderSide(color: PiColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: destinations[i].label,
                    child: InkWell(
                      onTap: () => onSelected(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            i == index
                                ? destinations[i].selectedIcon
                                : destinations[i].icon,
                            size: 19,
                            color: i == index
                                ? PiColors.accent
                                : PiColors.textMuted,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            destinations[i].label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              height: 1.2,
                              fontFamily: PiFonts.mono,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                              color: i == index
                                  ? PiColors.accent
                                  : PiColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
