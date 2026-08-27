import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../core/models/media_type.dart';
import '../../core/models/message.dart';
import '../../core/native_bridge.dart';
import '../../l10n/generated/app_localizations.dart';

class DeletedFeedScreen extends StatelessWidget {
  const DeletedFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final items = appState.deletedFeed;

    return RefreshIndicator(
      onRefresh: appState.refreshData,
      child: items.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                const Icon(Icons.mark_email_read_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      AppLocalizations.of(context).deletedFeedEmpty,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => _DeletedTile(item: items[index]),
            ),
    );
  }
}

class _DeletedTile extends StatelessWidget {
  final DeletedFeedItem item;

  const _DeletedTile({required this.item});

  static const _inlineViewableTypes = {MediaType.image, MediaType.gif, MediaType.sticker};

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('MMM d, HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(item.timestamp));

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        child: Icon(_leadingIcon(), color: Theme.of(context).colorScheme.error),
      ),
      title: Text(item.chatTitle),
      subtitle: Text(
        item.hasMedia
            ? (item.sender != null
                ? AppLocalizations.of(context)
                    .deletedFeedMediaWithSender(item.sender!, mediaTypeLabel(context, item.mediaType))
                : mediaTypeLabel(context, item.mediaType))
            : (item.text?.isNotEmpty == true
                ? item.text!
                : AppLocalizations.of(context).deletedFeedNoText),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(time, style: Theme.of(context).textTheme.labelSmall),
      onTap: item.hasMedia ? () => _handleTap(context) : null,
    );
  }

  IconData _leadingIcon() {
    if (!item.hasMedia) return Icons.delete_outline;
    switch (item.mediaType) {
      case MediaType.video:
        return Icons.videocam_outlined;
      case MediaType.audio:
        return Icons.mic_none_rounded;
      case MediaType.document:
        return Icons.insert_drive_file_outlined;
      case MediaType.sticker:
        return Icons.emoji_emotions_outlined;
      case MediaType.image:
      case MediaType.gif:
      case MediaType.none:
        return Icons.image_outlined;
    }
  }

  void _handleTap(BuildContext context) {
    if (_inlineViewableTypes.contains(item.mediaType)) {
      showDialog(
        context: context,
        builder: (_) => Dialog(child: Image.file(File(item.mediaPath!))),
      );
    } else {
      NativeBridge.openFile(item.mediaPath!, mime: item.mediaMime).then((ok) {
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).openFileFailed)),
          );
        }
      });
    }
  }
}
