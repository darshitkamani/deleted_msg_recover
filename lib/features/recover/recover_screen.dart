import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../core/models/media_type.dart';
import '../../l10n/generated/app_localizations.dart';
import '../chats/chats_list_screen.dart';
import '../paywall/paywall_screen.dart';
import 'media_folder_screen.dart';
import 'media_recovery_screen.dart';

/// Landing screen for the Recover tab: a grid of recovery categories,
/// mirroring the reference app's "Message Recovery" screen. Text Message
/// routes to the existing recovered-chats list; Voice Message uses
/// [MediaRecoveryScreen] (media captured from notifications, aggregated
/// across chats); Photo/Video/Files/Stickers & GIFs use [MediaFolderScreen]
/// instead, which scans WhatsApp's own Media folder on disk so it also
/// catches files whose message was deleted but whose download survived.
class RecoverScreen extends StatelessWidget {
  const RecoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _RecoverHeader(
            title: l10n.recoverTitle,
            subtitle: l10n.recoverTagline,
            plusLabel: l10n.recoverPlusBadge,
            onPlus: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PaywallScreen()),
            ),
            onSettings: () =>
                context.read<AppState>().goToTab(homeShellSettingsTabIndex),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _SectionHeader(l10n.recoverChatRecoveryHeader),
                const SizedBox(height: 10),
                _TileRow(
                  tiles: [
                    _RecoverTile(
                      icon: Icons.chat_bubble_rounded,
                      color: Colors.green.shade600,
                      label: l10n.recoverTextMessage,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _TitledScreen(
                            title: l10n.recoverTextMessage,
                            child: const ChatsListScreen(),
                          ),
                        ),
                      ),
                    ),
                    _RecoverTile(
                      icon: Icons.graphic_eq_rounded,
                      color: Colors.indigo.shade400,
                      label: l10n.recoverVoiceMessage,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MediaRecoveryScreen(
                            title: l10n.recoverVoiceMessage,
                            mediaTypes: const [MediaType.audio],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SectionHeader(l10n.recoverMediaRecoveryHeader),
                const SizedBox(height: 10),
                _TileRow(
                  tiles: [
                    _RecoverTile(
                      icon: Icons.image_rounded,
                      color: Colors.orange.shade600,
                      label: l10n.recoverPhoto,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              MediaFolderScreen(kind: 'photo', title: l10n.recoverPhoto),
                        ),
                      ),
                    ),
                    _RecoverTile(
                      icon: Icons.videocam_rounded,
                      color: Colors.lightBlue.shade600,
                      label: l10n.recoverVideo,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              MediaFolderScreen(kind: 'video', title: l10n.recoverVideo),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SectionHeader(l10n.recoverMoreHeader),
                const SizedBox(height: 10),
                _TileRow(
                  tiles: [
                    _RecoverTile(
                      icon: Icons.folder_rounded,
                      color: Colors.amber.shade700,
                      label: l10n.recoverFiles,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              MediaFolderScreen(kind: 'files', title: l10n.recoverFiles),
                        ),
                      ),
                    ),
                    _RecoverTile(
                      icon: Icons.gif_box_rounded,
                      color: Colors.teal.shade500,
                      label: l10n.recoverStickersGifs,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MediaFolderScreen(
                            kind: 'stickersGifs',
                            title: l10n.recoverStickersGifs,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a tab-body screen (built to live inside [HomeShell]'s IndexedStack,
/// with no [Scaffold] of its own) with a real app bar so it can also be
/// pushed as a standalone route from the Recover grid.
class _TitledScreen extends StatelessWidget {
  final String title;
  final Widget child;

  const _TitledScreen({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

/// Gradient banner header for the Recover tab -- just the title, tagline,
/// and the Recovery+ pill. Direct Chat used to live here as an unlabeled
/// send icon, which read as unexplained clutter; it's now a proper labeled
/// tile in the grid below instead.
class _RecoverHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String plusLabel;
  final VoidCallback onPlus;
  final VoidCallback onSettings;

  const _RecoverHeader({
    required this.title,
    required this.subtitle,
    required this.plusLabel,
    required this.onPlus,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final deep = Color.lerp(scheme.primary, Colors.black, 0.25)!;
    final teal = Color.lerp(scheme.primary, Colors.cyan, 0.35)!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [teal, scheme.primary, deep],
                  ),
                ),
              ),
            ),
            // Decorative watermark + soft glows -- purely visual texture so
            // the banner reads as designed rather than a flat color block.
            Positioned(
              right: -30,
              top: -34,
              child: Transform.rotate(
                angle: -0.35,
                child: Icon(
                  Icons.forum_rounded,
                  size: 150,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              left: -40,
              bottom: -50,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              right: 60,
              bottom: -20,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tooltip(
                        message: l10n.navSettings,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: onSettings,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.settings_rounded, size: 20, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _RecoveryPlusPill(label: plusLabel, onTap: onPlus),
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

class _RecoveryPlusPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RecoveryPlusPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _TileRow extends StatelessWidget {
  final List<_RecoverTile> tiles;

  const _TileRow({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _RecoverTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _RecoverTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
