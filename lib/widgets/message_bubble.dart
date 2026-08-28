import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/models/media_type.dart';
import '../core/models/message.dart';
import '../core/native_bridge.dart';
import '../l10n/generated/app_localizations.dart';
import 'voice_message_player.dart';

final RegExp _urlRegex = RegExp(
  r'((https?:\/\/)|(www\.))[^\s]+',
  caseSensitive: false,
);

/// Strips trailing punctuation a URL regex tends to sweep up from
/// surrounding sentence text, e.g. "check example.com." or "(example.com)".
String _trimTrailingPunctuation(String url) {
  return url.replaceAll(RegExp(r'''[.,!?;:'")\]}]+$'''), '');
}

List<String> _extractUrls(String? text) {
  if (text == null) return const [];
  return _urlRegex
      .allMatches(text)
      .map((m) => _trimTrailingPunctuation(m.group(0)!))
      .toList();
}

Future<void> _openUrl(BuildContext context, String rawUrl) async {
  final normalized =
      rawUrl.startsWith(RegExp(r'https?://', caseSensitive: false))
      ? rawUrl
      : 'https://$rawUrl';
  final uri = Uri.tryParse(normalized);
  final ok =
      uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).linkOpenFailed)),
    );
  }
}

void _showLinkSheet(BuildContext context, List<String> urls) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (final url in urls) _LinkSheetRow(url: url)],
      ),
    ),
  );
}

class _LinkSheetRow extends StatelessWidget {
  final String url;

  const _LinkSheetRow({required this.url});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.link_rounded),
      title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        Navigator.of(context).pop();
        _openUrl(context, url);
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: l10n.copyAction,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.linkCopied)));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: l10n.shareAction,
            onPressed: () => SharePlus.instance.share(ShareParams(text: url)),
          ),
        ],
      ),
    );
  }
}

/// Renders text with any URLs highlighted and tappable (opens in the
/// device's browser), leaving everything else as plain text.
class _LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _LinkifiedText(this.text, {this.style});

  @override
  State<_LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<_LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final matches = _urlRegex.allMatches(widget.text).toList();
    if (matches.isEmpty) {
      return Text(widget.text, style: widget.style);
    }

    final theme = Theme.of(context);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in matches) {
      if (match.start > last) {
        spans.add(TextSpan(text: widget.text.substring(last, match.start)));
      }
      final rawUrl = match.group(0)!;
      final url = _trimTrailingPunctuation(rawUrl);
      final trailing = rawUrl.substring(url.length);
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _openUrl(context, url);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          recognizer: recognizer,
        ),
      );
      if (trailing.isNotEmpty) {
        spans.add(TextSpan(text: trailing));
      }
      last = match.end;
    }
    if (last < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(last)));
    }
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}

