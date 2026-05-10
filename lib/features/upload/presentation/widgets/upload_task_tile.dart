import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/upload_task.dart';
import '../providers/upload_providers.dart';

/// A single upload task row with progress and actions.
class UploadTaskTile extends ConsumerWidget {
  final UploadTask task;

  const UploadTaskTile({super.key, required this.task});

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
            // File name and actions
            Row(
              children: [
                _statusIcon(theme),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.fileName,
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
            // Progress bar (only when uploading)
            if (task.status == UploadStatus.uploading) ...[
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
                  Text(
                    task.speedFormatted,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
            // Error message
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
      case UploadStatus.idle:
        return Icon(Icons.hourglass_empty,
            size: 20, color: theme.colorScheme.onSurfaceVariant);
      case UploadStatus.uploading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: task.progress > 0 ? task.progress : null,
          ),
        );
      case UploadStatus.completed:
        return const Icon(Icons.check_circle, size: 20, color: Colors.green);
      case UploadStatus.failed:
        return const Icon(Icons.error, size: 20, color: Colors.red);
    }
  }

  Widget _actionButton(WidgetRef ref, ThemeData theme) {
    switch (task.status) {
      case UploadStatus.uploading:
        return IconButton(
          icon: const Icon(Icons.close, size: 20),
          tooltip: '取消',
          onPressed: () =>
              ref.read(uploadProvider.notifier).remove(task.id),
        );
      case UploadStatus.failed:
        return IconButton(
          icon: Icon(Icons.refresh, size: 20, color: theme.colorScheme.primary),
          tooltip: '重试',
          onPressed: () =>
              ref.read(uploadProvider.notifier).retry(task.id),
        );
      case UploadStatus.completed:
        return IconButton(
          icon: Icon(Icons.delete_outline,
              size: 20, color: theme.colorScheme.onSurfaceVariant),
          tooltip: '删除记录',
          onPressed: () =>
              ref.read(uploadProvider.notifier).remove(task.id),
        );
      case UploadStatus.idle:
        return const SizedBox.shrink();
    }
  }
}
