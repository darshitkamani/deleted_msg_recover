class Chat {
  final String chatKey;
  final String package;
  final String title;
  final bool isGroup;
  final String? lastText;
  final int lastTimestamp;
  final int totalCount;
  final bool lastIsDeleted;
  final bool lastIsEdited;

  const Chat({
    required this.chatKey,
    required this.package,
    required this.title,
    required this.isGroup,
    required this.lastText,
    required this.lastTimestamp,
    required this.totalCount,
    this.lastIsDeleted = false,
    this.lastIsEdited = false,
  });

  bool get isBusiness => package == 'com.whatsapp.w4b';

  factory Chat.fromMap(Map<dynamic, dynamic> map) {
    return Chat(
      chatKey: map['chatKey'] as String,
      package: map['package'] as String,
      title: map['title'] as String,
      isGroup: map['isGroup'] as bool? ?? false,
      lastText: map['lastText'] as String?,
      lastTimestamp: (map['lastTimestamp'] as num?)?.toInt() ?? 0,
      totalCount: (map['totalCount'] as num?)?.toInt() ?? 0,
      lastIsDeleted: map['lastStatus'] == 'deleted',
      lastIsEdited: map['lastIsEdited'] as bool? ?? false,
    );
  }
}
