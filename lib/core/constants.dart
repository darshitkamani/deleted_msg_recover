import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';
import 'models/media_type.dart';

const String pkgWhatsApp = 'com.whatsapp';
const String pkgWhatsAppBusiness = 'com.whatsapp.w4b';

String appLabelForPackage(BuildContext context, String package) {
  final l10n = AppLocalizations.of(context);
  switch (package) {
    case pkgWhatsAppBusiness:
      return l10n.appWhatsAppBusiness;
    case pkgWhatsApp:
    default:
      return l10n.appWhatsApp;
  }
}

String mediaTypeLabel(BuildContext context, MediaType type) {
  final l10n = AppLocalizations.of(context);
  switch (type) {
    case MediaType.image:
      return l10n.mediaTypeImage;
    case MediaType.video:
      return l10n.mediaTypeVideo;
    case MediaType.audio:
      return l10n.mediaTypeAudio;
    case MediaType.document:
      return l10n.mediaTypeDocument;
    case MediaType.sticker:
      return l10n.mediaTypeSticker;
    case MediaType.gif:
      return l10n.mediaTypeGif;
    case MediaType.none:
      return '';
  }
}
