import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// Covers HomeShell for [duration] right after onboarding, then calls
/// [onDone]. HomeShell is already built underneath, so its first screen and
/// native ad load while this is up -- the job the old app tour page did.
class FirstRunLoader extends StatefulWidget {
  final Duration duration;
  final VoidCallback onDone;

  const FirstRunLoader({
    super.key,
    this.duration = const Duration(seconds: 3),
    required this.onDone,
  });

  @override
  State<FirstRunLoader> createState() => _FirstRunLoaderState();
}

class _FirstRunLoaderState extends State<FirstRunLoader> {
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    // Blocks touches to the screen underneath while it's up.
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 88,
                    height: 88,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.forum_rounded,
                      size: 72,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  l10n.firstRunLoaderTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.firstRunLoaderBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: scheme.primary.withValues(alpha: 0.15),
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
