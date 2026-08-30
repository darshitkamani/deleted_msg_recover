import 'media_type.dart';

/// One file recovered by scanning WhatsApp's own Media folder on disk
/// (see [MediaFolderRepository] on the native side) -- unlike
/// [RecoveredMedia], which comes from a captured notification, this is
/// whatever WhatsApp itself downloaded and still has sitting in storage,
/// whether or not the message that sent it was later deleted.
class MediaFolderItem {
  final String path;
  final String fileName;
  final MediaType mediaType;
  final int lastModified;

  const MediaFolderItem({
    required this.path,
    required this.fileName,
    required this.mediaType,
    required this.lastModified,
  });

  factory MediaFolderItem.fromMap(Map<dynamic, dynamic> map) {
    return MediaFolderItem(
      path: map['path'] as String,
      fileName: map['fileName'] as String,
      mediaType: mediaTypeFromString(map['mediaType'] as String?),
      lastModified: (map['lastModified'] as num).toInt(),
    );
  }
}
