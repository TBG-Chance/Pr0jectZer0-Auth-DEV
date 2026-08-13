import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/device_security/device_security_models.dart';

class SecurityItem extends StatelessWidget {
  const SecurityItem(
    this.label,
    this.status, {
    required this.detail,
    super.key,
  });

  final String label;
  final SecurityCheckStatus status;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final (icon, color, state) = switch (status) {
      SecurityCheckStatus.passed => (
        Icons.check_circle,
        AppColors.success,
        'Verified',
      ),
      SecurityCheckStatus.failed => (
        Icons.cancel,
        AppColors.danger,
        'Action required',
      ),
      SecurityCheckStatus.unavailable => (
        Icons.block,
        AppColors.warning,
        'Unavailable',
      ),
      SecurityCheckStatus.unknown => (
        Icons.help_outline,
        AppColors.textSecondary,
        'Unknown',
      ),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label),
      subtitle: Text('$state — $detail'),
    );
  }
}
