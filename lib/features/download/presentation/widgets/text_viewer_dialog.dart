import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../data/models/cloud_file.dart';
import '../providers/download_provider.dart';

class TextViewerDialog extends ConsumerStatefulWidget {
  final CloudFile file;

  const TextViewerDialog({super.key, required this.file});

  @override
  ConsumerState<TextViewerDialog> createState() => _TextViewerDialogState();
}

class _TextViewerDialogState extends ConsumerState<TextViewerDialog> {
  String? _content;
  bool _isLoading = true;
  bool _isCopying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final content = await readCloudTextContent(ref, widget.file);
      if (mounted) {
        setState(() {
          _content = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _copyToClipboard() async {
    if (_content == null || _isCopying) return;

    setState(() {
      _isCopying = true;
    });

    try {
      await Clipboard.setData(ClipboardData(text: _content!));
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('复制失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCopying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('查看文本', style: theme.textTheme.titleLarge),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: UiConstants.spacingMd),
                    Text('加载失败', style: theme.textTheme.titleMedium),
                    const SizedBox(height: UiConstants.spacingSm),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(UiConstants.spacingMd),
                  primary: true,
                  child: SelectableText(
                    _content ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ),
      ),
      actions: [
        TextButton.icon(
          onPressed: Navigator.of(context).pop,
          icon: const Icon(Icons.close_outlined),
          label: const Text('关闭'),
        ),
        FilledButton.icon(
          onPressed: (_content == null || _isLoading || _isCopying)
              ? null
              : _copyToClipboard,
          icon: _isCopying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.copy_outlined),
          label: const Text('复制'),
        ),
      ],
    );
  }
}

Future<void> showTextViewer(BuildContext context, CloudFile file) {
  return showDialog(
    context: context,
    builder: (ctx) => TextViewerDialog(file: file),
  );
}
