import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';

/// Loading spinner widget
class LoadingSpinner extends StatelessWidget {
  final double? size;
  final Color? color;
  final String? message;

  const LoadingSpinner({
    super.key,
    this.size,
    this.color,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(
      height: size ?? 24,
      width: size ?? 24,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppColors.primary,
        ),
      ),
    );

    if (message != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          spinner,
          const SizedBox(height: 16),
          Text(
            message!,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return spinner;
  }
}

/// Full screen loading overlay
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final Widget child;

  const LoadingOverlay({
    super.key,
    this.message,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (message != null)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LoadingSpinner(size: 48),
                  const SizedBox(height: 16),
                  Text(
                    message!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
