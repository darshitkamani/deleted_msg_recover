import 'package:intl/intl.dart';
import 'package:preload_google_ads/preload_google_ads.dart' hide AppState;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../core/models/chat.dart';
import '../../core/models/edited_deleted_message.dart';
import '../../core/models/media_type.dart';
import '../../core/native_bridge.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/app_tab_switcher.dart';
import '../../widgets/chat_avatar.dart';
import '../../widgets/error_state.dart';
import '../../widgets/welcome_chat_tile.dart';

/// Every edited or deleted message, aggregated across every chat and grouped
/// by day, then by chat within each day -- unlike ChatsListScreen/ChatDetailScreen, which
/// are scoped one conversation at a time, this pulls the same cross-chat
/// aggregate view the Recover grid already uses for media (see
/// NativeBridge.getEditedOrDeletedMessages), just for edits/deletions.
class DeletedFeedScreen extends StatefulWidget {
  const DeletedFeedScreen({super.key});

  @override
  State<DeletedFeedScreen> createState() => _DeletedFeedScreenState();
}

class _DeletedFeedScreenState extends State<DeletedFeedScreen> {
  String _package = pkgWhatsApp;
  bool _loading = true;
  Object? _error;
  List<EditedDeletedMessage> _items = [];
  int? _seenRevision;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This tab is built once and then kept alive by HomeShell's IndexedStack,
    // so without this it would keep showing whatever it loaded on first
    // visit -- new deletions would only appear after a manual pull-to-refresh.
    // AppState bumps dataRevision on every native message event and app
    // resume; reload quietly (no spinner) whenever it moves.
    final revision = context.watch<AppState>().dataRevision;
    if (_seenRevision != null && revision != _seenRevision) {
      _load(silent: true);
    }
    _seenRevision = revision;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await NativeBridge.getEditedOrDeletedMessages(
        package: _package,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // A failed background reload keeps showing the last good list.
      if (silent) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _switchPackage(String package) {
    if (package == _package) return;
    setState(() => _package = package);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    // Groups by day, then by chat within that day -- by chat rather than by
    // sender because the profile photo is captured per chat (contact or
    // group photo), so each group header can show the same avatar the chat
    // list does; a group chat's rows still name their own sender. Insertion
    // order follows the source list, which is already most-recent-first, so
    // days, the chats within a day, and each chat's rows all stay
    // chronological.
    final days = <DateTime, Map<String, List<EditedDeletedMessage>>>{};
    for (final item in _items) {
      final time = DateTime.fromMillisecondsSinceEpoch(item.timestamp);
      final day = DateTime(time.year, time.month, time.day);
      days
          .putIfAbsent(day, () => {})
          .putIfAbsent(item.chatKey, () => [])
          .add(item);
    }
    final chatsByKey = {
      for (final chat in context.watch<AppState>().chats) chat.chatKey: chat,
    };

    // No own Scaffold/AppBar -- like every other bottom-nav tab body
    // (ChatsListScreen, StatusesScreen), this is rendered inside HomeShell's
    // single shared Scaffold, which already supplies the app bar for
    // whichever tab is selected.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: AppTabSwitcher(
            selected: _package,
            onChanged: _switchPackage,
            options: [
              AppTabOption(
                value: pkgWhatsApp,
                label: appLabelForPackage(context, pkgWhatsApp),
              ),
              AppTabOption(
                value: pkgWhatsAppBusiness,
                label: appLabelForPackage(context, pkgWhatsAppBusiness),
              ),
            ],
          ),
        ),
        Expanded(
          child: _error != null
              ? ErrorState(error: _error!, onRetry: _load)
              : _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _DeletedFeedList(days: days, chatsByKey: chatsByKey),
                ),
        ),
      ],
    );
  }
}

class _DeletedFeedList extends StatelessWidget {
  final Map<DateTime, Map<String, List<EditedDeletedMessage>>> days;

  /// For each group's profile photo and group flag, which the deleted
  /// messages themselves don't carry.
  final Map<String, Chat> chatsByKey;

