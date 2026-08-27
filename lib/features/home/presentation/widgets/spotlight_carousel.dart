import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/anime.dart';

/// A large, swipeable spotlight banner at the top of the Home screen.
///
/// Shows a handful of highlighted titles as full-bleed cover art with a
/// bottom gradient scrim, the title overlaid, and a row of page dots (the
/// active one tinted with the amber [AppTheme.accent]). Tapping a page opens
/// that title's details.
class SpotlightCarousel extends StatefulWidget {
  const SpotlightCarousel({
    super.key,
    required this.items,
    required this.onTap,
    this.height = 230,
  });

  final List<Anime> items;
  final void Function(Anime anime) onTap;
  final double height;

  @override
  State<SpotlightCarousel> createState() => _SpotlightCarouselState();
}

class _SpotlightCarouselState extends State<SpotlightCarousel> {
  static const _viewport = 0.9;

  late final PageController _controller =
      PageController(viewportFraction: _viewport);
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items.take(8).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => _SpotlightPage(
              anime: items[i],
              onTap: () => widget.onTap(items[i]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < items.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _current ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _current ? AppTheme.accent : Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SpotlightPage extends StatelessWidget {
  const _SpotlightPage({required this.anime, required this.onTap});

  final Anime anime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (anime.coverUrl.isEmpty)
                const ColoredBox(color: Colors.white10)
              else
                CachedNetworkImage(
                  imageUrl: anime.coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const ColoredBox(color: Colors.white10),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: Colors.white10),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black87,
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Text(
                  anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    shadows: [
                      Shadow(blurRadius: 8, color: Colors.black),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
