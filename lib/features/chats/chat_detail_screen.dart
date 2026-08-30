import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/models/chat.dart';
import '../../core/models/message.dart';
import '../../core/native_bridge.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/error_state.dart';
import '../../widgets/message_bubble.dart';

/// Opening a chat here marks it "opened" -- this is the app's proxy for
/// "the user has seen this", the same way opening WhatsApp itself would,
/// except it doesn't send a read receipt back to the sender.
class ChatDetailScreen extends StatefulWidget {
  final Chat chat;

  const ChatDetailScreen({super.key, required this.chat});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  static const _bottomThreshold = 120.0;

  List<Message>? _messages;
  Object? _error;
  StreamSubscription<Map<dynamic, dynamic>>? _eventSub;
  final _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  bool _jumpToBottomOnNextBuild = true;
  int _unseenNewMessages = 0;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    appState.openChat(widget.chat.chatKey);
    _loadMessages(appState);
    _scrollController.addListener(_handleScroll);
    _eventSub = NativeBridge.events.listen((event) {
      if (event['chatKey'] == widget.chat.chatKey && mounted) {
        final wasAtBottom = _isAtBottom();
        if (event['type'] == 'new') {
          // The user is actively watching this chat, so a message that
          // arrives now has been "seen" -- without this, a message that
          // shows up while the screen is already open would still count as
          // never-opened once its notification is later cleared for any
          // ordinary reason, and get wrongly flagged as deleted.
          appState.openChat(widget.chat.chatKey);
        }
        _loadMessages(
          appState,
          jumpToBottom: wasAtBottom,
          countAsUnseen: !wasAtBottom && event['type'] == 'new',
        );
      }
    });
  }

  // Loads into `_messages` in place rather than swapping out a Future for a
  // FutureBuilder to await -- that used to unmount the ListView (dropping
  // into the loading spinner) on every single incoming message, which tore
  // down and rebuilt the ScrollController's position and made the
  // stay-pinned-to-bottom behavior unreliable.
  Future<void> _loadMessages(
    AppState appState, {
    bool jumpToBottom = true,
    bool countAsUnseen = false,
  }) async {
    try {
      final messages = await appState.loadMessages(widget.chat.chatKey);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _error = null;
        if (jumpToBottom) {
          _jumpToBottomOnNextBuild = true;
          _unseenNewMessages = 0;
        } else if (countAsUnseen) {
          _unseenNewMessages++;
        }
      });
    } catch (e) {
      // Otherwise a throw here (e.g. a stale build missing a platform
      // channel method) leaves `_messages` null forever, and the spinner
      // below never resolves into either the message list or an error.
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _eventSub?.cancel();
    super.dispose();
  }

  // The list is rendered with reverse: true, so the newest message sits at
  // scroll offset 0 -- that's "the bottom" here, not maxScrollExtent.
  bool _isAtBottom() {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels <= _bottomThreshold;
  }

  void _handleScroll() {
    final atBottom = _isAtBottom();
    final shouldShowScrollToBottom = !atBottom;
    if (shouldShowScrollToBottom == _showScrollToBottom &&
        !(atBottom && _unseenNewMessages > 0)) {
      return;
    }
    setState(() {
      _showScrollToBottom = shouldShowScrollToBottom;
      if (atBottom) _unseenNewMessages = 0;
    });
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    const target = 0.0;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
    setState(() => _unseenNewMessages = 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chat.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Tooltip(
              message: AppLocalizations.of(context).noReadReceiptsExplanation,
              child: IconButton(
                icon: const Icon(Icons.visibility_off_outlined, size: 18),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context).noReadReceiptsExplanation,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      backgroundColor: isDark
          ? const Color(0xFF0B141A)
          : const Color(0xFFECE5DD),
      body: Stack(
        children: [
          Builder(
            builder: (context) {
              if (_error != null) {
                return ErrorState(
                  error: _error!,
                  onRetry: () => _loadMessages(context.read<AppState>()),
                );
              }
              final messages = _messages;
              if (messages == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (messages.isEmpty) {
                return Center(
                  child: Text(AppLocalizations.of(context).chatDetailEmpty),
                );
              }
              // Built oldest-first for the date-divider logic, then
              // reversed: with reverse: true the ListView anchors index 0
              // at the bottom, so index 0 must be the newest item. That
              // also means the list opens already showing the newest
              // message -- no post-frame scroll needed on first load.
              final items = _buildTimeline(
                context,
                messages,
              ).reversed.toList();

              if (_jumpToBottomOnNextBuild) {
                _jumpToBottomOnNextBuild = false;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(animated: false),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                itemCount: items.length,
                itemBuilder: (context, index) => items[index],
              );
            },
          ),
          if (_unseenNewMessages > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
              child: Center(
                child: Dismissible(
                  key: ValueKey('newMessageBanner_$_unseenNewMessages'),
                  direction: DismissDirection.horizontal,
                  onDismissed: (_) => setState(() => _unseenNewMessages = 0),
                  child: _NewMessageBanner(
                    count: _unseenNewMessages,
                    onTap: () => _scrollToBottom(),
                  ),
                ),
              ),
            )
          else if (_showScrollToBottom)
            Positioned(
              right: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
              child: FloatingActionButton.small(
                heroTag: 'scrollToBottom',
                onPressed: () => _scrollToBottom(),
                child: const Icon(Icons.keyboard_arrow_down),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildTimeline(BuildContext context, List<Message> messages) {
    final items = <Widget>[];
    DateTime? lastDay;
    for (final message in messages) {
      final day = DateTime.fromMillisecondsSinceEpoch(message.timestamp);
      final dayOnly = DateTime(day.year, day.month, day.day);
      if (lastDay == null || dayOnly != lastDay) {
        items.add(_DateDivider(date: dayOnly));
        lastDay = dayOnly;
      }
      items.add(MessageBubble(message: message));
    }
    return items;
  }
}

class _NewMessageBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NewMessageBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.primary,
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard_arrow_down,
                color: colorScheme.onPrimary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).newMessagesBanner(count),
                style: TextStyle(
                  color: colorScheme.onPrimary,
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

class _DateDivider extends StatelessWidget {
  final DateTime date;

  const _DateDivider({required this.date});

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
      padding: const EdgeInsets.symmetric(vertical: 8),
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
