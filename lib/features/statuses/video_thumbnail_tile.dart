import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

/// A single video's grid tile: a generated frame with a play badge on top.
/// Thumbnails are generated once per path and kept in memory for the life
/// of the app, since the same status list gets rebuilt often (tab
/// switches, pull-to-refresh) and re-decoding the same video is wasteful.
class VideoThumbnailTile extends StatefulWidget {
  final String path;

  const VideoThumbnailTile({super.key, required this.path});

  static final Map<String, Uint8List?> _cache = {};

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
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
            ),
          ),
        Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
          ),
        ),
      ],
    );
  }
}
