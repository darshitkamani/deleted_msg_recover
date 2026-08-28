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

  const Message({
    required this.id,
    required this.sender,
    required this.text,
    required this.mediaPath,
    required this.mediaType,
    required this.mediaMime,
    required this.timestamp,
    required this.removedAt,
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
    );
  }
}
