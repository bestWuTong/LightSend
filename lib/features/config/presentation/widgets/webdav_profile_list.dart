import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          if (profiles.isNotEmpty) ...[
            const Divider(height: UiConstants.spacingLg),
            ...List.generate(profiles.length, (index) {
              final profile = profiles[index];
              final isActive = profile.id == config.activeProfileId;
              return _ProfileTile(
                profile: profile,
                isActive: isActive,
              );
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
            icon:
                Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
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
    final success =
        await ref.read(configProvider.notifier).activateProfile(profile.id);
    if (context.mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换到"${profile.name}"')),
      );
    }
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

    final success =
        await ref.read(configProvider.notifier).deleteProfile(profile.id);
    if (context.mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除"${profile.name}"')),
      );
    }
  }
}