/// Approximates WhatsApp's incoming-message bubble: white/near-black bubble
/// with a sharp top-left corner, sender name in an accent color for group
/// chats, and the time tucked into the bottom-right of the bubble. Stickers
/// render "naked" (no bubble), matching WhatsApp's own look.
class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  /// WhatsApp prefixes media/document notification text with one of these
  /// emoji. When the message has no attached data -- a multi-item summary
  /// like "3 photos, 1 video", a generic file attachment, or a single item
  /// whose data just wasn't included -- there's nothing to recover, only
  /// this description of what it was. Returns the icon to show and the
  /// label with the emoji stripped, or null if it's not one of these.
  static (IconData, String)? _placeholderInfo(String text) {
    final trimmed = text.trimLeft();
    const emojiIcons = {
      '📷': Icons.photo_camera_outlined,
      '🎥': Icons.videocam_outlined,
      '👾': Icons.gif_box_outlined,
    };
    for (final entry in emojiIcons.entries) {
      if (trimmed.startsWith(entry.key)) {
        return (entry.value, trimmed.replaceFirst(entry.key, '').trim());
      }
    }
    if (trimmed.startsWith('📄')) {
      final label = trimmed.replaceFirst('📄', '').trim();
      return (_documentIcon(label), label);
    }
    return null;
  }

  Future<void> _openFile(BuildContext context) async {
    final ok = await NativeBridge.openFile(
      message.mediaPath!,
      mime: message.mediaMime,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).openFileFailed)),
      );
    }
  }

  void _explainNotRecoverable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).documentNotRecoverableExplanation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final time = DateFormat(
      'HH:mm',
    ).format(DateTime.fromMillisecondsSinceEpoch(message.timestamp));

    if (message.mediaType == MediaType.sticker && message.hasMedia) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 60, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.sender != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    message.sender!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              Image.file(
                File(message.mediaPath!),
                width: 130,
                height: 130,
                fit: BoxFit.contain,
                frameBuilder: (context, child, frame, synchronouslyLoaded) =>
                    _imageLoadTransition(
                      child,
                      frame,
                      synchronouslyLoaded,
                      width: 130,
                      height: 130,
                    ),
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined, size: 48),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: _TimeRow(time: time),
              ),
            ],
          ),
        ),
      );
    }

    final Color background = isDark ? const Color(0xFF1F2C34) : Colors.white;

    final placeholder = message.hasMedia || message.text == null
        ? null
        : _placeholderInfo(message.text!);

    final urls = _extractUrls(message.text);

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: urls.isEmpty ? null : () => _showLinkSheet(context, urls),
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 2, 60, 2),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
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
          // Without this, the bottom-right-aligned timestamp row (an Align
          // with no widthFactor) greedily fills all the width the Container
          // allows, forcing every bubble to max width regardless of how
          // short the message actually is. IntrinsicWidth makes the Column
          // -- and everything inside it, including that Align -- size to
          // its content's real width instead.
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.sender != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      message.sender!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                if (message.hasMedia)
                  _buildMedia(context)
                else if (placeholder != null)
                  _UnrecoverableFileRow(
                    icon: placeholder.$1,
                    label: placeholder.$2,
                    onTap: () => _explainNotRecoverable(context),
                  )
                else if (message.text != null && message.text!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
                    child: _LinkifiedText(
                      message.text!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _TimeRow(time: time),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedia(BuildContext context) {
    final path = message.mediaPath!;
    switch (message.mediaType) {
      case MediaType.image:
      case MediaType.gif:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                frameBuilder: (context, child, frame, synchronouslyLoaded) =>
                    _imageLoadTransition(
                      child,
                      frame,
                      synchronouslyLoaded,
                      width: double.infinity,
                      height: 200,
                    ),
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 120,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          ),
        );
      case MediaType.video:
        return GestureDetector(
          onTap: () => _openFile(context),
          child: Container(
            height: 140,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Icon(Icons.play_circle_outline, size: 40),
            ),
          ),
        );
      case MediaType.audio:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: VoiceMessagePlayer(path: path),
        );
      case MediaType.document:
        return _FileRow(
          icon: _documentIcon(path),
          label: message.text?.isNotEmpty == true
              ? message.text!
              : mediaTypeLabel(context, MediaType.document),
          onTap: () => _openFile(context),
        );
      case MediaType.sticker:
      case MediaType.none:
        return const SizedBox.shrink();
    }
  }
}

/// Shows a small spinner in place of the image until its first frame has
/// actually been decoded, then cross-fades into the real image. Image.file
/// has no network-style `loadingBuilder`, but `frameBuilder` fires the same
/// way for any image source and lets us cover that gap.
Widget _imageLoadTransition(
  Widget child,
  int? frame,
  bool wasSynchronouslyLoaded, {
  required double width,
  required double height,
}) {
  if (wasSynchronouslyLoaded) return child;
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    child: frame == null
        ? SizedBox(
            key: const ValueKey('loading'),
            width: width,
            height: height,
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        : KeyedSubtree(key: const ValueKey('loaded'), child: child),
  );
}

IconData _documentIcon(String nameOrPath) {
  final ext = nameOrPath.toLowerCase().split('.').last;
  switch (ext) {
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'apk':
      return Icons.android_rounded;
    case 'doc':
    case 'docx':
      return Icons.description_rounded;
    case 'xls':
    case 'xlsx':
      return Icons.table_chart_rounded;
    case 'zip':
    case 'rar':
      return Icons.folder_zip_rounded;
    case 'heic':
    case 'jpg':
    case 'jpeg':
    case 'png':
      return Icons.image_outlined;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

class _TimeRow extends StatelessWidget {
  final String time;

  const _TimeRow({required this.time});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      time,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// A tappable row used for audio and document attachments: icon, label, and
/// an affordance to open the file with the device's default viewer/player.
class _FileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FileRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A document WhatsApp only sent a filename for, with no attached data --
/// styled like a real attachment row but honest that there's nothing behind
/// it to open, rather than silently failing or hiding the filename.
class _UnrecoverableFileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _UnrecoverableFileRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    AppLocalizations.of(context).documentNotRecoverableTitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
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
