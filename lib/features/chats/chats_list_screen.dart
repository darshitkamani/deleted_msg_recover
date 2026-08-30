import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../core/models/chat.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/app_tab_switcher.dart';
import '../../widgets/error_state.dart';
import 'chat_detail_screen.dart';
import 'welcome_chat_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  String _package = pkgWhatsApp;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final chats = appState.chats.where((c) => c.package == _package).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: AppTabSwitcher(
            selected: _package,
            onChanged: (p) => setState(() => _package = p),
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
          child: RefreshIndicator(
            onRefresh: appState.refreshData,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              // The welcome chat is always pinned first, regardless of the
              // WA/WA Business tab or whether any real chats have been
              // captured yet -- it's app-authored content, not tied to
              // either package.
              itemCount: chats.length + 1 + (chats.isEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == 0) return const _WelcomeChatTile();
                if (chats.isEmpty) {
                  return appState.chatsError != null
                      ? ErrorState(
                          error: appState.chatsError!,
                          onRetry: appState.refreshData,
                        )
                      : const _EmptyChatsNotice();
                }
                return _ChatTile(chat: chats[index - 1]);
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Inline empty-state notice shown under the always-pinned welcome chat when
/// no real chats have been captured yet for the selected package.
class _EmptyChatsNotice extends StatelessWidget {
  const _EmptyChatsNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 32,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).chatsEmptyState,
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

/// App-authored "chat" pinned above every real recovered conversation --
/// tapping it opens [WelcomeChatScreen], a WhatsApp-styled explainer of what
/// the app does. Always shown, regardless of the WA/WA Business tab.
class _WelcomeChatTile extends StatelessWidget {
  const _WelcomeChatTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WelcomeChatScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.welcomeChatTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.welcomeChatPreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat.Md().format(DateTime.now()),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(Icons.done_all_rounded, size: 16, color: Colors.orange.shade600),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

    final theme = Theme.of(context);
    final previewText = chat.lastText?.isNotEmpty == true
        ? chat.lastText!
        : appLabelForPackage(context, chat.package);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    chat.isGroup ? Icons.group_rounded : Icons.person_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (chat.lastIsDeleted)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                size: 14,
                                color: theme.colorScheme.error,
                              ),
                            )
                          else if (chat.lastIsEdited)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              // The icon already flags deleted/edited -- the
                              // text itself stays the actual recovered
                              // content, same as the chat detail bubble,
                              // rather than being replaced by a generic label.
                              previewText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: chat.lastIsDeleted
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurfaceVariant,
                                fontStyle: chat.lastIsDeleted
                                    ? FontStyle.italic
                                    : FontStyle.normal,
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
                    color: theme.colorScheme.onSurfaceVariant,
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
