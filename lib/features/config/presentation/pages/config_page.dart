import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/ui_constants.dart';
import '../../../../features/tray/services/auto_start_service.dart';
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
  final AutoStartService _autoStartService = AutoStartService();
  final SendtoService _sendtoService = SendtoService();
  bool _autoStartEnabled = false;
  bool _autoStartLoaded = false;
  bool _sendToMenuEnabled = false;
  bool _sendToMenuLoaded = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _loadAutoStartState();
      _loadSendToMenuState();
    }
  }

  Future<void> _loadAutoStartState() async {
    final enabled = await _autoStartService.isEnabled();
    if (mounted) {
      setState(() {
        _autoStartEnabled = enabled;
        _autoStartLoaded = true;
      });
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

  Future<void> _toggleAutoStart(bool value) async {
    bool success;
    if (value) {
      success = await _autoStartService.enable();
    } else {
      success = await _autoStartService.disable();
    }
    if (mounted) {
      setState(() {
        _autoStartEnabled = success ? value : _autoStartEnabled;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? (value ? '已开启开机自启' : '已关闭开机自启')
                : '操作失败，请检查系统权限'),
          ),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? (value ? '已添加到"发送到"菜单' : '已从"发送到"菜单移除')
                : '操作失败，请检查系统权限'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('轻传 LightSend'),
        centerTitle: true,
      ),
      body: configAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(UiConstants.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error),
                const SizedBox(height: UiConstants.spacingMd),
                Text(
                  '配置加载失败',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: UiConstants.spacingSm),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: UiConstants.spacingLg),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(configProvider.notifier).reload(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
        data: (config) => ListView(
          padding: const EdgeInsets.symmetric(
            vertical: UiConstants.spacingMd,
          ),
          children: [
            const WebdavProfileList(),
            const DownloadPathSection(),
            const ThemeSection(),
            const SizedBox(height: UiConstants.spacingMd),
            // Custom font toggle
            Card(
              margin: const EdgeInsets.symmetric(
                horizontal: UiConstants.spacingMd,
                vertical: UiConstants.spacingSm,
              ),
              child: SwitchListTile(
                title: const Text('使用 HarmonyOS Sans 字体'),
                subtitle: const Text('关闭后重启应用恢复系统默认字体'),
                secondary: const Icon(Icons.font_download_outlined),
                value: config.useCustomFont,
                onChanged: (value) {
                  ref
                      .read(configProvider.notifier)
                      .setUseCustomFont(value);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('字体设置将在下次启动时生效'),
                      ),
                    );
                  }
                },
              ),
            ),
            // Window close behavior (Windows only)
            if (Platform.isWindows)
              Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: UiConstants.spacingMd,
                  vertical: UiConstants.spacingSm,
                ),
                child: SwitchListTile(
                  title: const Text('关闭窗口时退出程序'),
                  subtitle: const Text('关闭后彻底退出，不驻留托盘'),
                  secondary: const Icon(Icons.exit_to_app_outlined),
                  value: config.exitOnClose,
                  onChanged: (value) {
                    ref
                        .read(configProvider.notifier)
                        .setExitOnClose(value);
                  },
                ),
              ),
            // Auto-start toggle (Windows only)
            if (Platform.isWindows) ...[
              const SizedBox(height: UiConstants.spacingMd),
              Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: UiConstants.spacingMd,
                  vertical: UiConstants.spacingSm,
                ),
                child: SwitchListTile(
                  title: const Text('开机自启'),
                  subtitle: const Text('系统启动时自动后台托盘运行'),
                  secondary:
                      const Icon(Icons.power_settings_new_outlined),
                  value: _autoStartEnabled,
                  onChanged: _autoStartLoaded ? _toggleAutoStart : null,
                ),
              ),
              // SendTo menu toggle (Windows only)
              Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: UiConstants.spacingMd,
                  vertical: UiConstants.spacingSm,
                ),
                child: SwitchListTile(
                  title: const Text('添加到"发送到"菜单'),
                  subtitle: const Text('右键文件→发送到→轻传，快速发送文件'),
                  secondary:
                      const Icon(Icons.send_outlined),
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
