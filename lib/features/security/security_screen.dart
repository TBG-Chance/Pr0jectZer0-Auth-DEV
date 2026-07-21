import 'package:flutter/material.dart';

import '../../shared/widgets/app_page.dart';
import 'security_item.dart';

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
