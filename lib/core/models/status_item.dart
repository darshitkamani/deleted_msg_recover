class StatusItem {
  final String path;
  final bool isVideo;
  final int lastModified;

  const StatusItem({
    required this.path,
    required this.isVideo,
    required this.lastModified,
  });

  factory StatusItem.fromMap(Map<dynamic, dynamic> map) {
    return StatusItem(
      path: map['path'] as String,
      isVideo: map['isVideo'] as bool? ?? false,
      lastModified: (map['lastModified'] as num?)?.toInt() ?? 0,
    );
  }
}
