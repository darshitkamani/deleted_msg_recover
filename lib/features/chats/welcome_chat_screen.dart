import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:preload_google_ads/preload_google_ads.dart' hide AppState;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../l10n/generated/app_localizations.dart';

/// A pinned, app-authored "chat" at the top of the Chats tab that explains
/// what the app does -- styled like a real WhatsApp conversation (bubbles,
/// date divider) rather than a plain help screen, so it fits naturally
/// alongside the recovered conversations below it.
class WelcomeChatScreen extends StatelessWidget {
  const WelcomeChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.welcomeChatTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      backgroundColor: isDark
          ? const Color(0xFF0B141A)
          : const Color(0xFFECE5DD),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              children: [
                _DateLabel(text: DateFormat.yMMMd().format(DateTime.now())),
                _GreetingBubble(text: l10n.welcomeChatGreeting),
                _ChecklistBubble(
                  intro: l10n.welcomeChatIntro,
                  features: [
                    l10n.welcomeChatFeatureRestore,
                    l10n.welcomeChatFeatureUnseen,
                  ],
                  linkLabel: l10n.welcomeChatSeeHowToUse,
                  onTapLink: () {
                    // Jump straight to Settings -- that's where notification
                    // access, battery exclusion, and background reliability
                    // actually get turned on, so "how to use" leads directly to
                    // the actionable screen rather than a separate read-only one.
                    context.read<AppState>().goToTab(homeShellSettingsTabIndex);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: PreloadGoogleAds.instance.showNativeAd(),
          ),
        ],
      ),
    );
  }
}

class _DateLabel extends StatelessWidget {
  final String text;

  const _DateLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
            text,
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

class _GreetingBubble extends StatelessWidget {
  final String text;

  const _GreetingBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2C34) : Colors.white;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(8),
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(text, style: theme.textTheme.bodyMedium),
      ),
    );
  }
}

class _ChecklistBubble extends StatelessWidget {
  final String intro;
  final List<String> features;
  final String linkLabel;
  final VoidCallback onTapLink;

  const _ChecklistBubble({
    required this.intro,
    required this.features,
    required this.linkLabel,
    required this.onTapLink,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1F2C34) : Colors.white;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(8),
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(intro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              for (final feature in features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('✅', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(feature, style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              InkWell(
                onTap: onTapLink,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('👉', style: TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(
                          linkLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
