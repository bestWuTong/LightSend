import 'package:flutter/material.dart';

/// A small status indicator (colored dot + message).
class StatusIndicator extends StatelessWidget {
  final bool? success;
  final String? message;

  const StatusIndicator({
    super.key,
    this.success,
    this.message,
  });

  factory StatusIndicator.success(String message) {
    return StatusIndicator(key: ValueKey('success_$message'), success: true, message: message);
  }

  factory StatusIndicator.failure(String message) {
    return StatusIndicator(key: ValueKey('failure_$message'), success: false, message: message);
  }

  @override
  Widget build(BuildContext context) {
    if (success == null && message == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final color = success == true ? Colors.green : (success == false ? Colors.red : colorScheme.onSurface);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        if (message != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message!,
              style: TextStyle(
                color: color,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
