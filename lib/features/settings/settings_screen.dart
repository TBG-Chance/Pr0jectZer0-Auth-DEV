import 'package:flutter/material.dart';

import '../../app/constants.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/product_mark.dart';
import '../../shared/widgets/pz_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      title: 'Settings',
      child: PZCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductMark(size: 56),
            SizedBox(height: 20),
            Text(
              AppConstants.appName,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('Version ${AppConstants.version}'),
            SizedBox(height: 20),
            Divider(),
            SizedBox(height: 10),
            Text(AppConstants.tagline, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
