import 'package:flutter/material.dart';

import '../../app/constants.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/product_mark.dart';
import '../../shared/widgets/pz_card.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      title: 'About',
      child: SingleChildScrollView(
        child: PZCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductMark(size: 64),
              SizedBox(height: 20),
              Text(
                AppConstants.appName,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
              Text('Version ${AppConstants.version}'),
              SizedBox(height: 20),
              Divider(),
              SizedBox(height: 20),
              Text(AppConstants.tagline, style: TextStyle(fontSize: 16)),
              SizedBox(height: 16),
              Text(
                'A privacy-first authentication application for '
                'Pr0jectZer0 administrators.',
              ),
              SizedBox(height: 16),
              Text(
                'A product of The Bostrom Group.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
