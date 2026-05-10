import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/ui_constants.dart';
import '../providers/config_providers.dart';
import 'section_card.dart';

/// Theme color and mode selection section.
class ThemeSection extends ConsumerWidget {
  const ThemeSection({super.key});

  static const _modes = [
    ('system', '跟随系统', Icons.brightness_auto),
    ('light', '浅色', Icons.light_mode),
    ('dark', '深色', Icons.dark_mode),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(configProvider);
    final config = configAsync.valueOrNull;
    if (config == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final currentColor = Color(config.seedColor);
    final currentMode = config.themeMode;

    return SectionCard(
      title: '主题颜色',
      icon: Icons.palette_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color swatches
          Wrap(
            spacing: UiConstants.spacingSm,
            runSpacing: UiConstants.spacingSm,
            children: AppColors.presets.map((color) {
              final isSelected = color.toARGB32() == currentColor.toARGB32();
              return GestureDetector(
                onTap: () =>
                    ref.read(configProvider.notifier).setSeedColor(color.toARGB32()),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: theme.colorScheme.onSurface, width: 3)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(Icons.check,
                          size: 18,
                          color: color.computeLuminance() > 0.5
                              ? Colors.black87
                              : Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: UiConstants.spacingLg),
          // Theme mode selector
          SegmentedButton<String>(
            segments: _modes.map((m) {
              return ButtonSegment<String>(
                value: m.$1,
                label: Text(m.$2),
                icon: Icon(m.$3, size: 18),
              );
            }).toList(),
            selected: {currentMode},
            onSelectionChanged: (selection) {
              ref.read(configProvider.notifier).setThemeMode(selection.first);
            },
            showSelectedIcon: false,
          ),
        ],
      ),
    );
  }
}
