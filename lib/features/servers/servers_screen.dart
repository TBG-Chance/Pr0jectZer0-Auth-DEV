import 'package:flutter/material.dart';

import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/product_mark.dart';
import '../../shared/widgets/pz_button.dart';
import '../../shared/widgets/pz_card.dart';

class ServersScreen extends StatelessWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'My Servers',
      child: Center(
        child: PZCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ProductMark(size: 72),
              const SizedBox(height: 20),
              const Text(
                'No enrolled servers',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enroll your first Pr0jectZer0 server.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              PZButton(
                text: 'Enroll Server',
                icon: Icons.qr_code_scanner,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
