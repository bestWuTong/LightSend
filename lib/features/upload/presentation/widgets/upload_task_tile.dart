import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/upload_task.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/upload_providers.dart';

/// A single upload task row with progress and actions.
class UploadTaskTile extends ConsumerWidget {
  final UploadTask task;

  const UploadTaskTile({super.key, required this.task});

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final isTextTask = task.type == UploadType.text;
    final displayName = isTextTask 
        ? '文本消息' 
        : task.fileName;
    final subtitle = isTextTask 
        ? (task.textContent != null 
            ? _truncateText(task.textContent!, AppConstants.textPreviewMaxLength) 
            : '')
        : task.fileSizeFormatted;

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
                Icon(
                  isTextTask ? Icons.short_text : _iconForFile(task.fileName),
                  size: 24,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

  IconData _iconForFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return Icons.image_outlined;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
        return Icons.videocam_outlined;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return Icons.audio_file_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip_outlined;
      case 'doc':
      case 'docx':
      case 'txt':
      case 'md':
        return Icons.description_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
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
