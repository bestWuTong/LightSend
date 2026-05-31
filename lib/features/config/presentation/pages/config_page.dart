import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/ui_constants.dart';
import '../../../upload/services/sendto_service.dart';
import '../providers/config_providers.dart';
import '../widgets/about_section.dart';
import '../widgets/download_path_section.dart';
import '../widgets/theme_section.dart';
import '../widgets/webdav_profile_list.dart';

/// Main configuration page assembling all config sections.
class ConfigPage extends ConsumerStatefulWidget {
  const ConfigPage({super.key});

  @override
  ConsumerState<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends ConsumerState<ConfigPage> {
  final SendtoService _sendtoService = SendtoService();
  bool _sendToMenuEnabled = false;
  bool _sendToMenuLoaded = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _loadSendToMenuState();
    }
  }

  Future<void> _loadSendToMenuState() async {
    final enabled = await _sendtoService.isRegistered();
    if (mounted) {
      setState(() {
        _sendToMenuEnabled = enabled;
        _sendToMenuLoaded = true;
      });
    }
  }

  Future<void> _toggleSendToMenu(bool value) async {
    final success = await ref
        .read(configProvider.notifier)
        .setSendToMenuEnabled(value);
    if (mounted) {
      setState(() {
        _sendToMenuEnabled = success ? value : _sendToMenuEnabled;
      });
      if (!success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('操作失败，请检查系统权限')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置'), centerTitle: true),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(UiConstants.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: UiConstants.spacingMd),
                Text('配置加载失败', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: UiConstants.spacingSm),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: UiConstants.spacingLg),
                FilledButton.icon(
                  onPressed: () => ref.read(configProvider.notifier).reload(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
        data: (config) => ListView(
          padding: const EdgeInsets.symmetric(vertical: UiConstants.spacingMd),
          children: [
            const WebdavProfileList(),
            const DownloadPathSection(),
            const ThemeSection(),
            // SendTo menu toggle (Windows only)
            if (Platform.isWindows) ...[
              const SizedBox(height: UiConstants.spacingMd),
              Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: UiConstants.spacingMd,
                  vertical: UiConstants.spacingSm,
                ),
                child: SwitchListTile(
                  title: const Text('添加到"发送到"菜单'),
                  subtitle: const Text('右键文件→发送到→轻传，快速发送文件'),
                  secondary: const Icon(Icons.send_outlined),
                  value: _sendToMenuEnabled,
                  onChanged: _sendToMenuLoaded ? _toggleSendToMenu : null,
                ),
              ),
            ],
            const AboutSection(),
            const SizedBox(height: UiConstants.spacingXl),
          ],
        ),
      ),
    );
  }
}
