import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../core/models/chat.dart';
import '../../l10n/generated/app_localizations.dart';
import 'chat_detail_screen.dart';

class ChatsListScreen extends StatelessWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return RefreshIndicator(
      onRefresh: appState.refreshData,
      child: appState.chats.isEmpty
          ? const _EmptyChats()
          : ListView.separated(
              itemCount: appState.chats.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _ChatTile(chat: appState.chats[index]),
            ),
    );
  }
}

/// Centered empty state for the Chats tab. Plain [ListView] children are
/// left-aligned by default, which is why the old version had its icon
/// pinned to the left edge while only the text below it was centered --
/// this wraps everything in a full-height [Center] instead, while staying
/// inside a scroll view so pull-to-refresh still works.
class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 40,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppLocalizations.of(context).chatsEmptyState,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Chat chat;

  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    final time = chat.lastTimestamp > 0
        ? DateFormat(
            'MMM d, HH:mm',
          ).format(DateTime.fromMillisecondsSinceEpoch(chat.lastTimestamp))
        : '';

    return ListTile(
      leading: CircleAvatar(
        child: Icon(chat.isGroup ? Icons.group : Icons.person),
      ),
      title: Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        chat.lastText?.isNotEmpty == true
            ? chat.lastText!
            : appLabelForPackage(context, chat.package),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(time, style: Theme.of(context).textTheme.labelSmall),
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)));
      },
    );
  }
}
