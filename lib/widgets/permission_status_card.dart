import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'app_dialog.dart';

class PermissionStatusCard extends StatelessWidget {
  final String title;
  final String description;
  final bool granted;
  final VoidCallback onAction;

  const PermissionStatusCard({
    super.key,
    required this.title,
    required this.description,
    required this.granted,
    required this.onAction,
  });

  /// Neither notification access nor battery-optimization exclusion can be
  /// flipped in-app -- both only take effect via a system settings screen --
  /// so the switch never changes state on its own tap. It always confirms
  /// first, then hands off to [onAction] (which opens that settings screen);
  /// the switch's displayed value keeps following [granted] until the app
  /// re-checks permissions on resume.
  Future<void> _confirmAndOpenSettings(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      icon: Icons.settings_suggest_rounded,
      title: l10n.permissionChangeConfirmTitle,
      message: l10n.permissionChangeConfirmBody(title),
      cancelLabel: l10n.cancelButton,
      confirmLabel: l10n.continueButton,
    );
    if (confirmed == true) onAction();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final green = Colors.green.shade600;
    final color = granted ? green : scheme.error;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              granted ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: granted,
            onChanged: (_) => _confirmAndOpenSettings(context),
          ),
        ],
      ),
    );
  }
}
