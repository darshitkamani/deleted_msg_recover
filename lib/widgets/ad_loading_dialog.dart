import 'dart:ui';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// What the user is waiting on behind [showAdLoadingDialog] -- picks the icon
/// and the wording of the message.
enum AdLoadingAction { download, share }

/// Shown while the ad that gates a status download/share is being requested,
/// so the tap visibly does something instead of the app just sitting there.
/// Same look as [showAppConfirmDialog] (blurred backdrop, rounded card,
/// gradient icon medallion, soft entrance), with a progress ring around the
/// medallion and a progress bar under the message.
///
/// Not dismissible: whoever opens it closes it (with
/// `Navigator.of(context, rootNavigator: true).pop()`) as soon as the ad has
/// loaded or given up, so it can never get stuck open.
void showAdLoadingDialog(
  BuildContext context, {
  required AdLoadingAction action,
}) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 220),
    useRootNavigator: true,
    pageBuilder: (dialogContext, _, _) =>
        PopScope(canPop: false, child: _AdLoadingDialog(action: action)),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 4 * animation.value,
          sigmaY: 4 * animation.value,
        ),
        child: FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.88, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

class _AdLoadingDialog extends StatelessWidget {
  final AdLoadingAction action;

  const _AdLoadingDialog({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final accent = scheme.primary;
    final accentDark = Color.lerp(accent, Colors.black, 0.25)!;
    final isDownload = action == AdLoadingAction.download;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 26),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.28),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 92,
              height: 92,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 92,
                    height: 92,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      strokeCap: StrokeCap.round,
                      color: accent,
                      backgroundColor: accent.withValues(alpha: 0.15),
                    ),
                  ),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent, accentDark],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      isDownload ? Icons.download_rounded : Icons.share_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              l10n.adLoadingTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isDownload ? l10n.adLoadingDownloadBody : l10n.adLoadingShareBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 4,
                color: accent,
                backgroundColor: accent.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
