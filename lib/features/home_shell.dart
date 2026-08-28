import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../l10n/generated/app_localizations.dart';
import 'chats/chats_list_screen.dart';
import 'settings/settings_screen.dart';
import 'statuses/statuses_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    ChatsListScreen(),
    StatusesScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().refreshData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titles = [
      l10n.navChats,
      l10n.navStatuses,
      l10n.navSettings,
    ];

    // The Statuses screen has its own header (app tabs + filter chips), so
    // a redundant "Statuses" app bar above it just eats vertical space.
    final showAppBar = _index != 1;

    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(titles[_index])) : null,
      body: SafeArea(
        top: !showAppBar,
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            label: l10n.navChats,
          ),
          NavigationDestination(
            icon: const Icon(Icons.donut_large_outlined),
            label: l10n.navStatuses,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
