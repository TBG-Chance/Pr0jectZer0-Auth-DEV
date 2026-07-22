import 'package:flutter/material.dart';

import '../../core/enrollment/enrollment_models.dart';
import '../../core/models/trusted_system.dart';
import '../../core/services/app_services.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/product_mark.dart';
import '../../shared/widgets/pz_button.dart';
import '../../shared/widgets/pz_card.dart';
import '../enrollment/enrollment_scanner_screen.dart';

class ServersScreen extends StatefulWidget {
  const ServersScreen({super.key});

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  Future<void> _enroll() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const EnrollmentScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enrollment = AppServices.of(context).enrollment;
    return StreamBuilder<EnrollmentSnapshot>(
      stream: enrollment.changes,
      initialData: enrollment.snapshot,
      builder: (context, snapshot) {
        final systems = snapshot.data?.trustedSystems ?? const <TrustedSystem>[];
        return AppPage(
          title: 'My Servers',
          actions: [
            IconButton(
              tooltip: 'Enroll trusted system',
              onPressed: _enroll,
              icon: const Icon(Icons.add_link),
            ),
          ],
          child: systems.isEmpty ? _EmptyState(onEnroll: _enroll) : _SystemList(systems: systems),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onEnroll});

  final VoidCallback onEnroll;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
        child: PZCard(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ProductMark(size: 82),
              const SizedBox(height: 26),
              const Text(
                'No enrolled servers',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              const Text(
                'Scan a trusted-system invitation to begin secure enrollment.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 200,
                child: PZButton(
                  text: 'Enroll Server',
                  icon: Icons.qr_code_scanner,
                  onPressed: onEnroll,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemList extends StatelessWidget {
  const _SystemList({required this.systems});

  final List<TrustedSystem> systems;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: systems.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final system = systems[index];
        return PZCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              system.trusted ? Icons.verified_user : Icons.gpp_maybe_outlined,
              size: 36,
            ),
            title: Text(system.displayName),
            subtitle: Text('${system.organization}\n${system.serverBaseUrl}'),
            isThreeLine: true,
            trailing: Text(system.trusted ? 'Trusted' : 'Pending'),
          ),
        );
      },
    );
  }
}
