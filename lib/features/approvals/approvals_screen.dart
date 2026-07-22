import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/approval/approval_models.dart';
import '../../core/services/app_services.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/pz_card.dart';
import 'approval_detail_screen.dart';
import 'login_scanner_screen.dart';

class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final approval = AppServices.of(context).approval;
    return StreamBuilder<ApprovalSnapshot>(
      stream: approval.changes,
      initialData: approval.snapshot,
      builder: (context, snapshot) {
        final data = snapshot.data ?? approval.snapshot;
        return AppPage(
          title: 'Approvals',
          actions: [
            IconButton(
              tooltip: 'Scan dashboard login',
              onPressed: () => _scanLogin(context),
              icon: const Icon(Icons.qr_code_scanner),
            ),
            if (kDebugMode)
              IconButton(
                tooltip: 'Add test approval',
                onPressed: () => _addTestRequest(context),
                icon: const Icon(Icons.add_task),
              ),
          ],
          child: RefreshIndicator(
            onRefresh: approval.removeExpiredRequests,
            child: data.pendingRequests.isEmpty
                ? _EmptyApprovals(
                    queuedCount: data.queuedResponses.length,
                    onScan: () => _scanLogin(context),
                  )
                : _ApprovalList(
                    requests: data.pendingRequests,
                    queuedCount: data.queuedResponses
                        .where(
                          (item) =>
                              item.syncStatus != ApprovalSyncStatus.synced,
                        )
                        .length,
                  ),
          ),
        );
      },
    );
  }

  void _scanLogin(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginScannerScreen()),
    );
  }

  Future<void> _addTestRequest(BuildContext context) async {
    final now = DateTime.now().toUtc();
    await AppServices.of(context).approval.receiveRequest(
      ApprovalRequest(
        id: 'debug-${now.microsecondsSinceEpoch}',
        systemId: 'pr0jectzer0-local',
        systemName: 'Pr0jectZer0',
        organization: 'The Bostrom Group',
        title: 'Approve administrative sign-in',
        description:
            'A user is requesting access to the local Pr0jectZer0 management console.',
        requestedBy: 'administrator',
        requestingDevice: 'Windows Console',
        sourceIp: '192.168.1.25',
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
        nonce: 'debug-${now.microsecondsSinceEpoch}',
        risk: ApprovalRisk.high,
      ),
    );
  }
}

class _ApprovalList extends StatelessWidget {
  const _ApprovalList({required this.requests, required this.queuedCount});

  final List<ApprovalRequest> requests;
  final int queuedCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (queuedCount > 0) ...[
          PZCard(
            child: Row(
              children: [
                const Icon(Icons.cloud_upload_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$queuedCount signed decision${queuedCount == 1 ? '' : 's'} pending synchronization',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (final request in requests) ...[
          _ApprovalCard(request: request),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.request});

  final ApprovalRequest request;

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(request.risk);
    final remaining = request.expiresAt.difference(DateTime.now().toUtc());
    final minutes = remaining.inMinutes.clamp(0, 999);
    return PZCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ApprovalDetailScreen(requestId: request.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 88,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text('${request.organization} • ${request.systemName}'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _RiskChip(risk: request.risk),
                        const SizedBox(width: 10),
                        Icon(Icons.timer_outlined, size: 16, color: color),
                        const SizedBox(width: 4),
                        Text(minutes == 0 ? '< 1 min' : '$minutes min'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyApprovals extends StatelessWidget {
  const _EmptyApprovals({required this.queuedCount, required this.onScan});

  final int queuedCount;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: PZCard(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 34),
              child: Column(
                children: [
                  const Icon(
                    Icons.task_alt,
                    size: 64,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No pending approvals',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    queuedCount > 0
                        ? '$queuedCount signed decision${queuedCount == 1 ? ' is' : 's are'} waiting to synchronize.'
                        : 'New trusted-system requests will appear here.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onScan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan dashboard login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RiskChip extends StatelessWidget {
  const _RiskChip({required this.risk});

  final ApprovalRisk risk;

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(risk);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .5)),
      ),
      child: Text(
        risk.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Color _riskColor(ApprovalRisk risk) => switch (risk) {
  ApprovalRisk.low => AppColors.success,
  ApprovalRisk.medium => AppColors.warning,
  ApprovalRisk.high => const Color(0xFFFF8C42),
  ApprovalRisk.critical => AppColors.danger,
};
