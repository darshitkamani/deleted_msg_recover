import 'package:flutter/material.dart';
import 'package:preload_google_ads/preload_google_ads.dart' hide AppState;
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../l10n/generated/app_localizations.dart';
import 'chats/chats_list_screen.dart';
import 'deleted_feed/deleted_feed_screen.dart';
import 'recover/direct_chat_screen.dart';
import 'recover/recover_screen.dart';
import 'settings/settings_screen.dart';
import 'statuses/statuses_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Which tabs have actually been selected at least once -- an unvisited
  // tab's slot renders as an empty placeholder instead of its real screen.
  // IndexedStack itself keeps every one of its children mounted regardless
  // of which index is selected (it only stops *painting* the others), so
  // building all five screens up front -- each with its own ad slot --
  // used to fire every screen's ad load (and, since native ads render via
  // a real platform view that IndexedStack's "not painted" doesn't hide,
  // even ad *impressions*) the instant HomeShell appeared, regardless of
  // which tab the user actually looked at. Building a screen lazily, only
  // once its tab is first selected, keeps that ad request (and Widget/State
  // cost) from happening at all until the screen is actually shown, while
  // still keeping it -- and its state, scroll position, loaded ad -- alive
  // for the rest of the session once it has been.
  final Set<int> _visitedTabs = {0};

  static const _screenBuilders = <Widget Function()>[
    RecoverScreen.new,
    ChatsListScreen.new,
    StatusesScreen.new,
    SettingsScreen.new,
    DirectChatScreen.new,
    DeletedFeedScreen.new,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().refreshData();
    });
  }

  void _selectTab(int index) {
    // Bottom-tab switches are an IndexedStack swap, not a Navigator push,
    // so _InterstitialAdNavigatorObserver (app.dart) never sees them -- a
    // user could flip between tabs indefinitely without ever nudging the
    // interstitial counter. Feeding the same counter here closes that gap,
    // only counting an actual tab change (not re-tapping the active tab).
    if (index != _index) {
      PreloadGoogleAds.instance.showInterstitialAd(callBack: (ad, error) {});
    }
    setState(() {
      _index = index;
      _visitedTabs.add(index);
    });
  }

  /// Shown in place of the previous "back on the home screen just kills the
  /// app" behavior -- one last native-ad impression plus a confirmation, so
  /// a swipe/back that wasn't actually meant to exit doesn't lose the user's
  /// place for nothing.
  Future<void> _confirmExit(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (_) => _ExitAppDialog(),
    );
    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final pendingTab = appState.pendingTabIndex;
    if (pendingTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appState.clearPendingTab();
        if (mounted && pendingTab != _index) {
          setState(() {
            _index = pendingTab;
            _visitedTabs.add(pendingTab);
          });
        }
      });
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final titles = [
      l10n.navRecover,
      l10n.navChats,
      l10n.navStatuses,
      l10n.navSettings,
      l10n.directChatTitle,
      l10n.deletedMessagesTitle,
    ];

    // Recover has its own distinct gradient header, so a plain app bar above
    // it would be redundant. Every other tab, including Statuses, uses the
    // shared app bar (title + settings action) above its own content.
    final showAppBar = _index != 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit(context);
      },
      child: Scaffold(
        backgroundColor: Color.lerp(
          theme.colorScheme.surface,
          Colors.white,
          0.6,
        ),
        appBar: showAppBar
            ? AppBar(
                title: Text(titles[_index]),
                actions: _index == homeShellSettingsTabIndex
                    ? null
                    : [
                        IconButton(
                          tooltip: l10n.navSettings,
                          icon: const Icon(Icons.settings_rounded),
                          onPressed: () =>
                              appState.goToTab(homeShellSettingsTabIndex),
                        ),
                      ],
              )
            : null,
        body: SafeArea(
          top: !showAppBar,
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    for (var i = 0; i < _screenBuilders.length; i++)
                      _visitedTabs.contains(i)
                          ? _screenBuilders[i]()
                          : const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Settings has no button here: every tab already has its own settings
        // icon (in its header or the shared app bar above), so a 5th nav slot
        // just for it would be a redundant second way to get there. It's
        // still reachable -- appState.goToTab still lands on it correctly --
        // just not from this bar.
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BottomNavBar(
              index: _index,
              backgroundColor: Color.lerp(
                theme.colorScheme.surface,
                Colors.white,
                0.6,
              )!,
              onSelect: _selectTab,
              items: [
                _NavItem(
                  targetIndex: 0,
                  icon: Icons.restore_rounded,
                  label: l10n.navRecover,
                ),
                _NavItem(
                  targetIndex: 1,
                  icon: Icons.chat_bubble_rounded,
                  label: l10n.navChats,
                ),
                _NavItem(
                  targetIndex: 2,
                  icon: Icons.donut_large_rounded,
                  label: l10n.navStatuses,
                ),
                _NavItem(
                  targetIndex: 4,
                  icon: Icons.send_rounded,
                  label: l10n.navDirectChat,
                ),
                _NavItem(
                  targetIndex: 5,
                  icon: Icons.delete_sweep_rounded,
                  label: l10n.navDeleted,
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: PreloadGoogleAds.instance.showAdCounter(),
      ),
    );
  }
}

/// Exit-confirmation dialog shown instead of letting back/swipe on the home
/// screen kill the app outright -- a native ad plus an explicit choice
/// between backing out of the dialog and actually closing.
class _ExitAppDialog extends StatelessWidget {
  const _ExitAppDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.waving_hand_rounded,
              color: scheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.exitAppTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.exitAppBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.exitAppSponsoredLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(minHeight: 100),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: PreloadGoogleAds.instance.showNativeAd(),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.exitAppBackButton),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          child: Text(l10n.exitAppCloseButton),
        ),
      ],
    );
  }
}

class _NavItem {
  final int targetIndex;
  final IconData icon;
  final String label;

  const _NavItem({
    required this.targetIndex,
    required this.icon,
    required this.label,
  });
}

/// A floating, rounded bottom nav -- the active tab is just its icon+label
/// switching to the accent color, with no background shape behind it.
class _BottomNavBar extends StatelessWidget {
  final int index;
  final Color backgroundColor;
  final ValueChanged<int> onSelect;
  final List<_NavItem> items;

  const _BottomNavBar({
    required this.index,
    required this.backgroundColor,
    required this.onSelect,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      // Matches the page's own background -- the floating card is the only
      // thing that should stand out, not a mismatched strip around it.
      color: backgroundColor,
      padding: EdgeInsets.fromLTRB(
        14,
        0,
        14,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: _BottomNavButton(
                  item: item,
                  selected: item.targetIndex == index,
                  onTap: () => onSelect(item.targetIndex),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
