import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:crisis_link/theme/app_colors.dart';

/// Rectangular shimmer loading placeholder
class ShimmerCard extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const ShimmerCard({
    super.key,
    this.height = 100,
    this.width,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: AppColors.shimmerBase,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Column of multiple shimmer card placeholders
class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final double spacing;

  const ShimmerList({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 80,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index < itemCount - 1 ? spacing : 0),
          child: ShimmerCard(height: itemHeight),
        ),
      ),
    );
  }
}

/// Circular shimmer loading placeholder
class ShimmerCircle extends StatelessWidget {
  final double size;

  const ShimmerCircle({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.shimmerBase,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Dashboard-style shimmer loading layout
class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerCard(height: 24, width: 200),
          const SizedBox(height: 8),
          const ShimmerCard(height: 14, width: 140),
          const SizedBox(height: 20),
          const ShimmerCard(height: 80),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ShimmerCard(height: 100)),
              const SizedBox(width: 12),
              Expanded(child: ShimmerCard(height: 100)),
              const SizedBox(width: 12),
              Expanded(child: ShimmerCard(height: 100)),
            ],
          ),
          const SizedBox(height: 16),
          const ShimmerCard(height: 250),
          const SizedBox(height: 16),
          const ShimmerList(itemCount: 3, itemHeight: 72),
        ],
      ),
    );
  }
}
