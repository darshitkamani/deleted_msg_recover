import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../core/native_bridge.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/permission_status_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context);
    final currentLanguage =
        appState.locale?.languageCode ?? Localizations.localeOf(context).languageCode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _SectionHeader(l10n.settingsPermissionsHeader),
        const SizedBox(height: 4),
        PermissionStatusCard(
          title: l10n.notificationAccessTitle,
          description: l10n.settingsNotificationAccessDesc,
          granted: appState.notificationAccessGranted,
          onAction: appState.requestNotificationAccess,
        ),
        PermissionStatusCard(
          title: l10n.batteryOptimizationTitle,
          description: l10n.settingsBatteryDesc,
          granted: appState.ignoringBatteryOptimizations,
          onAction: appState.requestBatteryExclusion,
        ),
        const SizedBox(height: 20),
        _SectionHeader(l10n.settingsBackgroundHeader),
        const SizedBox(height: 8),
        _BackgroundReliabilityCard(
          title: l10n.settingsBackgroundTitle,
          body: l10n.settingsBackgroundDesc,
        ),
        const SizedBox(height: 20),
        _SectionHeader(l10n.settingsMonitoredAppsHeader),
        const SizedBox(height: 8),
        _SettingsGroup(
          children: [
            _SwitchRow(
              icon: Icons.chat_bubble_rounded,
              iconColor: Colors.green.shade600,
              title: appLabelForPackage(context, pkgWhatsApp),
              value: appState.monitoredApps.contains(pkgWhatsApp),
              onChanged: (v) => appState.setMonitored(pkgWhatsApp, v),
            ),
            const _RowDivider(),
            _SwitchRow(
              icon: Icons.business_center_rounded,
              iconColor: Colors.teal.shade600,
              title: appLabelForPackage(context, pkgWhatsAppBusiness),
              value: appState.monitoredApps.contains(pkgWhatsAppBusiness),
              onChanged: (v) => appState.setMonitored(pkgWhatsAppBusiness, v),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionHeader(l10n.settingsLanguageHeader),
        const SizedBox(height: 8),
        _SettingsGroup(
          children: [
            _RowContainer(
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
                  ButtonSegment(value: 'hi', label: Text(l10n.languageHindi)),
                ],
                selected: {currentLanguage},
                onSelectionChanged: (selection) {
                  appState.setLocale(Locale(selection.first));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionHeader(l10n.settingsDataHeader),
        const SizedBox(height: 8),
        _SettingsGroup(
          children: [
            _NavRow(
              icon: Icons.delete_forever_rounded,
              iconColor: Theme.of(context).colorScheme.error,
              title: l10n.clearAllDataTitle,
              subtitle: l10n.clearAllDataSubtitle,
              onTap: () async {
                final confirmed = await showAppConfirmDialog(
                  context,
                  icon: Icons.delete_forever_rounded,
                  title: l10n.clearAllDialogTitle,
                  message: l10n.clearAllDialogContent,
                  cancelLabel: l10n.cancelButton,
                  confirmLabel: l10n.clearButton,
                  danger: true,
                );
                if (confirmed == true) {
                  await appState.clearAll();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionHeader(l10n.settingsHowItWorksHeader),
        const SizedBox(height: 8),
        _SettingsGroup(
          children: [
            _ExplainerRow(
              icon: Icons.radar_rounded,
              iconColor: Colors.indigo.shade400,
              title: l10n.settingsHowItWorksDetectionTitle,
              body: l10n.settingsHowItWorksDetectionBody,
            ),
            const _RowDivider(),
            _ExplainerRow(
              icon: Icons.edit_note_rounded,
              iconColor: Colors.amber.shade700,
              title: l10n.settingsHowItWorksEditedTitle,
              body: l10n.settingsHowItWorksEditedBody,
            ),
            const _RowDivider(),
            _ExplainerRow(
              icon: Icons.perm_media_rounded,
              iconColor: Colors.lightBlue.shade600,
              title: l10n.settingsHowItWorksMediaTitle,
              body: l10n.settingsHowItWorksMediaBody,
            ),
            const _RowDivider(),
            _ExplainerRow(
              icon: Icons.lock_rounded,
              iconColor: Colors.green.shade600,
              title: l10n.settingsHowItWorksPrivacyTitle,
              body: l10n.settingsHowItWorksPrivacyBody,
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Rounded card that groups a set of rows, matching the reference app's
/// grouped settings sections.
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _BackgroundReliabilityCard extends StatelessWidget {
  final String title;
  final String body;

  const _BackgroundReliabilityCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = Colors.orange.shade600;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.battery_alert_rounded, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: NativeBridge.openBackgroundAppSettings,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(l10n.settingsBackgroundAction),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 60,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
  }
}

class _RowContainer extends StatelessWidget {
  final Widget child;

  const _RowContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: child,
    );
  }
}

class _RowIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _RowIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            _RowIcon(icon: icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _RowIcon(icon: icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// One point in the "How this works" explainer -- a bold headline over a
/// short description, each with its own icon, instead of one long paragraph
/// covering detection, edits, media, and privacy all at once.
class _ExplainerRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  const _ExplainerRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RowIcon(icon: icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

