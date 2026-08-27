import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../core/native_bridge.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/permission_status_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context);
    final currentLanguage = appState.locale?.languageCode ?? Localizations.localeOf(context).languageCode;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(l10n.settingsPermissionsHeader, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        PermissionStatusCard(
          title: l10n.notificationAccessTitle,
          description: l10n.settingsNotificationAccessDesc,
          granted: appState.notificationAccessGranted,
          actionLabel: l10n.openSettingsAction,
          onAction: appState.requestNotificationAccess,
        ),
        PermissionStatusCard(
          title: l10n.batteryOptimizationTitle,
          description: l10n.settingsBatteryDesc,
          granted: appState.ignoringBatteryOptimizations,
          actionLabel: l10n.excludeAppAction,
          onAction: appState.requestBatteryExclusion,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(l10n.settingsBackgroundHeader, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l10n.settingsBackgroundDesc),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: OutlinedButton(
            onPressed: NativeBridge.openBackgroundAppSettings,
            child: Text(l10n.settingsBackgroundAction),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(l10n.settingsMonitoredAppsHeader, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        SwitchListTile(
          title: Text(appLabelForPackage(context, pkgWhatsApp)),
          value: appState.monitoredApps.contains(pkgWhatsApp),
          onChanged: (v) => appState.setMonitored(pkgWhatsApp, v),
        ),
        SwitchListTile(
          title: Text(appLabelForPackage(context, pkgWhatsAppBusiness)),
          value: appState.monitoredApps.contains(pkgWhatsAppBusiness),
          onChanged: (v) => appState.setMonitored(pkgWhatsAppBusiness, v),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(l10n.settingsLanguageHeader, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(l10n.settingsDataHeader, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever_outlined),
          title: Text(l10n.clearAllDataTitle),
          subtitle: Text(l10n.clearAllDataSubtitle),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(l10n.clearAllDialogTitle),
                content: Text(l10n.clearAllDialogContent),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.cancelButton),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(l10n.clearButton),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await appState.clearAll();
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(l10n.settingsHowItWorksHeader, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l10n.settingsHowItWorksBody),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
