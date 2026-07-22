import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/enrollment/enrollment_models.dart';
import '../../core/services/app_services.dart';
import '../../shared/widgets/pz_button.dart';
import '../../shared/widgets/pz_card.dart';

class EnrollmentRequestReadyScreen extends StatefulWidget {
  const EnrollmentRequestReadyScreen({
    required this.invitation,
    required this.request,
    super.key,
  });

  final EnrollmentInvitation invitation;
  final DeviceEnrollmentRequest request;

  @override
  State<EnrollmentRequestReadyScreen> createState() =>
      _EnrollmentRequestReadyScreenState();
}

class _EnrollmentRequestReadyScreenState
    extends State<EnrollmentRequestReadyScreen> {
  bool _submitting = false;
  String? _error;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.request.toJsonString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed registration request copied.')),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AppServices.of(context).enrollment.submitEnrollment(
        invitation: widget.invitation,
        request: widget.request,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication device registered.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registration Ready')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: PZCard(
                child: Column(
                  children: [
                    const Icon(Icons.task_alt, size: 68),
                    const SizedBox(height: 18),
                    Text(
                      'Signed request created',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${widget.invitation.displayName} has been validated and the device registration request is ready.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    _Summary(
                      label: 'Key ID',
                      value: widget.request.publicKey.keyId,
                    ),
                    _Summary(
                      label: 'Server',
                      value: widget.invitation.serverBaseUrl.toString(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'The server will assign the authoritative device ID. The app will only trust this system after the server confirms registration.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: PZButton(
                        text: _submitting ? 'Registering…' : 'Register Device',
                        icon: Icons.verified_user_outlined,
                        onPressed: _submitting ? null : _submit,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _submitting ? null : () => _copy(context),
                        child: const Text('Copy Signed Request'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () async {
                          await AppServices.of(
                            context,
                          ).enrollment.cancelPendingEnrollment();
                          if (!context.mounted) return;
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
