import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

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
        color: passed ? AppColors.success : AppColors.warning,
      ),
      title: Text(label),
      subtitle: Text(passed ? 'Verified' : 'Pending mobile validation'),
    );
  }
}
