import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../l10n/generated/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final _controller = PageController();
  int _page = 0;

  /// The intro (which also covers notification access), then battery.
  static const _pageCount = 2;
  static const _notificationAccessPage = 0;

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

  /// Shows the system battery-optimization dialog and, once the user has
  /// answered it, finishes onboarding. Battery exclusion is only
  /// "Recommended", so allow and deny both move on -- and so does a dialog
  /// that couldn't be shown at all, rather than leaving the user stuck here.
  Future<void> _requestBatteryExclusion() async {
    final appState = context.read<AppState>();
    try {
      await appState.requestBatteryExclusion();
    } catch (_) {
      // Treated like a denial, see above.
    }
    await appState.refreshPermissions();
    await appState.completeOnboarding();
  }

  void _advance() {
    if (_page == _pageCount - 1) return;
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _onNextPressed() {
    final appState = context.read<AppState>();
    if (_page == _notificationAccessPage &&
        !appState.notificationAccessGranted) {
      appState.requestNotificationAccess();
      return;
    }
    _advance();
  }

  /// Offers the battery dialog (which finishes onboarding once answered),
  /// unless it's already excluded, in which case there's nothing to ask.
  void _onGetStartedPressed() {
    final appState = context.read<AppState>();
    if (!appState.ignoringBatteryOptimizations) {
      _requestBatteryExclusion();
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
                  // Next here opens notification access until it's granted
                  // (see _onNextPressed), then moves on.
                  _IntroSlide(
                    notificationAccessGranted:
                        appState.notificationAccessGranted,
                    onAllowNotificationAccess:
                        appState.requestNotificationAccess,
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
                    onAction: _requestBatteryExclusion,
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
                      onPressed: appState.notificationAccessGranted
                          ? _onGetStartedPressed
                          : null,
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

/// The first page: the app's real flow in three steps, each with a small
/// mock of what the user actually sees -- the WhatsApp notification, the
/// "This message was deleted" bubble, and the row in this app's Deleted tab --
/// and, below it, the notification access that step 1 relies on, which this
/// page's Next asks for.
class _IntroSlide extends StatelessWidget {
  final bool notificationAccessGranted;
  final VoidCallback onAllowNotificationAccess;

  const _IntroSlide({
    required this.notificationAccessGranted,
    required this.onAllowNotificationAccess,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.onboardingSimpleTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.onboardingSimpleBody,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          _FlowStep(
            number: 1,
            label: l10n.onboardingFlowStep1,
            child: const _NotificationMock(),
          ),
          _FlowStep(
            number: 2,
            label: l10n.onboardingFlowStep2,
            child: const _DeletedBubbleMock(),
          ),
          _FlowStep(
            number: 3,
            label: l10n.onboardingFlowStep3,
            isLast: true,
            child: const _RecoveredRowMock(),
          ),
          const SizedBox(height: 4),
          _NotificationAccessRow(
            granted: notificationAccessGranted,
            onTap: onAllowNotificationAccess,
          ),
        ],
      ),
    );
  }
}

/// Notification access, on the intro page, drawn like the row the user is
/// about to switch on in Android's "Notification access" screen: this app's
/// icon and name with a switch -- off until it's granted -- and one line
/// saying what to do. Tapping it opens that screen too, same as Next.
class _NotificationAccessRow extends StatelessWidget {
  final bool granted;
  final VoidCallback onTap;

  const _NotificationAccessRow({required this.granted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final green = Colors.green.shade600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: granted ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 36,
                      height: 36,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.forum_rounded,
                        size: 36,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.appTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.notificationAccessTitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Shows the state; the tap goes to the row (the real switch
                  // is in Android's screen).
                  IgnorePointer(
                    child: Switch(value: granted, onChanged: (_) {}),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              granted ? Icons.check_circle_rounded : Icons.touch_app_rounded,
              size: 16,
              color: granted ? green : scheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                granted
                    ? l10n.notificationAccessGrantedLabel
                    : l10n.onboardingNotificationHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: granted ? green : scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One step of the flow: a numbered dot on a line that joins the steps,
/// a short label, and the mock below it.
class _FlowStep extends StatelessWidget {
  final int number;
  final String label;
  final Widget child;
  final bool isLast;

  const _FlowStep({
    required this.number,
    required this.label,
    required this.child,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: scheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 16 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared look of the mocks: a softly outlined card.
class _MockCard extends StatelessWidget {
  final Widget child;
  final Color? color;

  const _MockCard({required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}

/// Step 1: an Android notification from WhatsApp.
class _NotificationMock extends StatelessWidget {
  const _NotificationMock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    const whatsappGreen = Color(0xFF25D366);

    return _MockCard(
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: whatsappGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.onboardingDemoName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${l10n.onboardingFlowNow}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.onboardingDemoMessage,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 2: WhatsApp's placeholder once the sender deletes it.
class _DeletedBubbleMock extends StatelessWidget {
  const _DeletedBubbleMock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded, size: 15, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                l10n.deletedMessageLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 3: the same message as this app's Deleted tab shows it.
class _RecoveredRowMock extends StatelessWidget {
  const _RecoveredRowMock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return _MockCard(
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primary,
            child: Text(
              l10n.onboardingDemoName.characters.first,
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.onboardingDemoName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.deletedBadge(1),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.onboardingDemoMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
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
              color: granted
                  ? green.withValues(alpha: 0.15)
                  : theme.colorScheme.primaryContainer,
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
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Text(actionLabel),
              ),
            ),
        ],
      ),
    );
  }
}
