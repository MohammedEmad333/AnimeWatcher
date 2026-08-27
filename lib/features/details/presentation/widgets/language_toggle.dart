import 'package:flutter/material.dart';

import '../../../../shared/models/content_language.dart';

/// A custom segmented toggle for choosing the episode language (Arabic /
/// English). Emits the newly-selected [ContentLanguage] via [onChanged].
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ContentLanguage selected;
  final ValueChanged<ContentLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final lang in ContentLanguage.values)
            _Segment(
              label: lang.label,
              isSelected: lang == selected,
              onTap: () => onChanged(lang),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
