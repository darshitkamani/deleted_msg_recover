import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Recover Deleted Messages'**
  String get appTitle;

  /// No description provided for @dateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateToday;

  /// No description provided for @dateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dateYesterday;

  /// No description provided for @onboardingIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Never miss a deleted message'**
  String get onboardingIntroTitle;

  /// No description provided for @onboardingIntroDescription.
  ///
  /// In en, this message translates to:
  /// **'This app quietly backs up your WhatsApp and WhatsApp Business notifications, so if someone deletes a message before you see it, you still can.'**
  String get onboardingIntroDescription;

  /// No description provided for @onboardingHowItWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get onboardingHowItWorksTitle;

  /// No description provided for @onboardingHowItWorksDescription.
  ///
  /// In en, this message translates to:
  /// **'When a WhatsApp notification disappears before you open that chat here, it\'s flagged as deleted and you\'re alerted instantly.'**
  String get onboardingHowItWorksDescription;

  /// No description provided for @onboardingPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'100% on your device'**
  String get onboardingPrivacyTitle;

  /// No description provided for @onboardingPrivacyDescription.
  ///
  /// In en, this message translates to:
  /// **'Nothing is ever uploaded anywhere. Everything stays stored locally in this app, for your eyes only.'**
  String get onboardingPrivacyDescription;

  /// No description provided for @permissionRequiredTag.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get permissionRequiredTag;

  /// No description provided for @permissionRecommendedTag.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get permissionRecommendedTag;

  /// No description provided for @notificationAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification access'**
  String get notificationAccessTitle;

  /// No description provided for @notificationAccessDescription.
  ///
  /// In en, this message translates to:
  /// **'Without this the app cannot see incoming WhatsApp notifications at all. Tap below, find this app in the list, and turn the toggle on.'**
  String get notificationAccessDescription;

  /// No description provided for @notificationAccessGrantedLabel.
  ///
  /// In en, this message translates to:
  /// **'Access granted'**
  String get notificationAccessGrantedLabel;

  /// No description provided for @notificationAccessActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Open notification access settings'**
  String get notificationAccessActionLabel;

  /// No description provided for @batteryOptimizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization'**
  String get batteryOptimizationTitle;

  /// No description provided for @batteryOptimizationDescription.
  ///
  /// In en, this message translates to:
  /// **'Excluding this app from battery optimization stops Android from killing the background listener, so no messages are missed while your phone is idle.'**
  String get batteryOptimizationDescription;

  /// No description provided for @batteryOptimizationGrantedLabel.
  ///
  /// In en, this message translates to:
  /// **'Excluded from optimization'**
  String get batteryOptimizationGrantedLabel;

  /// No description provided for @batteryOptimizationActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Exclude from battery optimization'**
  String get batteryOptimizationActionLabel;

  /// No description provided for @nextButton.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextButton;

  /// No description provided for @getStartedButton.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStartedButton;

  /// No description provided for @navChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get navChats;

  /// No description provided for @navDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get navDeleted;

  /// No description provided for @navStatuses.
  ///
  /// In en, this message translates to:
  /// **'Statuses'**
  String get navStatuses;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @deletedMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted messages'**
  String get deletedMessagesTitle;

  /// No description provided for @chatsEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No chats captured yet. Once a WhatsApp notification arrives, it will show up here.'**
  String get chatsEmptyState;

  /// No description provided for @statusAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Grant access to Statuses'**
  String get statusAccessTitle;

  /// No description provided for @statusAccessDescription.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp keeps current statuses in their own folder on your device for about 24 hours. To save them here, pick that folder once in the next screen.'**
  String get statusAccessDescription;

  /// No description provided for @statusFolderPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Navigate to:'**
  String get statusFolderPathLabel;

  /// No description provided for @statusAccessAction.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get statusAccessAction;

  /// No description provided for @statusAccessDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Access wasn\'t granted. Make sure to select the exact Statuses folder shown above and tap \"Use this folder\".'**
  String get statusAccessDeniedMessage;

  /// No description provided for @statusesEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No statuses saved yet. Open WhatsApp Status once so it downloads, then pull to refresh here.'**
  String get statusesEmptyState;

  /// No description provided for @statusFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get statusFilterAll;

  /// No description provided for @statusFilterImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get statusFilterImages;

  /// No description provided for @statusFilterVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get statusFilterVideos;

  /// No description provided for @statusDownloadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get statusDownloadTooltip;

  /// No description provided for @statusShareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get statusShareTooltip;

  /// No description provided for @statusDownloadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get statusDownloadSuccess;

  /// No description provided for @statusDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save this file'**
  String get statusDownloadFailed;

  /// No description provided for @appWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get appWhatsApp;

  /// No description provided for @appWhatsAppBusiness.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Business'**
  String get appWhatsAppBusiness;

  /// No description provided for @deletedBadge.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 deleted} other{{count} deleted}}'**
  String deletedBadge(int count);

  /// No description provided for @chatDetailEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages captured for this chat.'**
  String get chatDetailEmpty;

  /// No description provided for @newMessagesBanner.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 new message} other{{count} new messages}}'**
  String newMessagesBanner(int count);

  /// No description provided for @deletedFeedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing recovered yet. Deleted messages will show up here as soon as they are detected.'**
  String get deletedFeedEmpty;

  /// No description provided for @deletedFeedMediaWithSender.
  ///
  /// In en, this message translates to:
  /// **'{sender}: {label}'**
  String deletedFeedMediaWithSender(String sender, String label);

  /// No description provided for @deletedFeedNoText.
  ///
  /// In en, this message translates to:
  /// **'[no text captured]'**
  String get deletedFeedNoText;

  /// No description provided for @mediaTypeImage.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get mediaTypeImage;

  /// No description provided for @mediaTypeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get mediaTypeVideo;

  /// No description provided for @mediaTypeAudio.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get mediaTypeAudio;

  /// No description provided for @mediaTypeDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get mediaTypeDocument;

  /// No description provided for @mediaTypeSticker.
  ///
  /// In en, this message translates to:
  /// **'Sticker'**
  String get mediaTypeSticker;

  /// No description provided for @mediaTypeGif.
  ///
  /// In en, this message translates to:
  /// **'GIF'**
  String get mediaTypeGif;

  /// No description provided for @openFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this file'**
  String get openFileFailed;

  /// No description provided for @linkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this link'**
  String get linkOpenFailed;

  /// No description provided for @copyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyAction;

  /// No description provided for @shareAction.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareAction;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @documentNotRecoverableTitle.
  ///
  /// In en, this message translates to:
  /// **'Not recoverable'**
  String get documentNotRecoverableTitle;

  /// No description provided for @documentNotRecoverableExplanation.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp didn\'t attach this file to the notification, only its name, so it can\'t be recovered.'**
  String get documentNotRecoverableExplanation;

  /// No description provided for @noReadReceiptsExplanation.
  ///
  /// In en, this message translates to:
  /// **'Viewing this chat here doesn\'t send a read receipt (blue tick) on WhatsApp.'**
  String get noReadReceiptsExplanation;

  /// No description provided for @editedBadge.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get editedBadge;

  /// No description provided for @deletedMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'This message was deleted'**
  String get deletedMessageLabel;

  /// No description provided for @editedToExplanation.
  ///
  /// In en, this message translates to:
  /// **'This message was later edited to: \"{newText}\"'**
  String editedToExplanation(String newText);

  /// No description provided for @settingsPermissionsHeader.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get settingsPermissionsHeader;

  /// No description provided for @settingsNotificationAccessDesc.
  ///
  /// In en, this message translates to:
  /// **'Needed to capture WhatsApp notifications.'**
  String get settingsNotificationAccessDesc;

  /// No description provided for @settingsBatteryDesc.
  ///
  /// In en, this message translates to:
  /// **'Excluding this app keeps the listener alive in the background.'**
  String get settingsBatteryDesc;

  /// No description provided for @openSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettingsAction;

  /// No description provided for @excludeAppAction.
  ///
  /// In en, this message translates to:
  /// **'Exclude app'**
  String get excludeAppAction;

  /// No description provided for @settingsMonitoredAppsHeader.
  ///
  /// In en, this message translates to:
  /// **'Monitored apps'**
  String get settingsMonitoredAppsHeader;

  /// No description provided for @settingsDataHeader.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsDataHeader;

  /// No description provided for @clearAllDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all captured data'**
  String get clearAllDataTitle;

  /// No description provided for @clearAllDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Removes every stored chat and message from this device.'**
  String get clearAllDataSubtitle;

  /// No description provided for @clearAllDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all data?'**
  String get clearAllDialogTitle;

  /// No description provided for @clearAllDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get clearAllDialogContent;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @clearButton.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearButton;

  /// No description provided for @settingsHowItWorksHeader.
  ///
  /// In en, this message translates to:
  /// **'How this works'**
  String get settingsHowItWorksHeader;

  /// No description provided for @settingsHowItWorksBody.
  ///
  /// In en, this message translates to:
  /// **'This app backs up incoming WhatsApp notifications locally. A message is marked \"deleted\" when its notification disappears before you opened that chat inside this app -- this is a best-effort signal, not a guarantee, since WhatsApp does not publish an official \"message deleted\" event. The same applies to edited messages: if WhatsApp updates a message\'s notification with new text before you\'ve seen it, the original text is kept and marked \"Edited\" so you can still see what it said before. Media is only recovered if WhatsApp attached it to the notification itself. Nothing is ever sent off this device.'**
  String get settingsHowItWorksBody;

  /// No description provided for @settingsLanguageHeader.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageHeader;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get languageHindi;

  /// No description provided for @settingsBackgroundHeader.
  ///
  /// In en, this message translates to:
  /// **'Background reliability'**
  String get settingsBackgroundHeader;

  /// No description provided for @settingsBackgroundDesc.
  ///
  /// In en, this message translates to:
  /// **'Some phone brands (Xiaomi, Oppo, Vivo, OnePlus, Huawei, Samsung) kill background apps more aggressively than stock Android, even with battery optimization already excluded above. If messages stop being captured after the app hasn\'t been opened for a while, open your phone\'s autostart / protected apps / background activity settings for this app and allow it to run in the background.'**
  String get settingsBackgroundDesc;

  /// No description provided for @settingsBackgroundAction.
  ///
  /// In en, this message translates to:
  /// **'Open background app settings'**
  String get settingsBackgroundAction;

  /// No description provided for @iosUnsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not available on iOS'**
  String get iosUnsupportedTitle;

  /// No description provided for @iosUnsupportedBody.
  ///
  /// In en, this message translates to:
  /// **'This app recovers deleted WhatsApp messages by reading your device\'s notification history in the background. iOS does not allow any app to do that for other apps\' notifications, so this feature cannot work here. It is only available on Android.'**
  String get iosUnsupportedBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
