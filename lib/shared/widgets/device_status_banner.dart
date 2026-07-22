import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/enrollment/enrollment_models.dart';
import '../../core/enrollment/enrollment_service.dart';

enum DeviceStatus {
  notEnrolled,
  trusted,
  screenLockRequired,
  requirementsNotMet,
}

class EnrollmentStatusBanner extends StatelessWidget {
  const EnrollmentStatusBanner({super.key, required this.enrollment});

  final EnrollmentService enrollment;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EnrollmentSnapshot>(
      stream: enrollment.changes,
      initialData: enrollment.snapshot,
      builder: (context, snapshot) {
        final enrolled = (snapshot.data ?? enrollment.snapshot).isEnrolled;
        return DeviceStatusBanner(
          status: enrolled ? DeviceStatus.trusted : DeviceStatus.notEnrolled,
        );
      },
    );
  }
}

class DeviceStatusBanner extends StatelessWidget {
  final DeviceStatus status;

  const DeviceStatusBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final IconData icon;
    late final String title;
    late final String subtitle;

    switch (status) {
      case DeviceStatus.notEnrolled:
        color = AppColors.warning;
        icon = Icons.phone_android;
        title = "Device Not Enrolled";
        subtitle = "Scan a Pr0jectZer0 enrollment QR code.";
        break;

      case DeviceStatus.trusted:
        color = AppColors.success;
        icon = Icons.verified_user;
        title = "Trusted Device";
        subtitle = "This device is trusted for authentication.";
        break;

      case DeviceStatus.screenLockRequired:
        color = AppColors.warning;
        icon = Icons.lock_outline;
        title = "Screen Lock Required";
        subtitle = "Enable a secure screen lock before enrollment.";
        break;

      case DeviceStatus.requirementsNotMet:
        color = AppColors.danger;
        icon = Icons.error_outline;
        title = "Security Requirements Not Met";
        subtitle = "This device cannot be used until requirements are met.";
        break;
    }

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
