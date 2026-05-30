import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/file_opener.dart';
import '../../data/models/download_task.dart';
import '../providers/download_provider.dart';

/// A single download task row with progress and actions.
class DownloadTaskTile extends ConsumerWidget {
  final DownloadTask task;

  const DownloadTaskTile({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusIcon(theme),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.cloudFile.name,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.fileSizeFormatted,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _actionButton(ref, theme),
              ],
            ),
            if (task.status == DownloadStatus.downloading) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: task.progress,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(task.progress * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelSmall,
                  ),
                  Text(task.speedFormatted, style: theme.textTheme.labelSmall),
                ],
              ),
            ],
            if (task.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  task.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(ThemeData theme) {
    switch (task.status) {
      case DownloadStatus.pending:
        return Icon(
          Icons.hourglass_empty,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        );
      case DownloadStatus.downloading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: task.progress > 0 ? task.progress : null,
          ),
        );
      case DownloadStatus.completed:
        return const Icon(Icons.check_circle, size: 20, color: Colors.green);
      case DownloadStatus.failed:
        return const Icon(Icons.error, size: 20, color: Colors.red);
    }
  }

  Widget _actionButton(WidgetRef ref, ThemeData theme) {
    switch (task.status) {
      case DownloadStatus.downloading:
        return IconButton(
          icon: const Icon(Icons.close, size: 20),
          tooltip: '取消',
          onPressed: () => ref.read(downloadProvider.notifier).remove(task.id),
        );
      case DownloadStatus.failed:
        return IconButton(
          icon: Icon(Icons.refresh, size: 20, color: theme.colorScheme.primary),
          tooltip: '重试',
          onPressed: () => ref.read(downloadProvider.notifier).retry(task.id),
        );
      case DownloadStatus.completed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!Platform.isAndroid)
              IconButton(
                icon: Icon(
                  Icons.folder_open,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                tooltip: '打开文件夹',
                onPressed: () =>
                    FileOpener.openContainingFolder(task.localPath),
              ),
            IconButton(
              icon: Icon(
                Icons.open_in_new,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              tooltip: '打开文件',
              onPressed: () => FileOpener.openFile(task.localPath),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: '删除记录',
              onPressed: () =>
                  ref.read(downloadProvider.notifier).remove(task.id),
            ),
          ],
        );
      case DownloadStatus.pending:
        return const SizedBox.shrink();
    }
  }
}
