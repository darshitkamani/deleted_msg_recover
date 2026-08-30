import 'media_type.dart';

/// One recovered media item, aggregated across every chat -- unlike
/// [Message], which is scoped to a single chat, this carries enough chat
/// context (title, package) to be shown standalone in the Recover grid's
/// per-media-type screens.
class RecoveredMedia {
  final String chatKey;
  final String chatTitle;
  final String package;
  final String? sender;
  final String? text;
  final String mediaPath;
  final MediaType mediaType;
  final String? mediaMime;
  final int timestamp;
  final bool isDeleted;

  const RecoveredMedia({
    required this.chatKey,
    required this.chatTitle,
    required this.package,
    required this.sender,
    required this.text,
    required this.mediaPath,
    required this.mediaType,
    required this.mediaMime,
    required this.timestamp,
    required this.isDeleted,
  });

  factory RecoveredMedia.fromMap(Map<dynamic, dynamic> map) {
    return RecoveredMedia(
      chatKey: map['chatKey'] as String,
      chatTitle: map['chatTitle'] as String,
      package: map['package'] as String,
      sender: map['sender'] as String?,
      text: map['text'] as String?,
      mediaPath: map['mediaPath'] as String,
      mediaType: mediaTypeFromString(map['mediaType'] as String?),
      mediaMime: map['mediaMime'] as String?,
      timestamp: (map['timestamp'] as num).toInt(),
      isDeleted: map['status'] == 'deleted',
    );
  }
}
