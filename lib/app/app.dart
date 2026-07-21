import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import 'constants.dart';
import 'theme/app_theme.dart';

class Pr0jectZer0AuthApp extends StatelessWidget {
  const Pr0jectZer0AuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}
