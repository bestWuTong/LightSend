import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/ui_constants.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../shared/widgets/status_indicator.dart';
import '../../data/models/webdav_config.dart';
import '../../data/models/webdav_profile.dart';
import '../../services/webdav_service.dart';
import '../providers/config_providers.dart';

/// Full-screen dialog for creating or editing a WebDAV configuration profile.
class WebdavConfigDialog extends ConsumerStatefulWidget {
  /// If non-null, editing an existing profile.
  final WebdavProfile? existingProfile;

  const WebdavConfigDialog({super.key, this.existingProfile});

  bool get isEditing => existingProfile != null;

  @override
  ConsumerState<WebdavConfigDialog> createState() => _WebdavConfigDialogState();
}

class _WebdavConfigDialogState extends ConsumerState<WebdavConfigDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _accountCtrl;
  late final TextEditingController _passwordCtrl;
  bool _obscurePassword = true;

  bool _isTesting = false;
  WebdavTestResult? _testResult;
  WebdavConfig? _lastTestedConfig;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProfile;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _urlCtrl = TextEditingController(text: p?.config.url ?? '');
    _accountCtrl = TextEditingController(text: p?.config.account ?? '');
    _passwordCtrl = TextEditingController(text: p?.config.password ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _accountCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
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
    final errors = [
      ConfigValidators.webdavUrl(input.url),
      ConfigValidators.account(input.account),
      ConfigValidators.password(input.password),
    ].whereType<String>().toList();

    if (errors.isNotEmpty) {
      _showError(errors.join('\n'));
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final service = ref.read(webdavServiceProvider);
    final result = await service.testConnection(input);

    if (!mounted) return;

    setState(() {
      _isTesting = false;
      _testResult = result;
      _lastTestedConfig = input;
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showError('请输入配置名称');
      return;
    }

    final input = _currentInput();
    final errors = [
      ConfigValidators.webdavUrl(input.url),
      ConfigValidators.account(input.account),
      ConfigValidators.password(input.password),
    ].whereType<String>().toList();

    if (errors.isNotEmpty) {
      _showError(errors.join('\n'));
      return;
    }

    final success = await ref.read(configProvider.notifier).saveProfile(
          name,
          profileId: widget.existingProfile?.id,
          config: input,
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

  void _onFieldChanged() {
    final current = _currentInput();
    if (_lastTestedConfig != null && _lastTestedConfig != current) {
      setState(() {
        _testResult = null;
        _lastTestedConfig = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑配置' : '新建配置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(UiConstants.spacingMd),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '配置名称',
              hintText: '例如：坚果云、公司WebDAV',
              prefixIcon: Icon(Icons.bookmark_outline),
            ),
          ),
          const SizedBox(height: UiConstants.spacingMd),
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
                icon: Icon(_obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            onChanged: (_) => _onFieldChanged(),
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
    if (_testResult == null) {
      final saved = widget.existingProfile?.config.lastTestSucceeded;
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
