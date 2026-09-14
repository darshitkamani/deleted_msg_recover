import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/models/status_item.dart';
import '../../core/native_bridge.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/app_tab_switcher.dart';
import '../../widgets/error_state.dart';
import 'image_viewer_screen.dart';
import 'video_player_screen.dart';
import 'video_thumbnail_tile.dart';

enum _MediaFilter { all, images, videos }

/// Browses WhatsApp/WhatsApp Business statuses. Unlike message recovery,
/// this has nothing to do with notifications: WhatsApp keeps currently
/// active statuses in its own folder on-device for ~24h, and reading
/// another app's folder requires the user to grant it once via the system
/// folder picker (Storage Access Framework) -- there's no notification
/// stream to listen for here, so this screen manages its own state.
class StatusesScreen extends StatefulWidget {
  const StatusesScreen({super.key});

  @override
  State<StatusesScreen> createState() => _StatusesScreenState();
}

class _StatusesScreenState extends State<StatusesScreen> {
  String _package = pkgWhatsApp;
  bool? _hasAccess;
  List<StatusItem> _items = [];
  String _folderHint = '';
  bool _loading = false;
  Object? _error;
  _MediaFilter _filter = _MediaFilter.all;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hasAccess = await NativeBridge.hasStatusAccess(_package);
      List<StatusItem> items = [];
      String hint = '';
      if (hasAccess) {
        items = await NativeBridge.listStatuses(_package);
      } else {
        hint = await NativeBridge.statusFolderHint(_package);
      }
      if (!mounted) return;
      setState(() {
        _hasAccess = hasAccess;
        _items = items;
        _folderHint = hint;
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
    setState(() {
      _package = package;
      _filter = _MediaFilter.all;
      _hasAccess = null;
      _items = [];
    });
    _refresh();
  }

  Future<void> _requestAccess() async {
    final granted = await NativeBridge.requestStatusAccess(_package);
    if (!mounted) return;
    if (granted) {
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).statusAccessDeniedMessage),
        ),
      );
    }
  }

  void _openItem(StatusItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => item.isVideo
            ? VideoPlayerScreen(path: item.path)
            : ImageViewerScreen(path: item.path),
      ),
    );
  }

  int get _imageCount => _items.where((i) => !i.isVideo).length;
  int get _videoCount => _items.where((i) => i.isVideo).length;

  List<StatusItem> get _filteredItems {
    switch (_filter) {
      case _MediaFilter.all:
        return _items;
      case _MediaFilter.images:
        return _items.where((i) => !i.isVideo).toList();
      case _MediaFilter.videos:
        return _items.where((i) => i.isVideo).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showFilters = (_hasAccess ?? false) && _items.isNotEmpty;
    return Column(
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SizeTransition(
              sizeFactor: anim,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
          child: showFilters
              ? Padding(
                  key: const ValueKey('filters'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _FilterChipRow(
                    selected: _filter,
                    total: _items.length,
                    imageCount: _imageCount,
                    videoCount: _videoCount,
                    onChanged: (f) => setState(() => _filter = f),
                    labels: (
                      all: l10n.statusFilterAll,
                      images: l10n.statusFilterImages,
                      videos: l10n.statusFilterVideos,
                    ),
                  ),
                )
              : const SizedBox(
                  key: ValueKey('no-filters'),
                  width: double.infinity,
                ),
        ),
        Expanded(
          child: _error != null
              ? ErrorState(error: _error!, onRetry: _refresh)
              : _loading
              ? const Center(child: CircularProgressIndicator())
              : (_hasAccess ?? false)
              ? _StatusGrid(
                  items: _filteredItems,
                  onRefresh: _refresh,
                  onOpen: _openItem,
                )
              : _AccessRequest(
                  folderHint: _folderHint,
                  onGrant: _requestAccess,
                ),
        ),
      ],
    );
  }
}

/// Filter chips for All / Images / Videos, each carrying a live count so
/// the user knows what a tap will show before they tap it.
class _FilterChipRow extends StatelessWidget {
  final _MediaFilter selected;
  final int total;
  final int imageCount;
  final int videoCount;
  final ValueChanged<_MediaFilter> onChanged;
  final ({String all, String images, String videos}) labels;

