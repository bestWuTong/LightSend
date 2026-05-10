import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cloud_file.dart';
import '../providers/download_provider.dart';

/// A single cloud file row with file info and download button.
class CloudFileTile extends ConsumerWidget {
  final CloudFile file;

  const CloudFileTile({super.key, required this.file});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tasks = ref.watch(
      downloadProvider.select((s) => s.tasks),
    );
    final existingTask = tasks.firstWhereOrNull(
      (t) => t.cloudFile.remotePath == file.remotePath,
    );

    final isQueued = existingTask != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              _iconForFile(file.name),
              size: 28,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    file.sizeFormatted,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            FilledButton.tonalIcon(
              onPressed: isQueued
                  ? null
                  : () =>
                      ref.read(downloadProvider.notifier).startDownload(file),
              icon: Icon(
                isQueued ? Icons.check : Icons.download,
                size: 18,
              ),
              label: Text(isQueued ? '已添加' : '下载'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: '删除云端文件',
              color: theme.colorScheme.error.withValues(alpha: 0.7),
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  ref.read(downloadProvider.notifier).deleteCloudFile(file),
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
}

extension _IterableX<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
