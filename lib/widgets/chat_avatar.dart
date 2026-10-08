import 'dart:io';

import 'package:flutter/material.dart';

/// Displays a chat's contact/group photo when available, falling back to
/// a themed letter avatar (first character of the title). Designed for both
/// the chat list tiles and the detail app bar.
class ChatAvatar extends StatelessWidget {
  final String? avatarPath;
  final String title;
  final bool isGroup;
  final double radius;

  const ChatAvatar({
    super.key,
    required this.avatarPath,
    required this.title,
    this.isGroup = false,
    this.radius = 23,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAvatar = avatarPath != null && avatarPath!.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      // Use the photo file as the background if it exists on disk.
      backgroundImage: hasAvatar ? FileImage(File(avatarPath!)) : null,
      // onBackgroundImageError keeps the widget from crashing when the
      // file has been pruned or is corrupt — it just falls through to
      // the child (letter/icon).
      onBackgroundImageError: hasAvatar
          ? (e, st) {} // swallow; the child below is the fallback
          : null,
      child: hasAvatar
          ? null
          : _LetterFallback(
              title: title,
              isGroup: isGroup,
              radius: radius,
            ),
    );
  }
}

class _LetterFallback extends StatelessWidget {
  final String title;
  final bool isGroup;
  final double radius;

  const _LetterFallback({
    required this.title,
    required this.isGroup,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // For groups, show a group icon; for individuals, show the first letter.
    if (isGroup) {
      return Icon(
        Icons.group_rounded,
        size: radius * 0.85,
        color: theme.colorScheme.onPrimaryContainer,
      );
    }

    final letter = title.isNotEmpty
        ? title.characters.first.toUpperCase()
        : '?';

    return Text(
      letter,
      style: TextStyle(
        fontSize: radius * 0.78,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}