  const _FilterChipRow({
    required this.selected,
    required this.total,
    required this.imageCount,
    required this.videoCount,
    required this.onChanged,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: labels.all,
          count: total,
          icon: Icons.apps_rounded,
          selected: selected == _MediaFilter.all,
          onTap: () => onChanged(_MediaFilter.all),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: labels.images,
          count: imageCount,
          icon: Icons.image_rounded,
          selected: selected == _MediaFilter.images,
          onTap: () => onChanged(_MediaFilter.images),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: labels.videos,
          count: videoCount,
          icon: Icons.videocam_rounded,
          selected: selected == _MediaFilter.videos,
          onTap: () => onChanged(_MediaFilter.videos),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? Icons.check_rounded : icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Text(
                  '($count)',
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessRequest extends StatelessWidget {
  final String folderHint;
  final VoidCallback onGrant;

  const _AccessRequest({required this.folderHint, required this.onGrant});

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
            l10n.statusAccessTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.statusAccessDescription,
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
              child: Text(l10n.statusAccessAction),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusGrid extends StatelessWidget {
  final List<StatusItem> items;
  final Future<void> Function() onRefresh;
  final void Function(StatusItem) onOpen;

  const _StatusGrid({
    required this.items,
    required this.onRefresh,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            const SizedBox(height: 100),
            Icon(
              Icons.image_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  AppLocalizations.of(context).statusesEmptyState,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        // Keep a couple of screens' worth of tiles warm so fast scrolling
        // doesn't re-decode images that were just off-screen a moment ago.
        // ignore: deprecated_member_use
        cacheExtent: 800,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => RepaintBoundary(
          child: _StatusTile(item: items[index], onOpen: onOpen),
        ),
      ),
    );
  }
}

class _StatusTile extends StatefulWidget {
  final StatusItem item;
  final void Function(StatusItem) onOpen;

  const _StatusTile({required this.item, required this.onOpen});

  @override
  State<_StatusTile> createState() => _StatusTileState();
}

class _StatusTileState extends State<_StatusTile> {
  bool _downloading = false;

  void _download() {
    if (_downloading) return;
    setState(() => _downloading = true);
    _runDownload();
  }

  Future<void> _runDownload() async {
    // A throw here would otherwise leave this tile's download spinner
    // stuck forever instead of resetting to a retryable state.
    bool ok = false;
    try {
      ok = await NativeBridge.downloadMedia(
        widget.item.path,
        isVideo: widget.item.isVideo,
      );
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _downloading = false);
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.statusDownloadSuccess : l10n.statusDownloadFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    // Grid tiles never render wider than ~200 logical px on a phone, so
    // decoding the source photo at full camera resolution (often 3000px+)
    // just to shrink it back down on every scroll frame is what makes the
    // grid feel laggy. Ask the decoder for a size close to what's actually
    // painted -- Flutter picks the nearest smaller JPEG/PNG scale, which
    // is dramatically cheaper to decode and keep resident.
    final cacheWidth = (220 * MediaQuery.of(context).devicePixelRatio).round();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          child: InkWell(
            onTap: () => widget.onOpen(item),
            child: Stack(
              fit: StackFit.expand,
              children: [
                item.isVideo
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
                Positioned(
                  right: 8,
                  top: 8,
                  child: _TileActionPill(
                    downloading: _downloading,
                    onDownload: _download,
                    onShare: () => SharePlus.instance.share(
                      ShareParams(files: [XFile(item.path)]),
                    ),
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

/// Download + share, grouped into one small glass pill in the tile's
/// corner instead of two separate circles sitting on a full-width scrim --
/// that used to cover a third of every photo just to host two buttons.
class _TileActionPill extends StatelessWidget {
  final bool downloading;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  const _TileActionPill({
    required this.downloading,
    required this.onDownload,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          type: MaterialType.transparency,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PillIcon(
                tooltip: l10n.statusDownloadTooltip,
                onPressed: downloading ? null : onDownload,
                child: downloading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
              ),
              Container(
                width: 1,
                height: 16,
                color: Colors.white.withValues(alpha: 0.22),
              ),
              _PillIcon(
                tooltip: l10n.statusShareTooltip,
                onPressed: onShare,
                child: const Icon(
                  Icons.share_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillIcon extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  const _PillIcon({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(width: 17, height: 17, child: Center(child: child)),
        ),
      ),
    );
  }
}
