import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../core/models/media_folder_item.dart';
import '../../core/models/media_type.dart';
import '../../core/native_bridge.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/app_tab_switcher.dart';
import '../../widgets/error_state.dart';
import '../statuses/image_viewer_screen.dart';
import '../statuses/video_player_screen.dart';
import '../statuses/video_thumbnail_tile.dart';
import 'media_recovery_guide_screen.dart';

/// Photo/Video/Files/Stickers & GIFs recovery: unlike [MediaRecoveryScreen]
/// (which surfaces media captured from notifications), this scans
/// WhatsApp's own Media folder on disk once folder access is granted --
/// catching files whose message was deleted but whose download WhatsApp
/// never cleaned up.
class MediaFolderScreen extends StatefulWidget {
  final String kind;
  final String title;

  const MediaFolderScreen({super.key, required this.kind, required this.title});

  @override
  State<MediaFolderScreen> createState() => _MediaFolderScreenState();
}

class _MediaFolderScreenState extends State<MediaFolderScreen> {
  // A full sync walks the entire granted SAF tree -- expensive, especially
  // on a large Media folder -- so it's only worth re-running automatically
  // once this much time has passed since the last one, rather than on
  // every single screen open or tab switch. Pull-to-refresh always forces
  // one regardless, so the user still has an explicit way to get fresh data
  // sooner.
  static const _autoSyncCooldown = Duration(minutes: 15);

  String _package = pkgWhatsApp;
  bool? _hasAccess;
  List<MediaFolderItem> _items = [];
  String _folderHint = '';
  bool _loading = false;
  bool _syncing = false;
  Object? _error;

  bool get _isGrid => widget.kind != 'files';

  String get _lastSyncPrefKey => 'media_last_synced_${widget.kind}_$_package';

  Future<bool> _shouldAutoSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMillis = prefs.getInt(_lastSyncPrefKey);
    if (lastMillis == null) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMillis);
    return DateTime.now().difference(last) > _autoSyncCooldown;
  }

  Future<void> _markSynced() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncPrefKey, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Fast path only: local cache + access/hint check, no SAF folder walk --
  /// this is what the screen's first paint waits on, so it stays quick even
  /// on a slow device or a huge WhatsApp Media folder. A real scan for new
  /// files is kicked off separately by [_sync].
  ///
  /// Any failure here (e.g. a stale build missing a newly added platform
  /// channel method) surfaces as an explicit error screen with a retry
  /// button -- previously an exception here just left `_loading` stuck
  /// `true` forever, since nothing downstream of the throw ever ran to
  /// clear it.
  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hasAccess = await NativeBridge.hasMediaFolderAccess(_package);
      List<MediaFolderItem> items = [];
      String hint = '';
      if (hasAccess) {
        items = await NativeBridge.listMediaFolder(widget.kind, _package);
      } else {
        hint = await NativeBridge.mediaFolderHint(_package);
      }
      if (!mounted) return;
      setState(() {
        _hasAccess = hasAccess;
        _items = items;
        _folderHint = hint;
        _loading = false;
      });
      if (hasAccess && await _shouldAutoSync()) _sync();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// The slow half: scans WhatsApp's granted Media folder for anything new
  /// and copies it in, then refreshes the (fast) local list. Runs behind a
  /// slim top progress bar instead of blocking the whole screen, so
  /// whatever was already recovered stays visible and interactive the
  /// entire time. A failure here surfaces the same error screen as
  /// [_refresh] rather than leaving that progress bar spinning forever.
  ///
  /// Called either because [_refresh] decided a fresh scan was actually due
  /// ([_shouldAutoSync]), or directly from pull-to-refresh, which always
  /// forces one regardless of the cooldown.
  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await NativeBridge.syncMediaFolder(widget.kind, _package);
      if (!mounted) return;
      final items = await NativeBridge.listMediaFolder(widget.kind, _package);
      if (!mounted) return;
      setState(() {
        _items = items;
        _syncing = false;
      });
      await _markSynced();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _syncing = false;
      });
    }
  }

  void _switchPackage(String package) {
    if (package == _package) return;
    setState(() {
      _package = package;
      _hasAccess = null;
      _items = [];
    });
    _refresh();
  }

  Future<bool> _requestAccess() async {
    final granted = await NativeBridge.requestMediaFolderAccess(_package);
    if (!mounted) return granted;
    if (granted) {
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).mediaFolderAccessDeniedMessage,
          ),
        ),
      );
    }
    return granted;
  }

  Future<void> _openGuide() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaRecoveryGuideScreen(
          package: _package,
          folderAccessGranted: _hasAccess ?? false,
          onRequestFolderAccess: _requestAccess,
        ),
      ),
    );
    _refresh();
  }

  void _openItem(MediaFolderItem item) {
    if (item.mediaType == MediaType.video) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VideoPlayerScreen(path: item.path)),
      );
    } else if (item.mediaType == MediaType.image ||
        item.mediaType == MediaType.sticker ||
        item.mediaType == MediaType.gif) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ImageViewerScreen(path: item.path)),
      );
    } else {
      _openFile(item);
    }
  }

  Future<void> _openFile(MediaFolderItem item) async {
    final ok = await NativeBridge.openFile(item.path);
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
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: l10n.mediaGuideTitle,
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _openGuide,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
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
          if (_syncing) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _error != null
                ? ErrorState(error: _error!, onRetry: _refresh)
                : _loading
                ? const Center(child: CircularProgressIndicator())
                : (_hasAccess ?? false)
                ? (_items.isEmpty
                      ? (_syncing
                            ? _ScanningNotice(
                                text: l10n.mediaFolderScanningState,
                              )
                            : _EmptyMediaFolder(onViewGuide: _openGuide))
                      : RefreshIndicator(
                          onRefresh: _sync,
                          child: _isGrid
                              ? _MediaFolderGrid(
                                  items: _items,
                                  onOpen: _openItem,
                                )
                              : _MediaFolderList(
                                  items: _items,
                                  onOpen: _openItem,
                                ),
                        ))
                : _FolderAccessRequest(
                    folderHint: _folderHint,
                    onGrant: _requestAccess,
                  ),
          ),
        ],
      ),
    );
  }
}

