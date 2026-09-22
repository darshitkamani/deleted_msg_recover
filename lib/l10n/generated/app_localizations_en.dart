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
  String get appTourTitle => 'Here\'s your app';

  @override
  String get appTourSubtitle => 'A quick look at what each tab does.';

  @override
  String get appTourFeatureRecoverTitle => 'Recover';

  @override
  String get appTourFeatureRecoverDescription =>
      'See every deleted message, right where it happened.';

  @override
  String get appTourFeatureChatsTitle => 'Chats';

  @override
  String get appTourFeatureChatsDescription =>
      'Every captured conversation, organized like WhatsApp itself.';

  @override
  String get appTourFeatureStatusesTitle => 'Statuses';

  @override
  String get appTourFeatureStatusesDescription =>
      'Save statuses before they expire and disappear.';

  @override
  String get appTourFeatureDirectChatTitle => 'Direct';

  @override
  String get appTourFeatureDirectChatDescription =>
      'Jump straight into a single chat\'s recovered history.';

  @override
  String get appTourFeatureSettingsTitle => 'Settings';

  @override
  String get appTourFeatureSettingsDescription =>
      'Manage monitored apps, permissions, and language.';

  @override
  String get appTourContinueButton => 'Continue';

  @override
  String get splashTaglineDetecting => 'Detecting deleted messages...';

  @override
  String get splashTaglineRecovering => 'Recovering instantly...';

  @override
  String get splashTaglineTracking => 'Tracking edits & new messages...';

  @override
  String get navChats => 'Chats';

  @override
  String get navDeleted => 'Deleted';

  @override
  String get navRecover => 'Recover';

  @override
  String get navStatuses => 'Statuses';

  @override
  String get navSettings => 'Settings';

  @override
  String get navDirectChat => 'Direct';

  @override
  String get deletedMessagesTitle => 'Deleted messages';

  @override
  String get recoverTitle => 'Message Recovery';

  @override
  String get recoverTagline => 'Get back what was deleted';

  @override
  String get recoverPlusBadge => 'Recovery+';

  @override
  String get recoverPermissionBannerTitle => 'Notification access needed';

  @override
  String get recoverPermissionBannerBody =>
      'Turn this on so deleted messages can actually be caught.';

  @override
  String get recoverPermissionBannerAction => 'Enable now';

  @override
  String get recoverRecentActivityTitle => 'Recent activity';

  @override
  String get recoverSeeAll => 'See all';

  @override
  String get recoverEmptyTitle => 'Nothing recovered yet';

  @override
  String get recoverEmptyBody =>
      'Deleted and edited messages will show up here as soon as they\'re captured.';

  @override
  String get recoverStatsMonitored => 'Monitored chats';

  @override
  String get recoverStatsCaptured => 'Messages captured';

  @override
  String get exitAppTitle => 'Leave already?';

  @override
  String get exitAppBody =>
      'Your recovered messages stay saved right here. Take a quick look below before you go.';

  @override
  String get exitAppSponsoredLabel => 'Sponsored';

  @override
  String get exitAppBackButton => 'Back';

  @override
  String get exitAppCloseButton => 'Close app';

  @override
  String get exitChatTitle => 'Leave this chat?';

  @override
  String get exitChatBody =>
      'Your recovered messages stay saved right here. Take a quick look below before you go.';

  @override
  String get exitChatBackButton => 'Stay';

  @override
  String get exitChatLeaveButton => 'Leave chat';

  @override
  String get recoverChatRecoveryHeader => 'Chat Recovery';

  @override
  String get recoverMediaRecoveryHeader => 'Media Recovery';

  @override
  String get recoverMoreHeader => 'More Recovery';

  @override
  String get recoverTextMessage => 'Text Message';

  @override
  String get recoverVoiceMessage => 'Voice Message';

  @override
  String get recoverPhoto => 'Photo';

  @override
  String get recoverVideo => 'Video';

  @override
  String get recoverFiles => 'Files';

  @override
  String get recoverStickersGifs => 'Stickers & GIFs';

  @override
  String get recoverMediaEmptyState => 'Nothing recovered here yet.';

  @override
  String get mediaFolderAccessTitle => 'Grant folder access';

  @override
  String get mediaFolderAccessDescription =>
      'WhatsApp keeps downloaded photos, videos, files and stickers in its own Media folder. Recovering them here -- even ones whose message was deleted -- needs access to that folder once.';

  @override
  String get mediaFolderAccessAction => 'Choose folder';

  @override
  String get mediaFolderAccessDeniedMessage =>
      'Access wasn\'t granted. Make sure to select the folder shown above and tap \"Use this folder\".';

  @override
  String get mediaFolderEmptyTitle => 'Empty here';

  @override
  String get mediaFolderScanningState => 'Scanning for recoverable files…';

  @override
  String get errorStateTitle => 'Something went wrong';

  @override
  String get errorStateRetryAction => 'Try again';

  @override
  String get mediaFolderViewGuide => 'View the Guide';

  @override
  String get mediaGuideTitle => 'How to use';

  @override
  String get mediaGuideFolderAccessTitle => 'Allow Folder Access';

  @override
  String get mediaGuideFolderAccessGrantedBody =>
      'Access granted -- recovered files show up here automatically.';

  @override
  String get mediaGuideFolderAccessBody =>
      'Tap to pick WhatsApp\'s Media folder, so recovered files can be found and copied here.';

  @override
  String get mediaGuideAutoDownloadTitle => 'Enable Media auto-download';

  @override
  String get mediaGuideAutoDownloadBody =>
      'Go to WhatsApp → Settings → Storage and Data, then enable Media Auto-Download for all options. Files that are downloaded stay recoverable here even after the message is deleted -- ones WhatsApp never downloaded can\'t be.';

  @override
  String get mediaGuideOpenWhatsApp => 'Open WhatsApp';

  @override
  String get mediaGuideOpenAppFailed =>
      'Couldn\'t open WhatsApp -- is it installed?';

  @override
  String get directChatTitle => 'Direct Chat';

  @override
  String get directChatNumberLabel => 'Input Number';

  @override
  String get countryPickerSearchHint => 'Search country or code';

  @override
  String get countryPickerNoResults => 'No countries match your search';

  @override
  String get directChatMessageLabel => 'Input Message';

  @override
  String get directChatSendAction => 'Send';

  @override
  String get directChatCopyLinkAction => 'Copy Link';

  @override
  String get directChatNumberRequired => 'Enter a phone number first';

  @override
  String get directChatLinkCopied => 'Link copied';

  @override
  String get paywallTitle => 'Recover Deleted WA Messages';

  @override
  String get paywallSubtitle => 'Enhanced recovery success';

  @override
  String get paywallFeatureSeen => 'View chats without being “Seen”';

  @override
  String get paywallFeaturePrivate => '100% Private - On-device only';

  @override
  String get paywallFeatureAdsFree => 'Ads-free';

  @override
  String get paywallTrialBadge => '3 Days Free Trial';

  @override
  String get paywallMonthlyLabel => 'Monthly ₹1,050.00';

  @override
  String get paywallMonthlySubLabel => 'No Payment Now';

  @override
  String get paywallSaveBadge => 'Save 99%';

  @override
  String get paywallLifetimeLabel => 'Lifetime ₹1,500.00';

  @override
  String get paywallLifetimeSubLabel => 'One-time Payment';

  @override
  String get paywallContinueAction => 'Continue';

  @override
  String get paywallDisclaimer => 'Auto-renewable, cancel anytime';

  @override
  String get paywallComingSoon =>
      'Purchases aren\'t available yet -- coming soon.';

  @override
  String get chatsEmptyState =>
      'No chats captured yet. Once a WhatsApp notification arrives, it will show up here.';

  @override
  String get welcomeChatTitle => 'Recover Deleted Message';

  @override
  String get welcomeChatPreview => 'If you want to ...';

  @override
  String get welcomeChatGreeting => 'Hi, dear';

  @override
  String get welcomeChatIntro => 'If you want to';

  @override
  String get welcomeChatFeatureRestore => 'Restore deleted messages';

  @override
  String get welcomeChatFeatureUnseen => 'Read message without being seen';

  @override
  String get welcomeChatSeeHowToUse => 'See how to use';

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
  String get adLoadingTitle => 'Just a moment…';

  @override
  String get adLoadingDownloadBody =>
      'A short ad is loading, then your status will be saved to your gallery.';

  @override
  String get adLoadingShareBody =>
      'A short ad is loading, then your status will be ready to share.';

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
  String get updateReadyMessage => 'A new update is ready to install.';

  @override
  String get updateReadyAction => 'Restart';

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
  String get editedToLabel => 'Edited to';

  @override
  String editedToExplanation(String newText) {
    return 'This message was later edited to: \"$newText\"';
  }

  @override
  String get permissionChangeConfirmTitle => 'Open system settings?';

  @override
  String permissionChangeConfirmBody(String title) {
    return '\"$title\" can only be changed from system settings, not directly here. Continue?';
  }

  @override
  String get continueButton => 'Continue';

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
  String get settingsHowItWorksDetectionTitle => 'How detection works';

  @override
  String get settingsHowItWorksDetectionBody =>
      'This app backs up incoming WhatsApp notifications locally. A message is marked \"deleted\" when its notification disappears before you\'ve opened that chat here -- a best-effort signal, not a guarantee, since WhatsApp doesn\'t publish an official \"deleted\" event.';

  @override
  String get settingsHowItWorksEditedTitle => 'Edited messages';

  @override
  String get settingsHowItWorksEditedBody =>
      'If WhatsApp updates a message\'s notification with new text before you\'ve seen it, the original text is kept and marked \"Edited\" so you can still see what it said before.';

  @override
  String get settingsHowItWorksMediaTitle => 'Media recovery';

  @override
  String get settingsHowItWorksMediaBody =>
      'Photos, videos, and voice notes are only recovered if WhatsApp attached them to the notification itself.';

  @override
  String get settingsHowItWorksPrivacyTitle => '100% on this device';

  @override
  String get settingsHowItWorksPrivacyBody =>
      'Nothing is ever sent off this device -- everything stays stored locally, for your eyes only.';

  @override
  String get settingsLanguageHeader => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get settingsBackgroundHeader => 'Background reliability';

  @override
  String get settingsBackgroundTitle =>
      'Some phone brands kill background apps';

  @override
  String get settingsBackgroundDesc =>
      'Xiaomi, Oppo, Vivo, OnePlus, Huawei and Samsung are more aggressive than stock Android, even with battery optimization already excluded above. If messages stop being captured after a while, allow this app to run in the background from your phone\'s autostart / protected apps settings.';

  @override
  String get settingsBackgroundAction => 'Open background app settings';

  @override
  String get iosUnsupportedTitle => 'Not available on iOS';

  @override
  String get iosUnsupportedBody =>
      'This app recovers deleted WhatsApp messages by reading your device\'s notification history in the background. iOS does not allow any app to do that for other apps\' notifications, so this feature cannot work here. It is only available on Android.';
}
