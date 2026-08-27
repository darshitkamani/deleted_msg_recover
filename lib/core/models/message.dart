import 'media_type.dart';

class Message {
  final int id;
  final String? sender;
  final String? text;
  final String? mediaPath;
  final MediaType mediaType;
  final String? mediaMime;
  final int timestamp;
  final int? removedAt;
  final bool isDeleted;
  final bool isEdited;
  final String? editedText;

  const Message({
    required this.id,
    required this.sender,
    required this.text,
    required this.mediaPath,
    required this.mediaType,
    required this.mediaMime,
    required this.timestamp,
    required this.removedAt,
    required this.isDeleted,
    required this.isEdited,
    required this.editedText,
  });

  bool get hasMedia => mediaPath != null && mediaPath!.isNotEmpty;

  factory Message.fromMap(Map<dynamic, dynamic> map) {
    return Message(
      id: (map['id'] as num).toInt(),
      sender: map['sender'] as String?,
      text: map['text'] as String?,
      mediaPath: map['mediaPath'] as String?,
      mediaType: mediaTypeFromString(map['mediaType'] as String?),
      mediaMime: map['mediaMime'] as String?,
      timestamp: (map['timestamp'] as num).toInt(),
      removedAt: (map['removedAt'] as num?)?.toInt(),
      isDeleted: map['isDeleted'] as bool? ?? false,
      isEdited: map['isEdited'] as bool? ?? false,
      editedText: map['editedText'] as String?,
    );
  }
}

class DeletedFeedItem {
  final int id;
  final String chatKey;
  final String chatTitle;
  final String package;
  final String? sender;
  final String? text;
  final String? mediaPath;
  final MediaType mediaType;
  final String? mediaMime;
  final int timestamp;
  final int? removedAt;

  const DeletedFeedItem({
    required this.id,
    required this.chatKey,
    required this.chatTitle,
    required this.package,
    required this.sender,
    required this.text,
    required this.mediaPath,
    required this.mediaType,
    required this.mediaMime,
    required this.timestamp,
    required this.removedAt,
  });

  bool get hasMedia => mediaPath != null && mediaPath!.isNotEmpty;

  factory DeletedFeedItem.fromMap(Map<dynamic, dynamic> map) {
    return DeletedFeedItem(
      id: (map['id'] as num).toInt(),
      chatKey: map['chatKey'] as String,
      chatTitle: map['chatTitle'] as String,
      package: map['package'] as String,
      sender: map['sender'] as String?,
      text: map['text'] as String?,
      mediaPath: map['mediaPath'] as String?,
      mediaType: mediaTypeFromString(map['mediaType'] as String?),
      mediaMime: map['mediaMime'] as String?,
      timestamp: (map['timestamp'] as num).toInt(),
      removedAt: (map['removedAt'] as num?)?.toInt(),
    );
  }
}
