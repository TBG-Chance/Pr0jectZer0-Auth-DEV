import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class ProductMark extends StatelessWidget {
  final double size;

  const ProductMark({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(size * .25),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(
        Icons.shield_outlined,
        color: AppColors.primary,
        size: size * .55,
      ),
    );
  }
}
