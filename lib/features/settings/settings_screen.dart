import 'package:flutter/material.dart';

import '../about/about_screen.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../../app/constants.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/product_mark.dart';
import '../../shared/widgets/pz_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Settings',
      child: ListView(
        children: [
          const PZCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductMark(size: 56),
                SizedBox(height: 20),
                Text(
                  AppConstants.appName,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text('Version ${AppConstants.version}'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              subtitle: const Text('Application information'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const Icon(Icons.medical_information_outlined),
              title: const Text('Diagnostics'),
              subtitle: const Text('Support and security information'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
