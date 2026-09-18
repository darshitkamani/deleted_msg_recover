import 'media_type.dart';
import 'message.dart';

/// One edited or deleted message, aggregated across every chat -- unlike
/// [Message], which is scoped to a single chat, this carries enough chat
/// context (title, package) to be shown standalone in the Deleted tab's
/// user-wise view. A row can be both edited and later deleted; [isDeleted]
/// and [isEdited] aren't mutually exclusive.
class EditedDeletedMessage {
  final int id;
  final String chatKey;
  final String chatTitle;
  final String package;
  final String? sender;
  final String? text;
  final int timestamp;
  final MessageStatus status;
  final int? editedAt;
  final int? deletedAt;
  final List<MessageEdit> editHistory;
  final String? mediaPath;
  final MediaType mediaType;
  final String? mediaMime;

  const EditedDeletedMessage({
    required this.id,
    required this.chatKey,
    required this.chatTitle,
    required this.package,
    required this.sender,
    required this.text,
    required this.timestamp,
    required this.status,
    required this.editedAt,
    required this.deletedAt,
    required this.editHistory,
    required this.mediaPath,
    required this.mediaType,
    required this.mediaMime,
  });

  bool get isDeleted => status == MessageStatus.deleted;
  bool get isEdited => editHistory.isNotEmpty;
  bool get hasMedia => mediaPath != null && mediaPath!.isNotEmpty;

  /// The earliest text this app ever captured for this message -- same
  /// rationale as [Message.originalText].
  String? get originalText => isEdited ? editHistory.first.text : text;

  factory EditedDeletedMessage.fromMap(Map<dynamic, dynamic> map) {
    return EditedDeletedMessage(
      id: (map['id'] as num).toInt(),
      chatKey: map['chatKey'] as String,
      chatTitle: map['chatTitle'] as String,
      package: map['package'] as String,
      sender: map['sender'] as String?,
      text: map['text'] as String?,
      timestamp: (map['timestamp'] as num).toInt(),
      status: map['status'] == 'deleted'
          ? MessageStatus.deleted
          : MessageStatus.active,
      editedAt: (map['editedAt'] as num?)?.toInt(),
      deletedAt: (map['deletedAt'] as num?)?.toInt(),
      editHistory: ((map['editHistory'] as List?) ?? const [])
          .map((e) => MessageEdit.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      mediaPath: map['mediaPath'] as String?,
      mediaType: mediaTypeFromString(map['mediaType'] as String?),
      mediaMime: map['mediaMime'] as String?,
    );
  }
}
