import 'package:flutter/material.dart';

import '../../core/services/app_services.dart';
import 'device_status_banner.dart';

class AppPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;

  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...actions,
              ],
            ),

            const SizedBox(height: 16),

            EnrollmentStatusBanner(
              enrollment: AppServices.of(context).enrollment,
            ),

            const SizedBox(height: 24),

            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
