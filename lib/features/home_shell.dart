import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../l10n/generated/app_localizations.dart';
import 'chats/chats_list_screen.dart';
import 'recover/direct_chat_screen.dart';
import 'recover/recover_screen.dart';
import 'settings/settings_screen.dart';
import 'statuses/statuses_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  static const _screens = [
    RecoverScreen(),
    ChatsListScreen(),
    StatusesScreen(),
    SettingsScreen(),
    DirectChatScreen(),
  ];

  // Shown (with retries -- see AdsService.showAppOpenAdWhenReady) once per
  // cold start, not on every resume -- this is the app's home screen, not a
  // splash gate, so there's no other single "app just launched" hook to
  // hang it on. Stays true until a pause/resume cycle confirms the ad's own
  // full-screen activity took over and came back, so we don't keep
  // retrying (and risk a second ad) once it's actually been shown.
  bool _awaitingAppOpenAd = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().refreshData();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_awaitingAppOpenAd &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.resumed)) {
      _awaitingAppOpenAd = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  void _selectTab(int index) {
    if (index != _index) {}
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final pendingTab = appState.pendingTabIndex;
    if (pendingTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appState.clearPendingTab();
        if (mounted && pendingTab != _index)
          setState(() => _index = pendingTab);
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
    ];

    // Recover has its own distinct gradient header, so a plain app bar above
    // it would be redundant. Every other tab, including Statuses, uses the
    // shared app bar (title + settings action) above its own content.
    final showAppBar = _index != 0;

    return Scaffold(
      backgroundColor: Color.lerp(theme.colorScheme.surface, Colors.white, 0.6),
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
              child: IndexedStack(index: _index, children: _screens),
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
            ],
          ),
        ],
      ),
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
