import 'package:flutter/material.dart';

/// A button that shows a loading indicator when [isLoading] is true.
class LoadingButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  const LoadingButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.label,
    this.icon,
  });

  factory LoadingButton.filled({
    Key? key,
    required bool isLoading,
    required VoidCallback? onPressed,
    required String label,
    IconData? icon,
  }) {
    return LoadingButton(
      key: key,
      isLoading: isLoading,
      onPressed: onPressed,
      label: label,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (icon != null ? Icon(icon) : const SizedBox.shrink()),
      label: Text(isLoading ? '请稍候...' : label),
    );
  }
}
