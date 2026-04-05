import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class SkeletonCard extends StatelessWidget {
  final double? height;
  final EdgeInsets? margin;

  const SkeletonCard({
    super.key,
    this.height,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Skeletonizer(
      child: Container(
        height: height ?? 120,
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8),
              SizedBox(height: 8),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
