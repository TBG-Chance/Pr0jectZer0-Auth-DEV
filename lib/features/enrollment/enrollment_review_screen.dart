import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/enrollment/enrollment_models.dart';
import '../../core/services/app_services.dart';
import '../../shared/widgets/pz_button.dart';
import '../../shared/widgets/pz_card.dart';
import 'enrollment_request_ready_screen.dart';

class EnrollmentReviewScreen extends StatefulWidget {
  const EnrollmentReviewScreen({required this.invitation, super.key});

  final EnrollmentInvitation invitation;

  @override
  State<EnrollmentReviewScreen> createState() => _EnrollmentReviewScreenState();
}

class _EnrollmentReviewScreenState extends State<EnrollmentReviewScreen> {
  bool _preparing = false;
  String? _error;

  Future<void> _continue() async {
    setState(() {
      _preparing = true;
      _error = null;
    });

    try {
      final services = AppServices.of(context);
      final report = await services.deviceSecurity.refresh();
      if (!report.requirementsMet) {
        throw const EnrollmentException(
          'This device does not meet the minimum security requirements.',
        );
      }
      final request = await services.enrollment.prepareEnrollment(
        invitation: widget.invitation,
        deviceName: report.deviceName,
        platform: Platform.operatingSystem,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => EnrollmentRequestReadyScreen(
            invitation: widget.invitation,
            request: request,
          ),
        ),
      );
    } on EnrollmentException catch (error) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _error = error.message;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _error = 'Unable to prepare enrollment: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitation = widget.invitation;
    return Scaffold(
      appBar: AppBar(title: const Text('Review Enrollment')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: PZCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.domain_verification_outlined, size: 48),
                    const SizedBox(height: 18),
                    Text(
                      invitation.displayName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(invitation.organization),
                    const SizedBox(height: 24),
                    _Detail(label: 'Product', value: invitation.productType),
                    _Detail(label: 'Server', value: invitation.serverBaseUrl.toString()),
                    _Detail(label: 'System ID', value: invitation.systemId),
                    _Detail(
                      label: 'Expires',
                      value: invitation.expiresAt.toLocal().toString(),
                    ),
                    if (invitation.serverPublicKey != null)
                      _Detail(
                        label: 'Server key',
                        value: _shorten(invitation.serverPublicKey!),
                      ),
                    const SizedBox(height: 14),
                    const Text(
                      'Continuing creates or reuses this device’s cryptographic identity and signs a registration request. No PIN or private key leaves this device.',
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    if (_preparing) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _preparing
                                ? null
                                : () async {
                                    await AppServices.of(context)
                                        .enrollment
                                        .cancelPendingEnrollment();
                                    if (context.mounted) Navigator.of(context).pop();
                                  },
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PZButton(
                            text: 'Create Request',
                            icon: Icons.key,
                            onPressed: _preparing ? null : _continue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _shorten(String value) {
    if (value.length <= 24) return value;
    return '${value.substring(0, 12)}…${value.substring(value.length - 12)}';
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 3),
          SelectableText(value),
        ],
      ),
    );
  }
}
