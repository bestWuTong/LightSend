import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../main.dart';
import '../../data/models/upload_task.dart';
import '../providers/upload_providers.dart';
import '../widgets/drop_zone.dart';
import '../widgets/upload_task_tile.dart';
import 'text_input_page.dart';

/// Main upload page. On Windows: drag-drop + file picker. On Android: file picker.
class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  @override
  void initState() {
    super.initState();
    _addPendingFiles();
    pendingUploadTick.addListener(_addPendingFiles);
  }

  @override
  void dispose() {
    pendingUploadTick.removeListener(_addPendingFiles);
    super.dispose();
  }

  void _addPendingFiles() {
    if (pendingUploadPaths.isNotEmpty) {
      final paths = List<String>.from(pendingUploadPaths);
      pendingUploadPaths.clear();
      ref.read(uploadProvider.notifier).addFiles(paths);
    }
  }

  void _openTextInputPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (ctx) => const TextInputPage()));
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(uploadProvider);
    final hasActive = tasks.any(
      (t) =>
          t.status == UploadStatus.idle || t.status == UploadStatus.uploading,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('轻传 LightSend'),
        centerTitle: true,
        actions: [
          if (tasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all_outlined),
              tooltip: '清空已完成',
              onPressed: () =>
                  ref.read(uploadProvider.notifier).clearCompleted(),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildUploadArea(context),
          // Task list
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: UiConstants.spacingSm),
                        Text(
                          '暂无传输任务',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: tasks.length,
                    itemBuilder: (_, index) {
                      final task = tasks[tasks.length - 1 - index];
                      return UploadTaskTile(task: task);
                    },
                  ),
          ),
          // Status bar
          if (hasActive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: UiConstants.spacingMd,
                vertical: UiConstants.spacingSm,
              ),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: UiConstants.spacingSm),
                  Text(
                    '${tasks.where((t) => t.status == UploadStatus.uploading).length} 个上传中, '
                    '${tasks.where((t) => t.status == UploadStatus.idle).length} 个等待中',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () =>
                        ref.read(uploadProvider.notifier).cancelCurrent(),
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('取消当前'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadArea(BuildContext context) {
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return Padding(
      padding: const EdgeInsets.all(UiConstants.spacingMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toggle button for text input
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: _openTextInputPage,
                icon: const Icon(Icons.text_fields, size: 18),
                label: const Text('发送文本'),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.insert_drive_file_outlined, size: 18),
                label: const Text('选择文件'),
              ),
            ],
          ),
          const SizedBox(height: UiConstants.spacingMd),
          // File drop/select area - full width
          isDesktop
              ? DropZone(
                  onFilesDropped: (paths) =>
                      ref.read(uploadProvider.notifier).addFiles(paths),
                  child: _buildUploadHint(context, '拖拽文件到此处上传'),
                )
              : _buildMobileUploadCard(context),
        ],
      ),
    );
  }

  Widget _buildMobileUploadCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(UiConstants.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.share_outlined,
              size: 40,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: UiConstants.spacingSm),
            Text(
              '从其他应用分享文件到此上传',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadHint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.all(UiConstants.spacingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: UiConstants.spacingSm),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      dialogTitle: '选择要上传的文件',
    );
    if (result != null && result.files.isNotEmpty) {
      final paths = result.files
          .map((f) => f.path)
          .whereType<String>()
          .toList();
      if (paths.isNotEmpty) {
        ref.read(uploadProvider.notifier).addFiles(paths);
      }
    }
  }
}
