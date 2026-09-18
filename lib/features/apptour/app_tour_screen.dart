import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Shown exactly once, right after onboarding finishes and before the user
/// ever lands on [HomeShell] -- a one-screen "here's what each tab does"
/// primer, distinct from onboarding's permission asks. See [_RootRouter] in
/// app.dart: this is also the point ads get initialized (via [onContinue]),
/// so a first-run user sees this explainer before anything ad-related loads.
class AppTourScreen extends StatelessWidget {
  final VoidCallback onContinue;

  const AppTourScreen({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final features = [
      _TourFeature(
        icon: Icons.restore_rounded,
        color: scheme.primary,
        title: l10n.appTourFeatureRecoverTitle,
        description: l10n.appTourFeatureRecoverDescription,
      ),
      _TourFeature(
        icon: Icons.chat_bubble_rounded,
        color: scheme.secondary,
        title: l10n.appTourFeatureChatsTitle,
        description: l10n.appTourFeatureChatsDescription,
      ),
      _TourFeature(
        icon: Icons.donut_large_rounded,
        color: scheme.tertiary,
        title: l10n.appTourFeatureStatusesTitle,
        description: l10n.appTourFeatureStatusesDescription,
      ),
      _TourFeature(
        icon: Icons.send_rounded,
        color: Colors.deepPurple,
        title: l10n.appTourFeatureDirectChatTitle,
        description: l10n.appTourFeatureDirectChatDescription,
      ),
      _TourFeature(
        icon: Icons.settings_rounded,
        color: scheme.onSurfaceVariant,
        title: l10n.appTourFeatureSettingsTitle,
        description: l10n.appTourFeatureSettingsDescription,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.explore_rounded,
                        size: 42,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.appTourTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.appTourSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    for (final feature in features)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _FeatureRow(feature: feature),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onContinue,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l10n.appTourContinueButton),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TourFeature {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _TourFeature({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

class _FeatureRow extends StatelessWidget {
  final _TourFeature feature;

  const _FeatureRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: feature.color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(feature.icon, size: 22, color: feature.color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feature.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                feature.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
