import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/authentication_models.dart';
import '../../core/login/login_models.dart';
import '../../core/services/app_services.dart';
import '../../shared/widgets/pz_card.dart';

class LoginApprovalScreen extends StatefulWidget {
  const LoginApprovalScreen({required this.challenge, super.key});

  final DashboardLoginChallenge challenge;

  @override
  State<LoginApprovalScreen> createState() => _LoginApprovalScreenState();
}

class _LoginApprovalScreenState extends State<LoginApprovalScreen> {
  bool _processing = false;
  String? _error;

  Future<void> _approve() async {
    setState(() {
      _processing = true;
      _error = null;
    });
    final services = AppServices.of(context);
    final authentication = services.authentication;
    final login = services.login;
    try {
      final method = await _authenticate();
      if (method == null) {
        if (mounted) setState(() => _processing = false);
        return;
      }
      await login.approve(widget.challenge);
      await authentication.lock();
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dashboard login approved with ${method.name}.'),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on Object catch (error) {
      await authentication.lock();
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = error.toString();
      });
    }
  }

  Future<AuthenticationMethod?> _authenticate() async {
    final authentication = AppServices.of(context).authentication;
    final biometricResult = await authentication.authenticateWithBiometrics();
    if (biometricResult.success) return AuthenticationMethod.biometric;
    if (!mounted) return null;
    final hasPin = await authentication.hasPin();
    if (!mounted) return null;
    if (!hasPin) {
      setState(() {
        _error =
            'Biometrics were unavailable. Create an app PIN before approving dashboard access.';
      });
      return null;
    }

    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Use app PIN'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 12,
          onSubmitted: (value) => Navigator.of(context).pop(value),
          decoration: const InputDecoration(
            labelText: 'PIN',
            helperText: 'Biometric approval was unavailable or cancelled.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (pin == null || pin.isEmpty) return null;
    final result = await authentication.authenticateWithPin(pin);
    if (!result.success) {
      if (mounted) {
        setState(() => _error = result.message ?? 'The PIN was not accepted.');
      }
      return null;
    }
    return AuthenticationMethod.pin;
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Dashboard Login')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: PZCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.phonelink_lock, size: 64),
                    const SizedBox(height: 18),
                    Text(
                      'Approve dashboard access?',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 20),
                    _Detail(
                      label: 'Server',
                      value: challenge.trustedSystem.displayName,
                    ),
                    _Detail(
                      label: 'Organization',
                      value: challenge.trustedSystem.organization,
                    ),
                    _Detail(
                      label: 'Address',
                      value: challenge.trustedSystem.serverBaseUrl,
                    ),
                    if (challenge.hasBrowserContext) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            const Text('Compare with the browser'),
                            const SizedBox(height: 6),
                            SelectableText(
                              _formatCode(challenge.verificationCode),
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 5,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Detail(
                        label: 'Browser',
                        value:
                            '${challenge.browserName} on ${challenge.operatingSystem}',
                      ),
                      _Detail(
                        label: 'Network',
                        value: challenge.networkAddress,
                      ),
                      _Detail(
                        label: 'Requested',
                        value: challenge.requestedAt.toLocal().toString(),
                      ),
                    ],
                    _Detail(
                      label: 'Expires',
                      value: challenge.expiresAt.toLocal().toString(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      challenge.hasBrowserContext
                          ? 'Approve only if you started this sign-in and the six-digit code matches the browser. Deny the request if any detail is unfamiliar.'
                          : 'This older login code does not include browser comparison details. Approve only if you started this sign-in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'PZ Auth will require biometrics or your local app PIN, then sign this one-time challenge. Your PIN and private key never leave this device.',
                      textAlign: TextAlign.center,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _processing ? null : _approve,
                      icon: _processing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fingerprint),
                      label: Text(
                        _processing ? 'Authorizing…' : 'Approve securely',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _processing
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Deny'),
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

  String _formatCode(String value) {
    if (value.length != 6) return value;
    return '${value.substring(0, 3)} ${value.substring(3)}';
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
