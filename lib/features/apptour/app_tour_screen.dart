import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Shown exactly once, right after onboarding finishes and before the user
/// ever lands on [HomeShell] -- a one-screen "here's what each tab does"
/// primer, distinct from onboarding's permission asks. See [_RootRouter] in
/// app.dart: for a user whose setup is still pending, this page appearing is
/// also the point ads get initialized, so a first-run user sees onboarding
/// before anything ad-related loads.
///
/// The Continue button shows a loader for the first [_continueDelay] the page
/// is on screen, giving the ads initialized above a head start before
/// [HomeShell]'s first native ad slot is built.
class AppTourScreen extends StatefulWidget {
  final VoidCallback onContinue;

  const AppTourScreen({super.key, required this.onContinue});

  @override
  State<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends State<AppTourScreen> {
  static const _continueDelay = Duration(seconds: 3);

  bool _continueReady = false;
  Timer? _continueTimer;

  @override
  void initState() {
    super.initState();
    _continueTimer = Timer(_continueDelay, () {
      if (mounted) setState(() => _continueReady = true);
    });
  }

  @override
  void dispose() {
    _continueTimer?.cancel();
    super.dispose();
  }

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
                  onPressed: _continueReady ? widget.onContinue : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _continueReady
                        ? Text(l10n.appTourContinueButton)
                        : SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
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
