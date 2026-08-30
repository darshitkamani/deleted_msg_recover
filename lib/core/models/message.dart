import 'media_type.dart';

enum MessageStatus { active, deleted }

MessageStatus _statusFromString(String? raw) =>
    raw == 'deleted' ? MessageStatus.deleted : MessageStatus.active;

/// One previous version of a message's text, from before it was edited.
class MessageEdit {
  final String? text;
  final int changedAt;

  const MessageEdit({required this.text, required this.changedAt});

  factory MessageEdit.fromMap(Map<dynamic, dynamic> map) {
    return MessageEdit(
      text: map['text'] as String?,
      changedAt: (map['changedAt'] as num).toInt(),
    );
  }
}

class Message {
  final int id;
  final String? sender;
  final String? text;
  final String? mediaPath;
  final MediaType mediaType;
  final String? mediaMime;
  final int timestamp;
  final int? removedAt;
  final MessageStatus status;
  final int? editedAt;
  final int? deletedAt;
  final List<MessageEdit> editHistory;

  const Message({
    required this.id,
    required this.sender,
    required this.text,
    required this.mediaPath,
    required this.mediaType,
    required this.mediaMime,
    required this.timestamp,
    required this.removedAt,
    this.status = MessageStatus.active,
    this.editedAt,
    this.deletedAt,
    this.editHistory = const [],
  });

  bool get hasMedia => mediaPath != null && mediaPath!.isNotEmpty;
  bool get isDeleted => status == MessageStatus.deleted;
  bool get isEdited => editHistory.isNotEmpty;

  /// The earliest text this app ever captured for this message. If it was
  /// later edited, this is what it originally said -- showing that, rather
  /// than the current text WhatsApp itself would show, is the whole point
  /// of flagging a message as edited.
  String? get originalText => isEdited ? editHistory.first.text : text;

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
      status: _statusFromString(map['status'] as String?),
      editedAt: (map['editedAt'] as num?)?.toInt(),
      deletedAt: (map['deletedAt'] as num?)?.toInt(),
      editHistory: ((map['editHistory'] as List?) ?? const [])
          .map((e) => MessageEdit.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
    );
  }
}
