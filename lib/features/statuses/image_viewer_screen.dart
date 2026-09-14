import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/native_bridge.dart';
import '../../l10n/generated/app_localizations.dart';

/// Full-screen in-app viewer for a recovered status image, with pinch-to-zoom
/// and its own download/share bar -- previously a plain [Dialog] with no way
/// to act on the photo other than closing it.
class ImageViewerScreen extends StatefulWidget {
  final String path;

  const ImageViewerScreen({super.key, required this.path});

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _downloading = false;

  void _download() {
    if (_downloading) return;
    setState(() => _downloading = true);
    _runDownload();
  }

  Future<void> _runDownload() async {
    // A throw here (rather than downloadMedia's normal false-on-failure)
    // would otherwise leave this button's spinner stuck forever.
    bool ok = false;
    try {
      ok = await NativeBridge.downloadMedia(widget.path, isVideo: false);
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
    SharePlus.instance.share(ShareParams(files: [XFile(widget.path)]));
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
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.file(
            File(widget.path),
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
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
