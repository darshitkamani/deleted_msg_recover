import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../core/ads/ads_service.dart';
import '../../core/native_bridge.dart';
import '../../l10n/generated/app_localizations.dart';

/// Full-screen in-app playback for a recovered status video, so viewing one
/// no longer has to hand off to whatever external player the device has.
class VideoPlayerScreen extends StatefulWidget {
  final String path;

  const VideoPlayerScreen({super.key, required this.path});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final VideoPlayerController _videoController;
  ChewieController? _chewieController;
  Object? _error;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(File(widget.path))
      ..initialize()
          .then((_) {
            if (!mounted) return;
            setState(() {
              _chewieController = ChewieController(
                videoPlayerController: _videoController,
                autoPlay: true,
                looping: false,
              );
            });
          })
          .catchError((Object e) {
            if (!mounted) return;
            setState(() => _error = e);
          });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  void _download() {
    if (_downloading) return;
    setState(() => _downloading = true);
    AdsService.instance.showRewardedInterThen(_runDownload);
  }

  Future<void> _runDownload() async {
    // A throw here (rather than downloadMedia's normal false-on-failure)
    // would otherwise leave this button's spinner stuck forever.
    bool ok = false;
    try {
      ok = await NativeBridge.downloadMedia(widget.path, isVideo: true);
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

  void _share() {
    AdsService.instance.showRewardedInterThen(
      () => SharePlus.instance.share(ShareParams(files: [XFile(widget.path)])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: _error != null
              ? const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                )
              : _chewieController != null
              // Chewie fills whatever box it's given rather than sizing
              // itself to the video, so without this explicit
              // AspectRatio it stretched to the full body height --
              // pushing the frame (and its controls) down and off the
              // bottom of the screen instead of centering it.
              ? AspectRatio(
                  aspectRatio: _videoController.value.aspectRatio,
                  child: Chewie(controller: _chewieController!),
                )
              : const CircularProgressIndicator(color: Colors.white),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _ViewerActionButton(
                  icon: Icons.download_rounded,
                  label: l10n.statusDownloadTooltip,
                  loading: _downloading,
                  onPressed: _download,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ViewerActionButton(
                  icon: Icons.share_rounded,
                  label: l10n.statusShareTooltip,
                  onPressed: _share,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewerActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool loading;

  const _ViewerActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: loading ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
