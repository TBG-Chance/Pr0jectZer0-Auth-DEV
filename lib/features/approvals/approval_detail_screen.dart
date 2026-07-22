import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../core/approval/approval_models.dart';
import '../../core/auth/authentication_models.dart';
import '../../core/services/app_services.dart';
import '../../shared/widgets/pz_card.dart';

class ApprovalDetailScreen extends StatefulWidget {
  const ApprovalDetailScreen({required this.requestId, super.key});

  final String requestId;

  @override
  State<ApprovalDetailScreen> createState() => _ApprovalDetailScreenState();
}

class _ApprovalDetailScreenState extends State<ApprovalDetailScreen> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final approval = AppServices.of(context).approval;
    return StreamBuilder<ApprovalSnapshot>(
      stream: approval.changes,
      initialData: approval.snapshot,
      builder: (context, snapshot) {
        final requests = snapshot.data?.pendingRequests ?? const <ApprovalRequest>[];
        final request = requests.where((item) => item.id == widget.requestId).firstOrNull;
        if (request == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Approval Request')),
            body: const Center(child: Text('This request is no longer pending.')),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Review Request')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _RiskHeader(request: request),
                const SizedBox(height: 16),
                PZCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.title,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Text(request.description),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PZCard(
                  child: Column(
                    children: [
                      _DetailRow(label: 'Organization', value: request.organization),
                      _DetailRow(label: 'Trusted system', value: request.systemName),
                      _DetailRow(label: 'Requested by', value: request.requestedBy),
                      _DetailRow(label: 'Requesting device', value: request.requestingDevice),
                      if (request.sourceIp != null)
                        _DetailRow(label: 'Source IP', value: request.sourceIp!),
                      _DetailRow(label: 'Request ID', value: request.id),
                      _DetailRow(
                        label: 'Expires',
                        value: _formatDate(request.expiresAt),
                        last: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _processing
                            ? null
                            : () => _decide(request, ApprovalDecision.deny),
                        icon: const Icon(Icons.close),
                        label: const Text('Deny'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _processing
                            ? null
                            : () => _decide(request, ApprovalDecision.approve),
                        icon: _processing
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Approve'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your decision is signed on this device. If the server is unavailable, it remains encrypted and pending synchronization.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _decide(ApprovalRequest request, ApprovalDecision decision) async {
    final services = AppServices.of(context);
    var method = services.authentication.currentSession?.method;
    if (!services.authentication.isAuthenticated) {
      method = await _authenticate();
      if (method == null) return;
    }
    setState(() => _processing = true);
    try {
      await services.approval.decide(
        requestId: request.id,
        decision: decision,
        authenticationMethod: (method ?? AuthenticationMethod.pin).name,
      );
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == ApprovalDecision.approve
                ? 'Approval signed and queued.'
                : 'Denial signed and queued.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${error.message}')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<AuthenticationMethod?> _authenticate() async {
    final authentication = AppServices.of(context).authentication;
    if (!await authentication.hasPin()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create an app PIN before approving requests.')),
        );
      }
      return null;
    }
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm your PIN'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 12,
          onSubmitted: (value) => Navigator.of(context).pop(value),
          decoration: const InputDecoration(labelText: 'PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (pin == null || pin.isEmpty) return null;
    final result = await authentication.authenticateWithPin(pin);
    if (!result.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Authentication failed.')),
        );
      }
      return null;
    }
    return AuthenticationMethod.pin;
  }
}

class _RiskHeader extends StatelessWidget {
  const _RiskHeader({required this.request});

  final ApprovalRequest request;

  @override
  Widget build(BuildContext context) {
    final color = switch (request.risk) {
      ApprovalRisk.low => AppColors.success,
      ApprovalRisk.medium => AppColors.warning,
      ApprovalRisk.high => const Color(0xFFFF8C42),
      ApprovalRisk.critical => AppColors.danger,
    };
    return Semantics(
      label: '${request.risk.name} risk approval request',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .55)),
        ),
        child: Row(
          children: [
            Icon(Icons.shield_outlined, color: color),
            const SizedBox(width: 10),
            Text(
              '${request.risk.name.toUpperCase()} RISK',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
