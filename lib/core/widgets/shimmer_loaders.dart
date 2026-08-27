import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer-based loading placeholders that mirror the real content layout, so
/// the transition from Loading → Success feels seamless.
///
/// All variants share a single [Shimmer] configuration via [_shimmer].
class ShimmerLoaders {
  const ShimmerLoaders._();

  static Widget _shimmer({required Widget child}) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF23232E),
      highlightColor: const Color(0xFF33333F),
      child: child,
    );
  }

  static Widget _box({
    double? width,
    double? height,
    double radius = 12,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  /// Horizontal carousel of poster placeholders (Home sections).
  static Widget animeCarousel({double height = 220, int count = 4}) {
    return SizedBox(
      height: height,
      child: _shimmer(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _box(width: 140, radius: 14)),
              const SizedBox(height: 8),
              _box(width: 110, height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Grid of poster placeholders (Favorites screen).
  static Widget animeGrid({int count = 6}) {
    return _shimmer(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 170,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
        itemCount: count,
        itemBuilder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _box(radius: 14)),
            const SizedBox(height: 8),
            _box(width: 100, height: 12),
          ],
        ),
      ),
    );
  }

  /// Vertical list of episode-row placeholders (Details screen).
  static Widget episodeList({int count = 6}) {
    return _shimmer(
      child: Column(
        children: List.generate(
          count,
          (_) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _box(width: 96, height: 56, radius: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(width: 120, height: 12),
                      const SizedBox(height: 8),
                      _box(width: 180, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
