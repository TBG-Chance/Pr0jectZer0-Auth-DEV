import 'package:flutter/material.dart';

import '../../core/device_security/device_security_models.dart';
import '../../core/services/app_services.dart';
import '../../shared/widgets/app_page.dart';
import 'security_item.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  DeviceSecurityReport? _report;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _report ??= AppServices.of(context).deviceSecurity.currentReport;
    if (_report == null) _refresh();
  }

  Future<void> _refresh() async {
    final report = await AppServices.of(context).deviceSecurity.refresh();
    if (mounted) setState(() => _report = report);
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return AppPage(
      title: 'Security Status',
      actions: [
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
      child: report == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: report.checks
                  .map(
                    (check) => SecurityItem(
                      check.name,
                      check.status,
                      detail: check.detail,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
