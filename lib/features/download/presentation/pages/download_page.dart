import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../core/utils/storage_permission_helper.dart';
import '../providers/download_provider.dart';
import '../widgets/cloud_file_tile.dart';
import '../widgets/download_task_tile.dart';

/// Download page: cloud file list + download task list + cleanup.
class DownloadPage extends ConsumerStatefulWidget {
  const DownloadPage({super.key});

  @override
  ConsumerState<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends ConsumerState<DownloadPage> {
  bool _hasStoragePermission = true;
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(downloadProvider.notifier).refreshCloudFiles();
      _checkPermission();
    });
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
    await Future.delayed(const Duration(milliseconds: 500));
    await _checkPermission();
  }

  Future<bool> _confirmClearAll() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空全部云端文件'),
        content: const Text('确定要删除云端所有文件吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('确定删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(downloadProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('下载'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () =>
                ref.read(downloadProvider.notifier).refreshCloudFiles(),
          ),
          if (state.cloudFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.auto_delete_outlined),
              tooltip: '清空云端',
              onPressed: () async {
                final confirmed = await _confirmClearAll();
                if (confirmed && mounted) {
                  ref.read(downloadProvider.notifier).clearAllCloudFiles();
                }
              },
            ),
          if (state.tasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all_outlined),
              tooltip: '清空已完成',
              onPressed: () =>
                  ref.read(downloadProvider.notifier).clearCompleted(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(downloadProvider.notifier).refreshCloudFiles(),
        child: ListView(
          children: [
            // ── Storage permission banner (Android) ──────────────────────
            if (Platform.isAndroid &&
                _permissionChecked &&
                !_hasStoragePermission)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 20, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '存储权限未开启，文件将下载到应用私有目录',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _openPermissionSettings,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('去设置'),
                    ),
                  ],
                ),
              ),

            // ── Cloud files section ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.cloud_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    '云端文件',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (state.isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  state.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (state.cloudFiles.isEmpty && !state.isLoading)
              Padding(
                padding: const EdgeInsets.all(UiConstants.spacingLg),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: UiConstants.spacingSm),
                      Text(
                        '暂无云端文件',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '下拉刷新或等待其他设备上传',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ...state.cloudFiles.map(
              (file) => CloudFileTile(file: file),
            ),

            // ── Download tasks section ───────────────────────────────────
            if (state.tasks.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.download_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      '下载任务',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ...state.tasks.map(
                (task) => DownloadTaskTile(task: task),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
