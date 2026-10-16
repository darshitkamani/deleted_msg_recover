import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/demo_samples.dart';
import '../l10n/generated/app_localizations.dart';

/// Asks for the deleted-message popup's permission.
///
/// On the first launch, right after onboarding, it always comes up --
/// [_firstRunDelay] after HomeShell's first-run loader lifts, on the Recover
/// screen. After that, now and then -- not on a fixed schedule, so it doesn't
/// feel like a nag: at most once per launch, on about 1 in [_chanceOneIn]
/// launches, a random 4-10 s after HomeShell shows. Either way only while
/// capturing works but the popup is off, and never on top of another dialog
/// or screen (or the first-run loader).
class OverlayPermissionPrompt {
  OverlayPermissionPrompt._();

  static const _chanceOneIn = 3;
  static const _firstRunDelay = Duration(seconds: 1);
  static const _minDelaySeconds = 4;
  static const _maxDelaySeconds = 10;

  /// Tries again this often (up to [_maxTries]) while something else is on
  /// screen when the delay runs out.
  static const _retryDelay = Duration(seconds: 8);
  static const _maxTries = 4;

  static final _random = Random();

  /// Call once HomeShell is on screen; [context] must be HomeShell's.
  static void maybeSchedule(BuildContext context) {
    final appState = context.read<AppState>();
    if (appState.overlayDialogHandled) return;
    appState.overlayDialogHandled = true;
    if (appState.showFirstRunLoader) {
      _showAfterFirstRunLoader(context, appState);
      return;
    }
    if (_random.nextInt(_chanceOneIn) != 0) return;
    final delay = Duration(
      seconds:
          _minDelaySeconds +
          _random.nextInt(_maxDelaySeconds - _minDelaySeconds + 1),
    );
    Timer(delay, () => _tryShow(context, 1));
  }

  /// First launch: waits for the loader to lift, then shows the dialog.
  static void _showAfterFirstRunLoader(
    BuildContext context,
    AppState appState,
  ) {
    void onChange() {
      if (appState.showFirstRunLoader) return;
      appState.removeListener(onChange);
      Timer(_firstRunDelay, () => _tryShow(context, 1));
    }

    appState.addListener(onChange);
  }

  static void _tryShow(BuildContext context, int attempt) {
    if (!context.mounted) return;
    final appState = context.read<AppState>();
    if (!appState.notificationAccessGranted || appState.overlayActive) return;
    // Not over a dialog, a pushed screen or the first-run loader: wait a bit.
    final onTop = ModalRoute.of(context)?.isCurrent ?? false;
    if (!onTop || appState.showFirstRunLoader) {
      if (attempt < _maxTries) {
        Timer(_retryDelay, () => _tryShow(context, attempt + 1));
      }
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => OverlayPermissionDialog(
        sample: DemoSample.random(context),
        onTurnOn: () => appState.setOverlayEnabled(true),
      ),
    );
  }
}

/// The dialog itself: a picture of the popup, one line on what it does, and
/// Turn on (which opens this app's "Display over other apps" screen) / Not
/// now.
class OverlayPermissionDialog extends StatelessWidget {
  /// Who "deleted" what in the picture of the popup.
  final DemoSample sample;
  final VoidCallback onTurnOn;

  const OverlayPermissionDialog({
    super.key,
    required this.sample,
    required this.onTurnOn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final accent = Colors.green.shade600;

    Widget action(String label) => Expanded(
      child: Container(
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: accent),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The popup, as it looks over another app.
          Container(
            color: scheme.primaryContainer.withValues(alpha: 0.6),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.feedback_rounded,
                        size: 18,
                        color: scheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.overlayDialogPreviewTitle(sample.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(sample.message, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      action(l10n.overlayDialogCopy),
                      const SizedBox(width: 8),
                      action(l10n.overlayDialogOpen),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.overlayDialogTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.overlayDialogBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
            child: SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onTurnOn();
                },
                child: Text(l10n.overlayDialogAction),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.overlayDialogLater),
            ),
          ),
        ],
      ),
    );
  }
}
