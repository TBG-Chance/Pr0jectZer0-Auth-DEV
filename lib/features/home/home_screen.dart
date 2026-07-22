import 'package:flutter/material.dart';

import '../approvals/approvals_screen.dart';
import '../security/security_screen.dart';
import '../servers/servers_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  static const List<Widget> screens = [
    ServersScreen(),
    ApprovalsScreen(),
    SecurityScreen(),
    SettingsScreen(),
  ];

  void _selectPage(int index) {
    if (index == selectedIndex) return;

    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 850;

        Widget page = AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(.03, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(selectedIndex),
            child: screens[selectedIndex],
          ),
        );

        if (desktop) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: _selectPage,
                  extended: true,
                  labelType: NavigationRailLabelType.none,
                  groupAlignment: -0.9,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dns_outlined),
                      selectedIcon: Icon(Icons.dns),
                      label: Text('Servers'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.approval_outlined),
                      selectedIcon: Icon(Icons.approval),
                      label: Text('Approvals'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.verified_user_outlined),
                      selectedIcon: Icon(Icons.verified_user),
                      label: Text('Security'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Settings'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: page),
              ],
            ),
          );
        }

        return Scaffold(
          body: page,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: _selectPage,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dns_outlined),
                selectedIcon: Icon(Icons.dns),
                label: 'Servers',
              ),
              NavigationDestination(
                icon: Icon(Icons.approval_outlined),
                selectedIcon: Icon(Icons.approval),
                label: 'Approvals',
              ),
              NavigationDestination(
                icon: Icon(Icons.verified_user_outlined),
                selectedIcon: Icon(Icons.verified_user),
                label: 'Security',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}