class _FolderAccessRequest extends StatelessWidget {
  final String folderHint;
  final Future<bool> Function() onGrant;

  const _FolderAccessRequest({required this.folderHint, required this.onGrant});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 42,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.mediaFolderAccessTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.mediaFolderAccessDescription,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (folderHint.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.statusFolderPathLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    folderHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onGrant,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(l10n.mediaFolderAccessAction),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown while a first-time sync is still running and hasn't found
/// anything yet -- distinct from [_EmptyMediaFolder] so a still-in-progress
/// scan doesn't get mistaken for a confirmed empty result.
class _ScanningNotice extends StatelessWidget {
  final String text;

  const _ScanningNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMediaFolder extends StatelessWidget {
  final VoidCallback onViewGuide;

  const _EmptyMediaFolder({required this.onViewGuide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.4,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_off_outlined,
                size: 42,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.mediaFolderEmptyTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onViewGuide,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(l10n.mediaFolderViewGuide),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaFolderGrid extends StatelessWidget {
  final List<MediaFolderItem> items;
  final void Function(MediaFolderItem) onOpen;

  const _MediaFolderGrid({required this.items, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      // A couple screens' worth stay warm so fast scrolling doesn't re-decode
      // images that were just off-screen a moment ago.
      // ignore: deprecated_member_use
      cacheExtent: 800,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final theme = Theme.of(context);
        // Grid tiles never render wider than ~200 logical px on a phone --
        // decoding the source photo at full camera resolution just to shrink
        // it back down on every scroll frame is what makes a grid feel
        // laggy on a low-end device, so ask the decoder for something close
        // to what's actually painted instead.
        final cacheWidth = (220 * MediaQuery.of(context).devicePixelRatio)
            .round();
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
                child: item.mediaType == MediaType.video
                    ? VideoThumbnailTile(path: item.path)
                    : Image.file(
                        File(item.path),
                        fit: BoxFit.cover,
                        cacheWidth: cacheWidth,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.broken_image_outlined,
                          color: theme.colorScheme.outline,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MediaFolderList extends StatelessWidget {
  final List<MediaFolderItem> items;
  final void Function(MediaFolderItem) onOpen;

  const _MediaFolderList({required this.items, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _FileRow(item: items[index], onOpen: onOpen),
    );
  }
}

class _FileRow extends StatelessWidget {
  final MediaFolderItem item;
  final void Function(MediaFolderItem) onOpen;

  const _FileRow({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateFormat(
      'MMM d, HH:mm',
    ).format(DateTime.fromMillisecondsSinceEpoch(item.lastModified));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onOpen(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.insert_drive_file_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
