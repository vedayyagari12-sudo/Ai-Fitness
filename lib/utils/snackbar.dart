import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Global, consistent save/action feedback — The Outsiders style:
/// dark surface, colored left border, white text, slides up, auto-dismiss.
class AppSnackbar {
  AppSnackbar._();

  static void success(BuildContext context, String message) =>
      _show(context, message, AppColors.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, AppColors.accentSecondary);

  static void info(BuildContext context, String message) =>
      _show(context, message, AppColors.accent);

  static void _show(BuildContext context, String message, Color accent) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        duration: const Duration(milliseconds: 2500),
        // NOTE: a left-only (non-uniform) Border combined with borderRadius
        // makes Flutter throw during paint(), which blanks the message. Round
        // with a ClipRRect and draw the accent stripe as its own element.
        content: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: accent),
                Expanded(
                  child: Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
