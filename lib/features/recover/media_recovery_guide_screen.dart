import 'package:flutter/material.dart';

import '../../core/native_bridge.dart';
import '../../l10n/generated/app_localizations.dart';

/// "How to use" guide for the folder-scan media recovery screens
/// (Photo/Video/Files/Stickers & GIFs): grant folder access once, and
/// enable WhatsApp's own media auto-download so there's something on disk
/// to recover in the first place.
class MediaRecoveryGuideScreen extends StatefulWidget {
  final String package;
  final bool folderAccessGranted;
  final Future<bool> Function() onRequestFolderAccess;

  const MediaRecoveryGuideScreen({
    super.key,
    required this.package,
    required this.folderAccessGranted,
    required this.onRequestFolderAccess,
  });

  @override
  State<MediaRecoveryGuideScreen> createState() =>
      _MediaRecoveryGuideScreenState();
}

class _MediaRecoveryGuideScreenState extends State<MediaRecoveryGuideScreen> {
  late bool _granted = widget.folderAccessGranted;
  bool _requesting = false;

  Future<void> _requestAccess() async {
    if (_requesting || _granted) return;
    setState(() => _requesting = true);
    try {
      final granted = await widget.onRequestFolderAccess();
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _granted = granted;
      });
    } catch (e) {
      // Otherwise a throw here leaves the request spinner in the row below
      // spinning forever instead of resetting to a retryable state.
      if (!mounted) return;
      setState(() => _requesting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openWhatsApp() async {
    final l10n = AppLocalizations.of(context);
    final ok = await NativeBridge.openApp(widget.package);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.mediaGuideOpenAppFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final green = Colors.green.shade600;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mediaGuideTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.mediaGuideFolderAccessTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _granted
                            ? l10n.mediaGuideFolderAccessGrantedBody
                            : l10n.mediaGuideFolderAccessBody,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _requesting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _granted
                    ? Icon(Icons.check_circle_rounded, color: green, size: 26)
                    : IconButton(
                        icon: const Icon(Icons.arrow_circle_right_rounded),
                        color: theme.colorScheme.primary,
                        iconSize: 28,
                        onPressed: _requestAccess,
                      ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.mediaGuideAutoDownloadTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.mediaGuideAutoDownloadBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openWhatsApp,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(l10n.mediaGuideOpenWhatsApp),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
