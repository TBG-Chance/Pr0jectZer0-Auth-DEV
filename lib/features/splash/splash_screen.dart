import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/constants.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/widgets/product_mark.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (_, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProductMark(size: 92),
              SizedBox(height: 26),
              Text(
                AppConstants.productName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'AUTH',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 5,
                ),
              ),
              SizedBox(height: 18),
              Text(
                AppConstants.tagline,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              SizedBox(height: 28),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 18),
              Text(
                'Version ${AppConstants.version}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
