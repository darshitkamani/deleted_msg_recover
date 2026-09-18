import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:preload_google_ads/preload_google_ads.dart' hide AppState;

import '../../core/constants.dart';
import '../../core/models/edited_deleted_message.dart';
import '../../core/models/media_type.dart';
import '../../core/native_bridge.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/app_tab_switcher.dart';
import '../../widgets/error_state.dart';
import '../../widgets/welcome_chat_tile.dart';

/// Every edited or deleted message, aggregated across every chat and grouped
/// by sender ("user wise") -- unlike ChatsListScreen/ChatDetailScreen, which
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await NativeBridge.getEditedOrDeletedMessages(
        package: _package,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
    // Groups by sender, falling back to the chat title when no explicit
    // sender name was captured (a 1:1 chat's own notifications don't always
    // carry a separate person name). Insertion order follows the source
    // list, which is already most-recent-first, so both which group appears
    // first and each group's own row order stay chronological.
    final groups = <String, List<EditedDeletedMessage>>{};
    for (final item in _items) {
      final key = item.sender?.isNotEmpty == true
          ? item.sender!
          : item.chatTitle;
      groups.putIfAbsent(key, () => []).add(item);
    }

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
                  child: _DeletedFeedList(groups: groups),
                ),
        ),
      ],
    );
  }
}

class _DeletedFeedList extends StatelessWidget {
  final Map<String, List<EditedDeletedMessage>> groups;

  const _DeletedFeedList({required this.groups});

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
        if (groups.isEmpty)
          _EmptyState(text: l10n.deletedFeedEmpty)
        else
          for (final entry in groups.entries) ...[
            _SenderHeader(sender: entry.key, items: entry.value),
            for (final item in entry.value) _DeletedFeedRow(item: item),
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

class _SenderHeader extends StatelessWidget {
  final String sender;
  final List<EditedDeletedMessage> items;

  const _SenderHeader({required this.sender, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final deletedCount = items.where((m) => m.isDeleted).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              sender.isNotEmpty ? sender[0].toUpperCase() : '?',
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sender,
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

  const _DeletedFeedRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final time = DateFormat(
      'MMM d, HH:mm',
    ).format(DateTime.fromMillisecondsSinceEpoch(item.timestamp));

    // Same rule ChatDetailScreen's message bubble uses: an edited message
    // shows what it originally said as its main content, not the latest
    // text -- that's the whole point of flagging it as edited.
    final displayText = item.isEdited ? item.originalText : item.text;
    final contentLabel = displayText?.isNotEmpty == true
        ? displayText!
        : item.hasMedia
        ? mediaTypeLabel(context, item.mediaType)
        : l10n.deletedFeedNoText;

    return Container(
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.chatTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  time,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (item.isDeleted)
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
            const SizedBox(height: 4),
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
            // Not shown for a deleted message -- what it was edited *to*
            // doesn't matter once it's also gone; the deleted tag above
            // already covers that.
            if (item.isEdited && !item.isDeleted)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.editedToExplanation(item.text ?? ''),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
