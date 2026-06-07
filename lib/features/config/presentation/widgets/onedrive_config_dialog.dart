import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/ui_constants.dart';
import '../../../../../shared/widgets/status_indicator.dart';
import '../../data/models/cloud_profile.dart';
import '../../data/models/onedrive_config.dart';
import '../providers/config_providers.dart';

class OneDriveConfigDialog extends ConsumerStatefulWidget {
  final CloudProfile? existingProfile;

  const OneDriveConfigDialog({super.key, this.existingProfile});

  bool get isEditing => existingProfile != null;

  @override
  ConsumerState<OneDriveConfigDialog> createState() =>
      _OneDriveConfigDialogState();
}

class _OneDriveConfigDialogState extends ConsumerState<OneDriveConfigDialog> {
  late final TextEditingController _nameCtrl;
  OneDriveConfig _config = OneDriveConfig.empty();
  bool _isSigningIn = false;
  bool _isTesting = false;
  bool? _testSucceeded;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    final profile = widget.existingProfile;
    _nameCtrl = TextEditingController(text: profile?.name ?? '');
    _config = profile?.oneDrive ?? OneDriveConfig.empty();
    _testSucceeded = _config.lastTestSucceeded;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _isSigningIn = true);
    try {
      final config = await ref.read(oneDriveAuthServiceProvider).signIn();
      if (!mounted) return;
      setState(() {
        _config = config.copyWith(clearLastTest: true);
        _testSucceeded = null;
        _testMessage = null;
        if (_nameCtrl.text.trim().isEmpty) {
          _nameCtrl.text = _defaultName(config);
        }
      });
    } catch (e) {
      if (mounted) _showError('$e');
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _testConnection() async {
    if (!_config.isConnected) {
      _showError('请先登录 OneDrive');
      return;
    }

    setState(() {
      _isTesting = true;
      _testSucceeded = null;
      _testMessage = null;
    });

    try {
      var testedConfig = _config;
      await ref
          .read(oneDriveFileServiceProvider)
          .testConnection(
            config: _config,
            onConfigUpdated: (updated) async {
              testedConfig = updated;
            },
          );

      if (!mounted) return;
      setState(() {
        _config = testedConfig.copyWith(lastTestSucceeded: true);
        _testSucceeded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _config = _config.copyWith(lastTestSucceeded: false);
        _testSucceeded = false;
        _testMessage = '$e';
      });
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showError('请输入配置名称');
      return;
    }
    if (!_config.isConnected) {
      _showError('请先登录 OneDrive');
      return;
    }

    final success = await ref
        .read(configProvider.notifier)
        .saveOneDriveProfile(
          name,
          profileId: widget.existingProfile?.id,
          config: _config,
        );

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
      } else {
        _showError('保存失败，请重试');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountText = _accountLabel(_config);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑 OneDrive 配置' : '新建 OneDrive 配置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(UiConstants.spacingMd),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '配置名称',
              hintText: '例如：我的 OneDrive',
              prefixIcon: Icon(Icons.bookmark_outline),
            ),
          ),
          const SizedBox(height: UiConstants.spacingMd),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _config.isConnected
                  ? Icons.check_circle
                  : Icons.account_circle_outlined,
              color: _config.isConnected ? theme.colorScheme.primary : null,
            ),
            title: Text(_config.isConnected ? '已登录' : '未登录'),
            subtitle: Text(accountText),
          ),
          const SizedBox(height: UiConstants.spacingMd),
          FilledButton.icon(
            onPressed: _isSigningIn ? null : _signIn,
            icon: _isSigningIn
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login_outlined),
            label: Text(
              _isSigningIn
                  ? '登录中...'
                  : (_config.isConnected ? '重新登录' : '登录 OneDrive'),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
          ),
          const SizedBox(height: UiConstants.spacingMd),
          _buildTestArea(),
          const SizedBox(height: UiConstants.spacingLg),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(widget.isEditing ? '保存修改' : '保存配置'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestArea() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _isTesting ? null : _testConnection,
          icon: _isTesting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cable_outlined),
          label: Text(_isTesting ? '测试中...' : '测试连接'),
        ),
        const SizedBox(width: UiConstants.spacingMd),
        Expanded(child: _buildTestStatus()),
      ],
    );
  }

  Widget _buildTestStatus() {
    if (_isTesting) {
      return const Text('正在测试...', style: TextStyle(fontSize: 13));
    }
    if (_testSucceeded == true) {
      return StatusIndicator.success('连接成功');
    }
    if (_testSucceeded == false) {
      return StatusIndicator.failure(_testMessage ?? '连接失败');
    }
    return const SizedBox.shrink();
  }

  String _accountLabel(OneDriveConfig config) {
    if (!config.isConnected) return '使用个人 OneDrive 的应用专属目录存取文件';
    if (config.displayName.isNotEmpty && config.account.isNotEmpty) {
      return '${config.displayName} · ${config.account}';
    }
    if (config.displayName.isNotEmpty) return config.displayName;
    if (config.account.isNotEmpty) return config.account;
    return 'OneDrive 账户';
  }

  String _defaultName(OneDriveConfig config) {
    if (config.displayName.isNotEmpty) return config.displayName;
    if (config.account.isNotEmpty) return config.account;
    return 'OneDrive';
  }
}
