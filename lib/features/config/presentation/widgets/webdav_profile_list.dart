import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../../core/constants/ui_constants.dart';
import '../../data/models/webdav_profile.dart';
import '../providers/config_providers.dart';
import 'config_dialogs.dart';
import 'section_card.dart';
import 'webdav_config_dialog.dart';

/// Displays the WebDAV profile list with create / switch / edit / delete actions.
class WebdavProfileList extends ConsumerWidget {
  const WebdavProfileList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(configProvider);
    final config = configAsync.valueOrNull;
    if (config == null) return const SizedBox.shrink();

    final profiles = config.profiles;

    return SectionCard(
      title: 'WebDAV配置列表',
      icon: Icons.cloud_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新建配置'),
          ),
          const SizedBox(height: UiConstants.spacingSm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: profiles.isEmpty
                      ? null
                      : () => _exportProfiles(context, ref, profiles),
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('导出配置'),
                ),
              ),
              const SizedBox(width: UiConstants.spacingMd),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _importProfiles(context, ref),
                  icon: const Icon(
                    Icons.download_for_offline_outlined,
                    size: 18,
                  ),
                  label: const Text('导入配置'),
                ),
              ),
            ],
          ),
          if (profiles.isNotEmpty) ...[
            const Divider(height: UiConstants.spacingLg),
            ...List.generate(profiles.length, (index) {
              final profile = profiles[index];
              final isActive = profile.id == config.activeProfileId;
              return _ProfileTile(profile: profile, isActive: isActive);
            }),
          ],
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, {WebdavProfile? profile}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebdavConfigDialog(existingProfile: profile),
      ),
    );
  }

  Future<void> _exportProfiles(
    BuildContext context,
    WidgetRef ref,
    List<WebdavProfile> profiles,
  ) async {
    final selectedIds = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => _WebdavProfileExportDialog(profiles: profiles),
    );
    if (selectedIds == null || selectedIds.isEmpty) return;

    final exported = ref
        .read(configProvider.notifier)
        .exportWebdavProfiles(selectedIds);
    if (exported == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('没有可导出的配置')));
      }
      return;
    }

    await Clipboard.setData(ClipboardData(text: exported));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
    }
  }

  Future<void> _importProfiles(BuildContext context, WidgetRef ref) async {
    final rawConfig = await showDialog<String>(
      context: context,
      builder: (ctx) => const _WebdavProfileImportDialog(),
    );
    if (rawConfig == null || rawConfig.trim().isEmpty) return;

    try {
      await ref
          .read(configProvider.notifier)
          .importWebdavProfiles(rawConfig.trim());
    } catch (_) {
      if (context.mounted) {
        await ConfigDialogs.showError(context, '导入失败', '配置内容无效，请检查后重新导入。');
      }
    }
  }
}

class _WebdavProfileExportDialog extends StatefulWidget {
  final List<WebdavProfile> profiles;

  const _WebdavProfileExportDialog({required this.profiles});

  @override
  State<_WebdavProfileExportDialog> createState() =>
      _WebdavProfileExportDialogState();
}

class _WebdavProfileExportDialogState
    extends State<_WebdavProfileExportDialog> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.profiles.map((profile) => profile.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导出WebDAV配置'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.profiles.length,
          itemBuilder: (ctx, index) {
            final profile = widget.profiles[index];
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _selectedIds.contains(profile.id),
              title: Text(profile.name),
              subtitle: Text(
                '${profile.config.account}@${Uri.tryParse(profile.config.url)?.host ?? profile.config.url}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedIds.add(profile.id);
                  } else {
                    _selectedIds.remove(profile.id);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selectedIds.toList()),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _WebdavProfileImportDialog extends StatefulWidget {
  const _WebdavProfileImportDialog();

  @override
  State<_WebdavProfileImportDialog> createState() =>
      _WebdavProfileImportDialogState();
}

class _WebdavProfileImportDialogState
    extends State<_WebdavProfileImportDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导入WebDAV配置'),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 8,
          maxLines: 12,
          decoration: const InputDecoration(
            hintText: '粘贴已复制的配置',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('导入'),
        ),
      ],
    );
  }
}

class _ProfileTile extends ConsumerWidget {
  final WebdavProfile profile;
  final bool isActive;

  const _ProfileTile({required this.profile, required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isActive ? Icons.cloud : Icons.cloud_outlined,
        color: isActive ? theme.colorScheme.primary : null,
      ),
      title: Text(
        profile.name,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        '${profile.config.account}@${Uri.tryParse(profile.config.url)?.host ?? profile.config.url}',
        style: theme.textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isActive)
            IconButton(
              icon: const Icon(Icons.check_circle_outline, size: 20),
              tooltip: '切换到此配置',
              onPressed: () => _activate(context, ref),
            )
          else
            Tooltip(
              message: '当前使用中',
              child: Icon(
                Icons.check_circle,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: '编辑',
            onPressed: () => _edit(context),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 20,
              color: theme.colorScheme.error,
            ),
            tooltip: '删除',
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      onTap: () => _activate(context, ref),
    );
  }

  Future<void> _activate(BuildContext context, WidgetRef ref) async {
    if (isActive) return;
    await ref.read(configProvider.notifier).activateProfile(profile.id);
  }

  void _edit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebdavConfigDialog(existingProfile: profile),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfigDialogs.showConfirmation(
      context,
      '删除配置"${profile.name}"',
      '确定要删除这个WebDAV配置吗？此操作不可撤销。',
    );
    if (!confirmed) return;

    await ref.read(configProvider.notifier).deleteProfile(profile.id);
  }
}
