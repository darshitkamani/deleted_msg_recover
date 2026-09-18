import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/models/media_type.dart';
import '../../core/models/recovered_media.dart';
import '../../core/native_bridge.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/app_tab_switcher.dart';
import '../../widgets/error_state.dart';
import '../../widgets/voice_message_player.dart';
import '../statuses/image_viewer_screen.dart';
import '../statuses/video_player_screen.dart';
import '../statuses/video_thumbnail_tile.dart';

/// Shows every recovered message carrying media of [mediaTypes], aggregated
/// across every chat -- backs the Recover grid's Photo/Video/Voice
/// Message/Files/Stickers & GIFs tiles. Unlike the per-chat message view,
/// this is a new query scoped only by media type (and WA/WA Business), not
/// by conversation.
class MediaRecoveryScreen extends StatefulWidget {
  final String title;
  final List<MediaType> mediaTypes;

  const MediaRecoveryScreen({
    super.key,
    required this.title,
    required this.mediaTypes,
  });

  @override
  State<MediaRecoveryScreen> createState() => _MediaRecoveryScreenState();
}

class _MediaRecoveryScreenState extends State<MediaRecoveryScreen> {
  String _package = pkgWhatsApp;
  bool _loading = true;
  Object? _error;
  List<RecoveredMedia> _items = [];

  static const _typeStrings = {
    MediaType.image: 'image',
    MediaType.video: 'video',
    MediaType.audio: 'audio',
    MediaType.document: 'document',
    MediaType.sticker: 'sticker',
    MediaType.gif: 'gif',
  };

  bool get _isGrid => widget.mediaTypes.every(
    (t) =>
        t == MediaType.image ||
        t == MediaType.video ||
        t == MediaType.sticker ||
        t == MediaType.gif,
  );

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
      final items = await NativeBridge.getMediaMessages(
        widget.mediaTypes.map((t) => _typeStrings[t]!).toList(),
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

  void _openItem(RecoveredMedia item) {
    if (item.mediaType == MediaType.video) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(path: item.mediaPath),
        ),
      );
    } else if (item.mediaType == MediaType.image ||
        item.mediaType == MediaType.sticker ||
        item.mediaType == MediaType.gif) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImageViewerScreen(path: item.mediaPath),
        ),
      );
    } else if (item.mediaType == MediaType.document) {
      _openFile(item);
    }
  }

  Future<void> _openFile(RecoveredMedia item) async {
    final ok = await NativeBridge.openFile(
      item.mediaPath,
      mime: item.mediaMime,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).openFileFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
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
                : _items.isEmpty
                ? _EmptyState(text: l10n.recoverMediaEmptyState)
                : _isGrid
                ? _MediaGrid(items: _items, onOpen: _openItem)
                : _MediaList(items: _items, onOpen: _openItem),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  final List<RecoveredMedia> items;
  final void Function(RecoveredMedia) onOpen;

  const _MediaGrid({required this.items, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Material(
              color: theme.colorScheme.surfaceContainerHighest,
              child: InkWell(
                onTap: () => onOpen(item),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    item.mediaType == MediaType.video
                        ? VideoThumbnailTile(path: item.mediaPath)
                        : Image.file(
                            File(item.mediaPath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.broken_image_outlined,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                        child: Text(
                          item.chatTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
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

class _MediaList extends StatelessWidget {
  final List<RecoveredMedia> items;
  final void Function(RecoveredMedia) onOpen;

  const _MediaList({required this.items, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _MediaRow(item: items[index], onOpen: onOpen),
    );
  }
}

class _MediaRow extends StatelessWidget {
  final RecoveredMedia item;
  final void Function(RecoveredMedia) onOpen;

  const _MediaRow({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateFormat(
      'MMM d, HH:mm',
    ).format(DateTime.fromMillisecondsSinceEpoch(item.timestamp));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
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
            const SizedBox(height: 8),
            if (item.mediaType == MediaType.audio)
              VoiceMessagePlayer(path: item.mediaPath)
            else
              InkWell(
                onTap: () => onOpen(item),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.insert_drive_file_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.text?.isNotEmpty == true
                            ? item.text!
                            : mediaTypeLabel(context, item.mediaType),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
