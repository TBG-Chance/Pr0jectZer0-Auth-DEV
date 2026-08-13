import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../core/device_security/device_security_models.dart';
import '../../core/services/app_services.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/pz_card.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  DeviceSecurityReport? _report;
  bool _loading = true;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_report == null && _loading) _load();
  }

  Future<void> _load() async {
    try {
      final report = await AppServices.of(context).deviceSecurity.refresh();
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _copyReport() async {
    final report = _report;
    if (report == null) return;
    await Clipboard.setData(ClipboardData(text: report.toSupportReport()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Support report copied.')));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Diagnostics',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading
              ? null
              : () {
                  setState(() => _loading = true);
                  _load();
                },
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Unable to read device security: $_error'))
          : SingleChildScrollView(
              child: Column(
                children: [
                  PZCard(
                    child: Column(
                      children: [
                        _DiagnosticItem(
                          label: 'Platform',
                          value: _report!.platform,
                        ),
                        _DiagnosticItem(
                          label: 'Device',
                          value: _report!.deviceName,
                        ),
                        _DiagnosticItem(
                          label: 'Operating system',
                          value: _report!.osVersion,
                        ),
                        _DiagnosticItem(
                          label: 'App version',
                          value:
                              '${_report!.appVersion} (${_report!.buildNumber})',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  PZCard(
                    child: Column(
                      children: _report!.checks
                          .map(
                            (check) => _DiagnosticItem(
                              label: check.name,
                              value: check.status.name,
                              status: check.status,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _copyReport,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Support Report'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The report excludes PINs, private keys, tokens, and server secrets.',
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

class _DiagnosticItem extends StatelessWidget {
  const _DiagnosticItem({
    required this.label,
    required this.value,
    this.status,
  });
  final String label;
  final String value;
  final SecurityCheckStatus? status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SecurityCheckStatus.passed => AppColors.success,
      SecurityCheckStatus.failed => AppColors.danger,
      SecurityCheckStatus.unavailable => AppColors.warning,
      SecurityCheckStatus.unknown => AppColors.textSecondary,
      null => AppColors.textPrimary,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}
