// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Recover Deleted Messages';

  @override
  String get dateToday => 'Today';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String get onboardingIntroTitle => 'Never miss a deleted message';

  @override
  String get onboardingIntroDescription =>
      'This app quietly backs up your WhatsApp and WhatsApp Business notifications, so if someone deletes a message before you see it, you still can.';

  @override
  String get onboardingHowItWorksTitle => 'How it works';

  @override
  String get onboardingHowItWorksDescription =>
      'When a WhatsApp notification disappears before you open that chat here, it\'s flagged as deleted and you\'re alerted instantly.';

  @override
  String get onboardingPrivacyTitle => '100% on your device';

  @override
  String get onboardingPrivacyDescription =>
      'Nothing is ever uploaded anywhere. Everything stays stored locally in this app, for your eyes only.';

  @override
  String get permissionRequiredTag => 'Required';

  @override
  String get permissionRecommendedTag => 'Recommended';

  @override
  String get notificationAccessTitle => 'Notification access';

  @override
  String get notificationAccessDescription =>
      'Without this the app cannot see incoming WhatsApp notifications at all. Tap below, find this app in the list, and turn the toggle on.';

  @override
  String get notificationAccessGrantedLabel => 'Access granted';

  @override
  String get notificationAccessActionLabel =>
      'Open notification access settings';

  @override
  String get batteryOptimizationTitle => 'Battery optimization';

  @override
  String get batteryOptimizationDescription =>
      'Excluding this app from battery optimization stops Android from killing the background listener, so no messages are missed while your phone is idle.';

  @override
  String get batteryOptimizationGrantedLabel => 'Excluded from optimization';

  @override
  String get batteryOptimizationActionLabel =>
      'Exclude from battery optimization';

  @override
  String get nextButton => 'Next';

  @override
  String get getStartedButton => 'Get started';

  @override
  String get navChats => 'Chats';

  @override
  String get navDeleted => 'Deleted';

  @override
  String get navStatuses => 'Statuses';

  @override
  String get navSettings => 'Settings';

  @override
  String get deletedMessagesTitle => 'Deleted messages';

  @override
  String get chatsEmptyState =>
      'No chats captured yet. Once a WhatsApp notification arrives, it will show up here.';

  @override
  String get statusAccessTitle => 'Grant access to Statuses';

  @override
  String get statusAccessDescription =>
      'WhatsApp keeps current statuses in their own folder on your device for about 24 hours. To save them here, pick that folder once in the next screen.';

  @override
  String get statusFolderPathLabel => 'Navigate to:';

  @override
  String get statusAccessAction => 'Choose folder';

  @override
  String get statusAccessDeniedMessage =>
      'Access wasn\'t granted. Make sure to select the exact Statuses folder shown above and tap \"Use this folder\".';

  @override
  String get statusesEmptyState =>
      'No statuses saved yet. Open WhatsApp Status once so it downloads, then pull to refresh here.';

  @override
  String get statusFilterAll => 'All';

  @override
  String get statusFilterImages => 'Images';

  @override
  String get statusFilterVideos => 'Videos';

  @override
  String get statusDownloadTooltip => 'Download';

  @override
  String get statusShareTooltip => 'Share';

  @override
  String get statusDownloadSuccess => 'Saved to gallery';

  @override
  String get statusDownloadFailed => 'Couldn\'t save this file';

  @override
  String get appWhatsApp => 'WhatsApp';

  @override
  String get appWhatsAppBusiness => 'WhatsApp Business';

  @override
  String deletedBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deleted',
      one: '1 deleted',
    );
    return '$_temp0';
  }

  @override
  String get chatDetailEmpty => 'No messages captured for this chat.';

  @override
  String newMessagesBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new messages',
      one: '1 new message',
    );
    return '$_temp0';
  }

  @override
  String get deletedFeedEmpty =>
      'Nothing recovered yet. Deleted messages will show up here as soon as they are detected.';

  @override
  String deletedFeedMediaWithSender(String sender, String label) {
    return '$sender: $label';
  }

  @override
  String get deletedFeedNoText => '[no text captured]';

  @override
  String get mediaTypeImage => 'Photo';

  @override
  String get mediaTypeVideo => 'Video';

  @override
  String get mediaTypeAudio => 'Voice message';

  @override
  String get mediaTypeDocument => 'Document';

  @override
  String get mediaTypeSticker => 'Sticker';

  @override
  String get mediaTypeGif => 'GIF';

  @override
  String get openFileFailed => 'Couldn\'t open this file';

  @override
  String get linkOpenFailed => 'Couldn\'t open this link';

  @override
  String get copyAction => 'Copy';

  @override
  String get shareAction => 'Share';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get documentNotRecoverableTitle => 'Not recoverable';

  @override
  String get documentNotRecoverableExplanation =>
      'WhatsApp didn\'t attach this file to the notification, only its name, so it can\'t be recovered.';

  @override
  String get noReadReceiptsExplanation =>
      'Viewing this chat here doesn\'t send a read receipt (blue tick) on WhatsApp.';

  @override
  String get editedBadge => 'Edited';

  @override
  String get deletedMessageLabel => 'This message was deleted';

  @override
  String editedToExplanation(String newText) {
    return 'This message was later edited to: \"$newText\"';
  }

  @override
  String get settingsPermissionsHeader => 'Permissions';

  @override
  String get settingsNotificationAccessDesc =>
      'Needed to capture WhatsApp notifications.';

  @override
  String get settingsBatteryDesc =>
      'Excluding this app keeps the listener alive in the background.';

  @override
  String get openSettingsAction => 'Open settings';

  @override
  String get excludeAppAction => 'Exclude app';

  @override
  String get settingsMonitoredAppsHeader => 'Monitored apps';

  @override
  String get settingsDataHeader => 'Data';

  @override
  String get clearAllDataTitle => 'Clear all captured data';

  @override
  String get clearAllDataSubtitle =>
      'Removes every stored chat and message from this device.';

  @override
  String get clearAllDialogTitle => 'Clear all data?';

  @override
  String get clearAllDialogContent => 'This cannot be undone.';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get clearButton => 'Clear';

  @override
  String get settingsHowItWorksHeader => 'How this works';

  @override
  String get settingsHowItWorksBody =>
      'This app backs up incoming WhatsApp notifications locally. A message is marked \"deleted\" when its notification disappears before you opened that chat inside this app -- this is a best-effort signal, not a guarantee, since WhatsApp does not publish an official \"message deleted\" event. The same applies to edited messages: if WhatsApp updates a message\'s notification with new text before you\'ve seen it, the original text is kept and marked \"Edited\" so you can still see what it said before. Media is only recovered if WhatsApp attached it to the notification itself. Nothing is ever sent off this device.';

  @override
  String get settingsLanguageHeader => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get settingsBackgroundHeader => 'Background reliability';

  @override
  String get settingsBackgroundDesc =>
      'Some phone brands (Xiaomi, Oppo, Vivo, OnePlus, Huawei, Samsung) kill background apps more aggressively than stock Android, even with battery optimization already excluded above. If messages stop being captured after the app hasn\'t been opened for a while, open your phone\'s autostart / protected apps / background activity settings for this app and allow it to run in the background.';

  @override
  String get settingsBackgroundAction => 'Open background app settings';

  @override
  String get iosUnsupportedTitle => 'Not available on iOS';

  @override
  String get iosUnsupportedBody =>
      'This app recovers deleted WhatsApp messages by reading your device\'s notification history in the background. iOS does not allow any app to do that for other apps\' notifications, so this feature cannot work here. It is only available on Android.';
}
