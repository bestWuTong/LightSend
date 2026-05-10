import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../../core/constants/ui_constants.dart';
import '../../../../../core/utils/path_utils.dart';
import '../../../../../core/utils/storage_permission_helper.dart';
import '../providers/config_providers.dart';
import 'config_dialogs.dart';
import 'section_card.dart';

/// Download path configuration section with storage permission management.
class DownloadPathSection extends ConsumerStatefulWidget {
  const DownloadPathSection({super.key});

  @override
  ConsumerState<DownloadPathSection> createState() =>
      _DownloadPathSectionState();
}

class _DownloadPathSectionState extends ConsumerState<DownloadPathSection> {
  bool _hasStoragePermission = true;
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await StoragePermissionHelper.hasFullStorageAccess();
    if (mounted) {
      setState(() {
        _hasStoragePermission = granted;
        _permissionChecked = true;
      });
    }
  }

  Future<void> _openPermissionSettings() async {
    await StoragePermissionHelper.openStoragePermissionSettings();
    // Re-check when returning from settings
    await Future.delayed(const Duration(milliseconds: 500));
    await _checkPermission();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configProvider);

    return configAsync.when(
      loading: () => const SectionCard(
        title: '默认下载路径',
        icon: Icons.folder_outlined,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SectionCard(
        title: '默认下载路径',
        icon: Icons.folder_outlined,
        child: Text('加载失败: $e'),
      ),
      data: (config) => _buildContent(context, ref, config),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    config,
  ) {
    final path = config.downloadPath.path;
    final theme = Theme.of(context);

    return SectionCard(
      title: '默认下载路径',
      icon: Icons.folder_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Storage permission warning (Android only) ────────────
          if (Platform.isAndroid &&
              _permissionChecked &&
              !_hasStoragePermission)
            Container(
              margin: const EdgeInsets.only(bottom: UiConstants.spacingMd),
              padding: const EdgeInsets.all(UiConstants.spacingMd),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(UiConstants.radiusSm),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 20, color: Colors.orange),
                  const SizedBox(width: UiConstants.spacingSm),
                  Expanded(
                    child: Text(
                      '存储权限未开启，文件可能无法下载到自定义目录',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: UiConstants.spacingSm),
                  TextButton(
                    onPressed: _openPermissionSettings,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('去授权'),
                  ),
                ],
              ),
            ),

          // ── Current path display ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(UiConstants.spacingMd),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(UiConstants.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: UiConstants.spacingSm),
                Expanded(
                  child: Text(
                    path.isEmpty ? '未设置' : PathUtils.displayPath(path),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: path.isEmpty
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          if (path.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: UiConstants.spacingXs),
              child: Text(
                path,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          const SizedBox(height: UiConstants.spacingMd),

          // ── Custom path input ──────────────────────────────────
          TextField(
            controller: TextEditingController(text: path),
            decoration: InputDecoration(
              labelText: '自定义路径',
              hintText: '/storage/emulated/0/Download',
              prefixIcon: const Icon(Icons.edit_outlined, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(UiConstants.radiusSm),
              ),
            ),
            style: theme.textTheme.bodySmall,
            onSubmitted: (value) async {
              if (value.trim().isNotEmpty) {
                final messenger = ScaffoldMessenger.of(context);
                // Verify path exists or can be created
                final dir = Directory(value.trim());
                if (!await dir.exists()) {
                  try {
                    await dir.create(recursive: true);
                  } catch (_) {
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('无法访问此路径，请检查权限')),
                      );
                    }
                    return;
                  }
                }
                ref
                    .read(configProvider.notifier)
                    .updateDownloadPath(value.trim(), isDefault: false);
              }
            },
          ),

          const SizedBox(height: UiConstants.spacingMd),

          // ── Action buttons ────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _resetToDefault(ref),
                  icon: const Icon(Icons.restore_outlined, size: 18),
                  label: const Text('恢复默认'),
                ),
              ),
              const SizedBox(width: UiConstants.spacingMd),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _pickDirectory(ref),
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: const Text('浏览...'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDirectory(WidgetRef ref) async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择默认下载目录',
    );
    if (selected == null) return;

    ref
        .read(configProvider.notifier)
        .updateDownloadPath(selected, isDefault: false);
  }

  Future<void> _resetToDefault(WidgetRef ref) async {
    final confirmed = await ConfigDialogs.showConfirmation(
      ref.context,
      '恢复默认下载路径',
      '确定要恢复到系统默认下载目录吗？',
    );
    if (!confirmed) return;

    ref.read(configProvider.notifier).resetDownloadPath();
  }
}
