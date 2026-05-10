import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/ui_constants.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../shared/widgets/status_indicator.dart';
import '../../data/models/webdav_config.dart';
import '../../services/webdav_service.dart';
import '../providers/config_providers.dart';
import 'config_dialogs.dart';
import 'section_card.dart';

/// WebDAV configuration section widget.
class WebdavConfigSection extends ConsumerStatefulWidget {
  const WebdavConfigSection({super.key});

  @override
  ConsumerState<WebdavConfigSection> createState() =>
      _WebdavConfigSectionState();
}

class _WebdavConfigSectionState extends ConsumerState<WebdavConfigSection> {
  final _urlCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  WebdavConfig? _lastSyncedConfig; // Track last config synced to controllers

  // Local test state — not using FutureProvider to avoid infinite rebuild loop
  bool _isTesting = false;
  WebdavTestResult? _testResult;
  WebdavConfig? _lastTestedConfig; // The config that produced _testResult

  @override
  void initState() {
    super.initState();
    _loadFromConfig();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _accountCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _loadFromConfig() {
    final config = ref.read(configProvider).valueOrNull;
    if (config != null) {
      final wc = config.webdav;
      _urlCtrl.text = wc.url;
      _accountCtrl.text = wc.account;
      _passwordCtrl.text = wc.password;
      _lastSyncedConfig = wc;
    }
  }

  WebdavConfig _currentInput() {
    return WebdavConfig(
      url: _urlCtrl.text.trim(),
      account: _accountCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
  }

  Future<void> _testConnection() async {
    final input = _currentInput();

    // Validate fields
    final urlError = ConfigValidators.webdavUrl(input.url);
    final accountError = ConfigValidators.account(input.account);
    final passwordError = ConfigValidators.password(input.password);

    if (urlError != null || accountError != null || passwordError != null) {
      ConfigDialogs.showError(
        context,
        '配置不完整',
        [urlError, accountError, passwordError].whereType<String>().join('\n'),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    // Call service directly instead of going through FutureProvider
    final service = ref.read(webdavServiceProvider);
    final result = await service.testConnection(input);

    if (!mounted) return;

    setState(() {
      _isTesting = false;
      _testResult = result;
      _lastTestedConfig = input;
    });

    // Update lastTestSucceeded in persistent config
    final notifier = ref.read(configProvider.notifier);
    final current = ref.read(configProvider).valueOrNull;
    if (current != null) {
      await notifier.updateWebdavConfig(
        input.copyWith(lastTestSucceeded: result.isSuccess),
      );
    }
  }

  void _save() {
    final input = _currentInput();
    if (!_validateInput(input)) return;

    ref.read(configProvider.notifier).updateWebdavConfig(input);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WebDAV配置已保存')),
    );
  }

  Future<void> _saveAsProfile() async {
    final input = _currentInput();
    if (!_validateInput(input)) return;

    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存为配置'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '配置名称',
            hintText: '例如：坚果云、公司WebDAV',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await ref.read(configProvider.notifier).saveProfile(name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存配置"$name"')),
        );
      }
    }
  }

  bool _validateInput(WebdavConfig input) {
    final urlError = ConfigValidators.webdavUrl(input.url);
    final accountError = ConfigValidators.account(input.account);
    final passwordError = ConfigValidators.password(input.password);

    if (urlError != null || accountError != null || passwordError != null) {
      ConfigDialogs.showError(
        context,
        '配置校验失败',
        [urlError, accountError, passwordError].whereType<String>().join('\n'),
      );
      return false;
    }
    return true;
  }

  Future<void> _reset() async {
    final confirmed = await ConfigDialogs.showConfirmation(
      context,
      '重置WebDAV配置',
      '确定要清空所有WebDAV配置吗？',
    );
    if (!confirmed) return;

    ref.read(configProvider.notifier).resetWebdavConfig();
    _urlCtrl.clear();
    _accountCtrl.clear();
    _passwordCtrl.clear();
    setState(() {
      _testResult = null;
      _lastTestedConfig = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncFromState();

    return SectionCard(
      title: 'WebDAV配置',
      icon: Icons.cloud_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: 'https://dav.jianguoyun.com/dav/',
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
            onChanged: (_) => _onFieldChanged(),
          ),
          const SizedBox(height: UiConstants.spacingMd),
          TextField(
            controller: _accountCtrl,
            decoration: const InputDecoration(
              labelText: '账号',
              hintText: 'your-email@example.com',
              prefixIcon: Icon(Icons.person_outline),
            ),
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => _onFieldChanged(),
          ),
          const SizedBox(height: UiConstants.spacingMd),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: '密码（第三方应用密码）',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            onChanged: (_) => _onFieldChanged(),
          ),
          const SizedBox(height: UiConstants.spacingMd),
          _buildTestArea(),
          const SizedBox(height: UiConstants.spacingMd),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reset,
                      child: const Text('重置'),
                    ),
                  ),
                  const SizedBox(width: UiConstants.spacingMd),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: UiConstants.spacingSm),
              FilledButton.tonalIcon(
                onPressed: _saveAsProfile,
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: const Text('保存到配置列表'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _syncFromState() {
    final config = ref.watch(configProvider).valueOrNull;
    if (config == null) return;

    final wc = config.webdav;
    if (_lastSyncedConfig == wc) return;

    _urlCtrl.text = wc.url;
    _accountCtrl.text = wc.account;
    _passwordCtrl.text = wc.password;
    _lastSyncedConfig = wc;
    _lastTestedConfig = null;
    _testResult = null;
  }

  /// Called when any text field changes — resets the test result if input differs.
  void _onFieldChanged() {
    final current = _currentInput();
    if (_lastTestedConfig != null && _lastTestedConfig != current) {
      setState(() {
        _testResult = null;
        _lastTestedConfig = null;
      });
    }
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
        Expanded(
          child: _buildTestStatus(),
        ),
      ],
    );
  }

  Widget _buildTestStatus() {
    if (_isTesting) {
      return const Text('正在测试...', style: TextStyle(fontSize: 13));
    }
    if (_testResult == null) {
      // Check if the saved config has a lastTestSucceeded
      final saved = ref.watch(configProvider).valueOrNull?.webdav.lastTestSucceeded;
      if (saved == true) return StatusIndicator.success('上次连接成功');
      if (saved == false) return StatusIndicator.failure('上次连接失败');
      return const SizedBox.shrink();
    }
    if (_testResult!.isSuccess) {
      return StatusIndicator.success('连接成功');
    }
    return StatusIndicator.failure(_testResult!.message ?? '连接失败');
  }
}
