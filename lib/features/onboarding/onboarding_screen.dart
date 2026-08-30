import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../l10n/generated/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  final _controller = PageController();
  int _page = 0;
  static const _pageCount = 3;
  static const _notificationAccessPage = 1;
  bool _batteryPromptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().refreshPermissions();
    }
  }

  void _advance() {
    if (_page == _pageCount - 1) return;
    _controller.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  void _onNextPressed() {
    final appState = context.read<AppState>();
    if (_page == _notificationAccessPage && !appState.notificationAccessGranted) {
      appState.requestNotificationAccess();
      return;
    }
    _advance();
  }

  /// Battery exclusion is only "Recommended", so the first tap offers the
  /// system dialog for it, but a user who declines (or has already seen it)
  /// isn't blocked from finishing onboarding on a second tap.
  void _onGetStartedPressed() {
    final appState = context.read<AppState>();
    if (!appState.ignoringBatteryOptimizations && !_batteryPromptShown) {
      _batteryPromptShown = true;
      appState.requestBatteryExclusion();
      return;
    }
    appState.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context);
    final isLast = _page == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _IntroSlide(),
                  _PermissionSlide(
                    icon: Icons.notifications_active_rounded,
                    tag: l10n.permissionRequiredTag,
                    tagColor: Theme.of(context).colorScheme.error,
                    title: l10n.notificationAccessTitle,
                    description: l10n.notificationAccessDescription,
                    granted: appState.notificationAccessGranted,
                    grantedLabel: l10n.notificationAccessGrantedLabel,
                    actionLabel: l10n.notificationAccessActionLabel,
                    onAction: appState.requestNotificationAccess,
                  ),
                  _PermissionSlide(
                    icon: Icons.battery_charging_full_rounded,
                    tag: l10n.permissionRecommendedTag,
                    tagColor: Theme.of(context).colorScheme.tertiary,
                    title: l10n.batteryOptimizationTitle,
                    description: l10n.batteryOptimizationDescription,
                    granted: appState.ignoringBatteryOptimizations,
                    grantedLabel: l10n.batteryOptimizationGrantedLabel,
                    actionLabel: l10n.batteryOptimizationActionLabel,
                    onAction: appState.requestBatteryExclusion,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  _DotsIndicator(count: _pageCount, index: _page),
                  const Spacer(),
                  if (!isLast)
                    FilledButton.icon(
                      onPressed: _onNextPressed,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(l10n.nextButton),
                    )
                  else
                    FilledButton(
                      onPressed: appState.notificationAccessGranted ? _onGetStartedPressed : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(l10n.getStartedButton),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int index;

  const _DotsIndicator({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 6),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? color : color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

/// Single combined intro slide: what the app does, how it works, and the
/// privacy story -- all in one screen instead of three separate ones.
class _IntroSlide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.forum_rounded, size: 48, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.onboardingIntroTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.onboardingIntroDescription,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          _FeatureRow(
            icon: Icons.history_toggle_off_rounded,
            color: scheme.secondary,
            title: l10n.onboardingHowItWorksTitle,
            description: l10n.onboardingHowItWorksDescription,
          ),
          const SizedBox(height: 20),
          _FeatureRow(
            icon: Icons.lock_rounded,
            color: scheme.tertiary,
            title: l10n.onboardingPrivacyTitle,
            description: l10n.onboardingPrivacyDescription,
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single full-page permission step: big status icon, a required/recommended
/// tag, description, and either an action button or a "granted" confirmation.
class _PermissionSlide extends StatelessWidget {
  final IconData icon;
  final String tag;
  final Color tagColor;
  final String title;
  final String description;
  final bool granted;
  final String grantedLabel;
  final String actionLabel;
  final VoidCallback onAction;

  const _PermissionSlide({
    required this.icon,
    required this.tag,
    required this.tagColor,
    required this.title,
    required this.description,
    required this.granted,
    required this.grantedLabel,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final green = Colors.green.shade600;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: granted ? green.withValues(alpha: 0.15) : theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              granted ? Icons.check_circle_rounded : icon,
              size: 52,
              color: granted ? green : theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tag,
              style: theme.textTheme.labelMedium?.copyWith(
                color: tagColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          if (granted)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: green, size: 20),
                const SizedBox(width: 8),
                Text(
                  grantedLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else
            FilledButton(
              onPressed: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(actionLabel),
              ),
            ),
        ],
      ),
    );
  }
}
