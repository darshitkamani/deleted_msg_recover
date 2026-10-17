import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

/// A single video's grid tile: a generated frame with a play badge on top.
/// Thumbnails are generated once per path and kept in memory for the life
/// of the app, since the same status list gets rebuilt often (tab
/// switches, reloads) and re-decoding the same video is wasteful.
class VideoThumbnailTile extends StatefulWidget {
  final String path;

  const VideoThumbnailTile({super.key, required this.path});

  static final Map<String, Uint8List?> _cache = {};

  /// At most this many thumbnails decode at once; the rest wait their turn.
  /// Every tile in the grid starting a decode at the same moment opens as
  /// many native video decoders together, which on some phones (seen on
  /// Oppo) stalls the system's media service -- enough that releasing a
  /// decoder then takes over Android's 10 s finalizer limit and crashes the
  /// app (MediaMetadataRetriever.finalize() timed out).
  static const _maxConcurrentDecodes = 2;
  static int _activeDecodes = 0;
  static final Queue<Completer<void>> _waiting = Queue();

  static Future<void> _acquireDecodeSlot() {
    if (_activeDecodes < _maxConcurrentDecodes) {
      _activeDecodes++;
      return Future.value();
    }
    final turn = Completer<void>();
    _waiting.add(turn);
    return turn.future;
  }

  /// Hands the slot straight to the next waiting tile, if any.
  static void _releaseDecodeSlot() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _activeDecodes--;
    }
  }

  @override
  State<VideoThumbnailTile> createState() => _VideoThumbnailTileState();
}

class _VideoThumbnailTileState extends State<VideoThumbnailTile> {
  Uint8List? _bytes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (VideoThumbnailTile._cache.containsKey(widget.path)) {
      setState(() {
        _bytes = VideoThumbnailTile._cache[widget.path];
        _loaded = true;
      });
      return;
    }
    Uint8List? bytes;
    await VideoThumbnailTile._acquireDecodeSlot();
    try {
      // Scrolled away (or decoded by another tile for the same video) while
      // waiting for a slot: nothing left to do.
      if (!mounted) return;
      if (VideoThumbnailTile._cache.containsKey(widget.path)) {
        setState(() {
          _bytes = VideoThumbnailTile._cache[widget.path];
          _loaded = true;
        });
        return;
      }
      try {
        bytes = await vt.VideoThumbnail.thumbnailData(
          video: widget.path,
          imageFormat: vt.ImageFormat.JPEG,
          maxWidth: 240,
          quality: 60,
        );
      } catch (_) {
        bytes = null;
      }
    } finally {
      VideoThumbnailTile._releaseDecodeSlot();
    }
    VideoThumbnailTile._cache[widget.path] = bytes;
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black26),
        if (_bytes != null)
          Image.memory(_bytes!, fit: BoxFit.cover)
        else if (!_loaded)
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          ),
        Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ],
    );
  }
}
