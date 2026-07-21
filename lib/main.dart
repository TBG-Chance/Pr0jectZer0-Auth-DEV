import 'package:flutter/material.dart';
import 'app/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Pr0jectZer0AuthApp());
}

class Pr0jectZer0AuthApp extends StatelessWidget {
  const Pr0jectZer0AuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pr0jectZer0 Auth',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  static const List<Widget> screens = [
    ServersScreen(),
    SecurityScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Desktop / Tablet
          if (constraints.maxWidth >= 800) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => selectedIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dns_outlined),
                      selectedIcon: Icon(Icons.dns),
                      label: Text('Servers'),
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
                Expanded(child: screens[selectedIndex]),
              ],
            );
          }

          // Mobile
          return Scaffold(
            body: screens[selectedIndex],
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                setState(() => selectedIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dns_outlined),
                  selectedIcon: Icon(Icons.dns),
                  label: 'Servers',
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
      ),
    );
  }
}

class ServersScreen extends StatelessWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      title: 'My Servers',
      child: Center(
        child: Text('No enrolled servers', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      title: 'Security Status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SecurityItem('Screen lock required', false),
          SecurityItem('Biometrics available', false),
          SecurityItem('Secure key storage', false),
          SecurityItem('Private keys non-exportable', false),
          SecurityItem('Telemetry disabled', true),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      title: 'Settings',
      child: Text('Pr0jectZer0 Auth\nVersion 0.1.0'),
    );
  }
}

class AppPage extends StatelessWidget {
  final String title;
  final Widget child;

  const AppPage({required this.title, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class SecurityItem extends StatelessWidget {
  final String label;
  final bool passed;

  const SecurityItem(this.label, this.passed, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        passed ? Icons.check_circle : Icons.pending_outlined,
        color: passed ? Colors.green : Colors.orange,
      ),
      title: Text(label),
      subtitle: Text(passed ? 'Verified' : 'Pending mobile validation'),
    );
  }
}
