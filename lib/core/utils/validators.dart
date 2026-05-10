/// Validation functions for config fields.
class ConfigValidators {
  ConfigValidators._();

  static String? webdavUrl(String? value) {
    if (value == null || value.trim().isEmpty) return 'WebDAV地址不能为空';
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return '请输入有效的URL（以 http:// 或 https:// 开头）';
    }
    return null;
  }

  static String? account(String? value) {
    if (value == null || value.trim().isEmpty) return '账号不能为空';
    if (value.trim().length < 3) return '账号长度至少3个字符';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.trim().isEmpty) return '密码不能为空';
    return null;
  }

  static String? downloadPath(String? value) {
    if (value == null || value.trim().isEmpty) return '下载路径不能为空';
    return null;
  }
}
