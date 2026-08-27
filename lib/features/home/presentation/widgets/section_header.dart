import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A titled section header used above each Home feed.
///
/// Under the Home screen's RTL layout the title sits on the right and the
/// optional "see all" action on the left, matching the reference design.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.seeAllLabel = 'عرض المزيد',
  });

  final String title;
  final VoidCallback? onSeeAll;
  final String seeAllLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                seeAllLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
