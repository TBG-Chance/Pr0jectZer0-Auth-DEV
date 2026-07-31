import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/auth/pin_policy.dart';
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
  bool _fingerprintConfirmed = false;
  String? _error;
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() {
      _preparing = true;
      _error = null;
    });

    try {
      String? activationPin;
      if (widget.invitation.requiresActivationPin) {
        activationPin = _pinController.text;
        final pinError = PinPolicy.validate(activationPin);
        if (pinError != null) {
          throw EnrollmentException(pinError);
        }
        if (activationPin != _confirmPinController.text) {
          throw const EnrollmentException('PIN confirmation does not match.');
        }
      }
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
            activationPin: activationPin,
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
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(invitation.organization),
                    const SizedBox(height: 24),
                    _Detail(label: 'Product', value: invitation.productType),
                    _Detail(
                      label: 'Server',
                      value: invitation.serverBaseUrl.toString(),
                    ),
                    _Detail(label: 'System ID', value: invitation.systemId),
                    if (invitation.requiresActivationPin) ...[
                      _Detail(
                        label: 'Action',
                        value:
                            invitation.purpose ==
                                EnrollmentPurpose.lostDeviceRecovery
                            ? 'Recover administrator access'
                            : 'Activate administrator account',
                      ),
                      _Detail(
                        label: 'Administrator',
                        value:
                            '${invitation.administratorFirstName} ${invitation.administratorLastName}',
                      ),
                      _Detail(
                        label: 'Role',
                        value: invitation.administratorRole ?? '',
                      ),
                    ],
                    _Detail(
                      label: 'Expires',
                      value: invitation.expiresAt.toLocal().toString(),
                    ),
                    if (invitation.serverFingerprint != null)
                      _Detail(
                        label: 'Server identity fingerprint',
                        value: _formatFingerprint(
                          invitation.serverFingerprint!,
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      invitation.requiresActivationPin
                          ? 'Continuing registers this phone and sends the new administrator PIN only to the verified server over HTTPS. The private key never leaves this device.'
                          : 'Continuing creates or reuses this device’s cryptographic identity and signs a registration request. No PIN or private key leaves this device.',
                    ),
                    if (invitation.requiresActivationPin) ...[
                      const SizedBox(height: 18),
                      TextField(
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: PinPolicy.maximumLength,
                        autofillHints: const <String>[
                          AutofillHints.newPassword,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'New administrator PIN',
                          helperText:
                              'Use 6–12 digits; avoid repeated or sequential numbers.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _confirmPinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: PinPolicy.maximumLength,
                        decoration: const InputDecoration(
                          labelText: 'Confirm administrator PIN',
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _fingerprintConfirmed,
                      onChanged: _preparing
                          ? null
                          : (value) => setState(
                              () => _fingerprintConfirmed = value ?? false,
                            ),
                      title: const Text(
                        'I confirmed this fingerprint on the Pr0jectZer0 server.',
                      ),
                      subtitle: const Text(
                        'Do not continue if the server displays a different fingerprint.',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
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
                                    await AppServices.of(
                                      context,
                                    ).enrollment.cancelPendingEnrollment();
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PZButton(
                            text: invitation.requiresActivationPin
                                ? 'Prepare Activation'
                                : 'Create Request',
                            icon: Icons.key,
                            onPressed: _preparing || !_fingerprintConfirmed
                                ? null
                                : _continue,
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

  static String _formatFingerprint(String value) {
    final normalized = value.replaceFirst('sha256:', '').toUpperCase();
    final prefix = normalized.length > 20
        ? normalized.substring(0, 20)
        : normalized;
    return List<String>.generate((prefix.length / 4).ceil(), (index) {
      final start = index * 4;
      final end = (start + 4).clamp(0, prefix.length);
      return prefix.substring(start, end);
    }).join('-');
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
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 3),
          SelectableText(value),
        ],
      ),
    );
  }
}
