enum MediaType { image, video, audio, document, sticker, gif, none }

MediaType mediaTypeFromString(String? value) {
  switch (value) {
    case 'image':
      return MediaType.image;
    case 'video':
      return MediaType.video;
    case 'audio':
      return MediaType.audio;
    case 'document':
      return MediaType.document;
    case 'sticker':
      return MediaType.sticker;
    case 'gif':
      return MediaType.gif;
    default:
      return MediaType.none;
  }
}
