import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:preload_google_ads/preload_google_ads.dart' hide AppState;
import 'package:provider/provider.dart';

import '../../core/ads/ads_service.dart';
import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../core/models/chat.dart';
import '../../l10n/generated/app_localizations.dart';
import '../chats/chat_detail_screen.dart';
import '../chats/chats_list_screen.dart';
import '../paywall/paywall_screen.dart';

/// Landing screen for the Recover tab: three tiles -- Text Message routes to
/// the existing recovered-chats list; Statuses and Direct just jump to their
/// own tabs in [HomeShell].
class RecoverScreen extends StatelessWidget {
  const RecoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    final recentChats = [...appState.chats]
      ..sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
    final capturedCount = appState.chats.fold<int>(
      0,
      (sum, c) => sum + c.totalCount,
    );

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _RecoverHeader(
            title: l10n.recoverTitle,
            subtitle: l10n.recoverTagline,
            plusLabel: l10n.recoverPlusBadge,
            onPlus: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PaywallScreen())),
            onSettings: () =>
                context.read<AppState>().goToTab(homeShellSettingsTabIndex),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _RecoverTile(
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RecoverTile(
                        icon: Icons.donut_large_rounded,
                        color: Colors.indigo.shade400,
                        label: l10n.navStatuses,
                        onTap: () => context.read<AppState>().goToTab(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RecoverTile(
                        icon: Icons.send_rounded,
                        color: Colors.lightBlue.shade600,
                        label: l10n.navDirectChat,
                        onTap: () => context.read<AppState>().goToTab(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(minHeight: 100),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: PreloadGoogleAds.instance.showNativeAd(
                    // preloader: AdsService.instance.recoverAdPreloader,
                  ),
                ),

                if (!appState.notificationAccessGranted) ...[
                  const SizedBox(height: 20),
                  _PermissionBanner(
                    title: l10n.recoverPermissionBannerTitle,
                    body: l10n.recoverPermissionBannerBody,
                    actionLabel: l10n.recoverPermissionBannerAction,
                    onTap: appState.requestNotificationAccess,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.forum_rounded,
                        value: '${appState.chats.length}',
                        label: l10n.recoverStatsMonitored,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.mark_chat_read_rounded,
                        value: '$capturedCount',
                        label: l10n.recoverStatsCaptured,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.recoverRecentActivityTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (recentChats.isNotEmpty)
                      TextButton(
                        onPressed: () => context.read<AppState>().goToTab(1),
                        child: Text(l10n.recoverSeeAll),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (recentChats.isEmpty)
                  _EmptyActivityCard(
                    title: l10n.recoverEmptyTitle,
                    body: l10n.recoverEmptyBody,
                  )
                else
                  for (final chat in recentChats.take(3))
                    _RecentActivityTile(
                      chat: chat,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(chat: chat),
                        ),
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

/// Wraps a tab-body screen (built to live inside [HomeShell]'s IndexedStack,
/// with no [Scaffold] of its own) with a real app bar so it can also be
/// pushed as a standalone route from the Recover tiles.
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

    return Container(
      width: double.infinity,
      color: scheme.primary,
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _RecoveryPlusPill(label: plusLabel, onTap: onPlus),
          const SizedBox(width: 4),
          Tooltip(
            message: l10n.navSettings,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onSettings,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.settings_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Warns that notification access -- the one permission the whole app
/// depends on -- isn't granted yet, right on the landing screen rather than
/// only inside Settings, since without it nothing ever gets recovered.
class _PermissionBanner extends StatelessWidget {
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onTap;

  const _PermissionBanner({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amber = Colors.amber.shade800;

    return Material(
      color: Colors.amber.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notifications_off_rounded, color: amber, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: amber,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(body, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Text(
                      actionLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
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

/// Shown in place of the recent-activity list before any chat has ever been
/// captured -- the landing screen's emptiest moment, so it gets an explicit
/// explanation rather than just trailing off into blank space.
class _EmptyActivityCard extends StatelessWidget {
  final String title;
  final String body;

  const _EmptyActivityCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 34,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact preview row for one chat in the landing screen's recent-activity
/// list -- a smaller cousin of ChatsListScreen's own tile, with an extra
/// deleted/edited badge so the landing screen shows off what this app
/// actually caught, not just a plain chat list.
class _RecentActivityTile extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;

  const _RecentActivityTile({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final time = chat.lastTimestamp > 0
        ? _formatTime(chat.lastTimestamp, l10n)
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    chat.isGroup ? Icons.group_rounded : Icons.person_rounded,
                    size: 18,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (chat.lastIsDeleted)
                            _Badge(
                              color: Colors.redAccent,
                              icon: Icons.delete_outline_rounded,
                            )
                          else if (chat.lastIsEdited)
                            _Badge(
                              color: Colors.orange.shade600,
                              icon: Icons.edit_rounded,
                            ),
                          if (chat.lastIsDeleted || chat.lastIsEdited)
                            const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              chat.lastText?.isNotEmpty == true
                                  ? chat.lastText!
                                  : '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatTime(int timestampMs, AppLocalizations l10n) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
    if (isToday) return DateFormat.Hm().format(date);
    if (isYesterday) return l10n.dateYesterday;
    return DateFormat('MMM d').format(date);
  }
}

class _Badge extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _Badge({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 13, color: color);
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