  const _DeletedFeedList({required this.days, required this.chatsByKey});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      // Always scrollable (even when empty) so pull-to-refresh still works,
      // same reasoning as StatusesScreen's empty grid.
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: PreloadGoogleAds.instance.showNativeAd(),
        ),
        // Same app-authored explainer tile pinned above ChatsListScreen's
        // real conversations, shown here too -- always present regardless
        // of the WA/WA Business tab or whether anything's been detected yet.
        const WelcomeChatTile(),
        if (days.isEmpty)
          _EmptyState(text: l10n.deletedFeedEmpty)
        else
          for (final day in days.entries) ...[
            _DayHeader(date: day.key),
            for (final group in day.value.entries) ...[
              _ChatHeader(
                chat: chatsByKey[group.key],
                title: group.value.first.chatTitle,
                items: group.value,
              ),
              for (final item in group.value)
                _DeletedFeedRow(
                  item: item,
                  isGroup: chatsByKey[group.key]?.isGroup ?? false,
                ),
            ],
          ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        children: [
          // Same circular-icon illustration convention as
          // ChatsListScreen's empty state, sized up and tinted to this
          // tab's "deleted" theme instead of the neutral one.
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_sweep_rounded,
              size: 44,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The day a run of groups below it belongs to -- same pill as
/// ChatDetailScreen's date divider.
class _DayHeader extends StatelessWidget {
  final DateTime date;

  const _DayHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final String label;
    if (date == today) {
      label = l10n.dateToday;
    } else if (date == yesterday) {
      label = l10n.dateYesterday;
    } else {
      label = DateFormat.yMMMMd().format(date);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF182229) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// One chat's edits/deletions on one day: its profile photo (as in the chat
/// list), name, and how many of that day's messages were deleted.
class _ChatHeader extends StatelessWidget {
  /// Null if the chat isn't in [AppState.chats] (e.g. not loaded yet) --
  /// the avatar then falls back to the letter.
  final Chat? chat;
  final String title;
  final List<EditedDeletedMessage> items;

  const _ChatHeader({
    required this.chat,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final deletedCount = items.where((m) => m.isDeleted).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
      child: Row(
        children: [
          ChatAvatar(
            avatarPath: chat?.avatarPath,
            title: title,
            isGroup: chat?.isGroup ?? false,
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (deletedCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l10n.deletedBadge(deletedCount),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeletedFeedRow extends StatelessWidget {
  final EditedDeletedMessage item;

  /// Whether the row's chat is a group -- the chat name is already in the
  /// header above, so a group's rows name their sender instead.
  final bool isGroup;

  const _DeletedFeedRow({required this.item, required this.isGroup});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Just the time: the day is in the header above.
    final time = DateFormat.Hm().format(
      DateTime.fromMillisecondsSinceEpoch(item.timestamp),
    );
    final sender = isGroup && item.sender?.isNotEmpty == true
        ? item.sender!
        : null;

    // Same rule ChatDetailScreen's message bubble uses: an edited message
    // shows what it originally said as its main content, not the latest
    // text -- that's the whole point of flagging it as edited.
    final displayText = item.isEdited ? item.originalText : item.text;
    final contentLabel = displayText?.isNotEmpty == true
        ? displayText!
        : item.hasMedia
        ? mediaTypeLabel(context, item.mediaType)
        : l10n.deletedFeedNoText;

    return GestureDetector(
      // Debug builds only: long-press shows why this was flagged as deleted.
      onLongPress: kDebugMode && item.isDeleted
          ? () => _showDeleteDiagnostics(context)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // One line: who sent it (group chats only -- a 1:1 chat's name
              // is already in the header above), what happened to it, and
              // when. The message itself goes underneath.
              Row(
                children: [
                  if (sender != null) ...[
                    Flexible(
                      child: Text(
                        sender,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (item.isPossiblyDeleted)
                    _StatusTag(
                      icon: Icons.help_outline_rounded,
                      label: l10n.possiblyDeletedMessageLabel,
                      color: theme.colorScheme.tertiary,
                    )
                  else if (item.isDeleted)
                    _StatusTag(
                      icon: Icons.delete_outline_rounded,
                      label: l10n.deletedMessageLabel,
                      color: theme.colorScheme.error,
                    )
                  else if (item.isEdited)
                    _StatusTag(
                      icon: Icons.edit_outlined,
                      label: l10n.editedBadge,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  const Spacer(),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.hasMedia)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 2),
                      child: Icon(
                        _mediaIcon(item.mediaType),
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      contentLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: item.isDeleted
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface,
                        fontStyle: item.isDeleted
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
              // Shown unconditionally, matching ChatDetailScreen's message
              // bubble: both what it originally said (above, as the main
              // content) and what it was later edited to need to be visible
              // at once, even for a message that was also deleted. Styled
              // the same quote-block way -- a left accent bar with a label
              // above the text, rather than one italic sentence with the
              // new text embedded in quotes.
              if (item.isEdited)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.editedToLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.text ?? '',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDiagnostics(BuildContext context) {
    final report =
        'source: ${item.deleteSource ?? 'unknown (flagged before diagnostics existed)'}\n'
        'text: ${item.text}\n'
        'timestamp: ${item.timestamp}  deletedAt: ${item.deletedAt}\n\n'
        '${item.deleteDetail ?? ''}';
    print("report => $report");
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deletion diagnostics'),
        content: SingleChildScrollView(child: SelectableText(report)),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: report)),
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _mediaIcon(MediaType type) {
    switch (type) {
      case MediaType.image:
      case MediaType.gif:
      case MediaType.sticker:
        return Icons.image_outlined;
      case MediaType.video:
        return Icons.videocam_outlined;
      case MediaType.audio:
        return Icons.mic_none_rounded;
      case MediaType.document:
      case MediaType.none:
        return Icons.insert_drive_file_outlined;
    }
  }
}

class _StatusTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A small tinted pill, so it reads as a label rather than as part of
    // the message.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
