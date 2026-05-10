import 'package:flutter/material.dart';

import '../../../../core/constants/ui_constants.dart';

/// A Material3-styled card wrapper for config sections.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: UiConstants.spacingMd,
        vertical: UiConstants.spacingSm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(UiConstants.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: UiConstants.spacingSm),
                ],
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: UiConstants.spacingMd),
            child,
          ],
        ),
      ),
    );
  }
}
