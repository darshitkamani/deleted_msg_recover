import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// A floating, animated "update ready to install" banner -- shown as an
/// [Overlay] entry rather than a plain [SnackBar], so it can carry the same
/// rounded-card, icon-badge look the rest of this app uses (see
/// WelcomeChatTile, the exit-confirmation dialog) instead of a generic
/// Material toast, and slides in on its own schedule regardless of which
/// screen happens to have a Scaffold under it.
class UpdateReadyBanner {
  UpdateReadyBanner._();

  /// Shows the banner above everything else in the app. [onRestart] is only
  /// called if the user taps the action -- dismissing it (the close button)
  /// just removes it, since the update stays downloaded and installs on
  /// the app's next natural restart regardless.
  static void show(BuildContext context, {required VoidCallback onRestart}) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _UpdateReadyBannerContent(
        onRestart: () {
          entry.remove();
          onRestart();
        },
        onDismiss: () => entry.remove(),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
  }
}

class _UpdateReadyBannerContent extends StatefulWidget {
  final VoidCallback onRestart;
  final VoidCallback onDismiss;

  const _UpdateReadyBannerContent({
    required this.onRestart,
    required this.onDismiss,
  });

  @override
  State<_UpdateReadyBannerContent> createState() =>
      _UpdateReadyBannerContentState();
}

class _UpdateReadyBannerContentState extends State<_UpdateReadyBannerContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Plays the entrance animation in reverse before actually removing the
  /// overlay entry, so dismissing (either button) doesn't just pop the
  /// card out instantly.
  Future<void> _dismiss(VoidCallback after) async {
    await _controller.reverse();
    after();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottomInset + 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.82),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.updateReadyMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => _dismiss(widget.onRestart),
                    child: Text(
                      l10n.updateReadyAction,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _dismiss(widget.onDismiss),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
