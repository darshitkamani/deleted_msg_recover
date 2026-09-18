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

  /// No description provided for @appTourTitle.
  ///
  /// In en, this message translates to:
  /// **'Here\'s your app'**
  String get appTourTitle;

  /// No description provided for @appTourSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A quick look at what each tab does.'**
  String get appTourSubtitle;

  /// No description provided for @appTourFeatureRecoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Recover'**
  String get appTourFeatureRecoverTitle;

  /// No description provided for @appTourFeatureRecoverDescription.
  ///
  /// In en, this message translates to:
  /// **'See every deleted message, right where it happened.'**
  String get appTourFeatureRecoverDescription;

  /// No description provided for @appTourFeatureChatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get appTourFeatureChatsTitle;

  /// No description provided for @appTourFeatureChatsDescription.
  ///
  /// In en, this message translates to:
  /// **'Every captured conversation, organized like WhatsApp itself.'**
  String get appTourFeatureChatsDescription;

  /// No description provided for @appTourFeatureStatusesTitle.
  ///
  /// In en, this message translates to:
  /// **'Statuses'**
  String get appTourFeatureStatusesTitle;

  /// No description provided for @appTourFeatureStatusesDescription.
  ///
  /// In en, this message translates to:
  /// **'Save statuses before they expire and disappear.'**
  String get appTourFeatureStatusesDescription;

  /// No description provided for @appTourFeatureDirectChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get appTourFeatureDirectChatTitle;

  /// No description provided for @appTourFeatureDirectChatDescription.
  ///
  /// In en, this message translates to:
  /// **'Jump straight into a single chat\'s recovered history.'**
  String get appTourFeatureDirectChatDescription;

  /// No description provided for @appTourFeatureSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get appTourFeatureSettingsTitle;

  /// No description provided for @appTourFeatureSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage monitored apps, permissions, and language.'**
  String get appTourFeatureSettingsDescription;

  /// No description provided for @appTourContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get appTourContinueButton;

  /// No description provided for @splashTaglineDetecting.
  ///
  /// In en, this message translates to:
  /// **'Detecting deleted messages...'**
  String get splashTaglineDetecting;

  /// No description provided for @splashTaglineRecovering.
  ///
  /// In en, this message translates to:
  /// **'Recovering instantly...'**
  String get splashTaglineRecovering;

  /// No description provided for @splashTaglineTracking.
  ///
  /// In en, this message translates to:
  /// **'Tracking edits & new messages...'**
  String get splashTaglineTracking;

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

  /// No description provided for @navRecover.
  ///
  /// In en, this message translates to:
  /// **'Recover'**
  String get navRecover;

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

  /// No description provided for @navDirectChat.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get navDirectChat;

  /// No description provided for @deletedMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted messages'**
  String get deletedMessagesTitle;

  /// No description provided for @recoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Message Recovery'**
  String get recoverTitle;

  /// No description provided for @recoverTagline.
  ///
  /// In en, this message translates to:
  /// **'Get back what was deleted'**
  String get recoverTagline;

  /// No description provided for @recoverPlusBadge.
  ///
  /// In en, this message translates to:
  /// **'Recovery+'**
  String get recoverPlusBadge;

  /// No description provided for @recoverPermissionBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification access needed'**
  String get recoverPermissionBannerTitle;

  /// No description provided for @recoverPermissionBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Turn this on so deleted messages can actually be caught.'**
  String get recoverPermissionBannerBody;

  /// No description provided for @recoverPermissionBannerAction.
  ///
  /// In en, this message translates to:
  /// **'Enable now'**
  String get recoverPermissionBannerAction;

  /// No description provided for @recoverRecentActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recoverRecentActivityTitle;

  /// No description provided for @recoverSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get recoverSeeAll;

  /// No description provided for @recoverEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing recovered yet'**
  String get recoverEmptyTitle;

  /// No description provided for @recoverEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Deleted and edited messages will show up here as soon as they\'re captured.'**
  String get recoverEmptyBody;

  /// No description provided for @recoverStatsMonitored.
  ///
  /// In en, this message translates to:
  /// **'Monitored chats'**
  String get recoverStatsMonitored;

  /// No description provided for @recoverStatsCaptured.
  ///
  /// In en, this message translates to:
  /// **'Messages captured'**
  String get recoverStatsCaptured;

  /// No description provided for @exitAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave already?'**
  String get exitAppTitle;

  /// No description provided for @exitAppBody.
  ///
  /// In en, this message translates to:
  /// **'Your recovered messages stay saved right here. Take a quick look below before you go.'**
  String get exitAppBody;

  /// No description provided for @exitAppSponsoredLabel.
  ///
  /// In en, this message translates to:
  /// **'Sponsored'**
  String get exitAppSponsoredLabel;

  /// No description provided for @exitAppBackButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get exitAppBackButton;

  /// No description provided for @exitAppCloseButton.
  ///
  /// In en, this message translates to:
  /// **'Close app'**
  String get exitAppCloseButton;

  /// No description provided for @exitChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this chat?'**
  String get exitChatTitle;

  /// No description provided for @exitChatBody.
  ///
  /// In en, this message translates to:
  /// **'Your recovered messages stay saved right here. Take a quick look below before you go.'**
  String get exitChatBody;

  /// No description provided for @exitChatBackButton.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get exitChatBackButton;

  /// No description provided for @exitChatLeaveButton.
  ///
  /// In en, this message translates to:
  /// **'Leave chat'**
  String get exitChatLeaveButton;

  /// No description provided for @recoverChatRecoveryHeader.
  ///
  /// In en, this message translates to:
  /// **'Chat Recovery'**
  String get recoverChatRecoveryHeader;

  /// No description provided for @recoverMediaRecoveryHeader.
  ///
  /// In en, this message translates to:
  /// **'Media Recovery'**
  String get recoverMediaRecoveryHeader;

  /// No description provided for @recoverMoreHeader.
  ///
  /// In en, this message translates to:
  /// **'More Recovery'**
  String get recoverMoreHeader;

  /// No description provided for @recoverTextMessage.
  ///
  /// In en, this message translates to:
  /// **'Text Message'**
  String get recoverTextMessage;

  /// No description provided for @recoverVoiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice Message'**
  String get recoverVoiceMessage;

  /// No description provided for @recoverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get recoverPhoto;

  /// No description provided for @recoverVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get recoverVideo;

  /// No description provided for @recoverFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get recoverFiles;

  /// No description provided for @recoverStickersGifs.
  ///
  /// In en, this message translates to:
  /// **'Stickers & GIFs'**
  String get recoverStickersGifs;

  /// No description provided for @recoverMediaEmptyState.
  ///
  /// In en, this message translates to:
  /// **'Nothing recovered here yet.'**
  String get recoverMediaEmptyState;

  /// No description provided for @mediaFolderAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Grant folder access'**
  String get mediaFolderAccessTitle;

  /// No description provided for @mediaFolderAccessDescription.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp keeps downloaded photos, videos, files and stickers in its own Media folder. Recovering them here -- even ones whose message was deleted -- needs access to that folder once.'**
  String get mediaFolderAccessDescription;

  /// No description provided for @mediaFolderAccessAction.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get mediaFolderAccessAction;

  /// No description provided for @mediaFolderAccessDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Access wasn\'t granted. Make sure to select the folder shown above and tap \"Use this folder\".'**
  String get mediaFolderAccessDeniedMessage;

  /// No description provided for @mediaFolderEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Empty here'**
  String get mediaFolderEmptyTitle;

  /// No description provided for @mediaFolderScanningState.
  ///
  /// In en, this message translates to:
  /// **'Scanning for recoverable files…'**
  String get mediaFolderScanningState;

  /// No description provided for @errorStateTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorStateTitle;

  /// No description provided for @errorStateRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get errorStateRetryAction;

  /// No description provided for @mediaFolderViewGuide.
  ///
  /// In en, this message translates to:
  /// **'View the Guide'**
  String get mediaFolderViewGuide;

  /// No description provided for @mediaGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'How to use'**
  String get mediaGuideTitle;

  /// No description provided for @mediaGuideFolderAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow Folder Access'**
  String get mediaGuideFolderAccessTitle;

  /// No description provided for @mediaGuideFolderAccessGrantedBody.
  ///
  /// In en, this message translates to:
  /// **'Access granted -- recovered files show up here automatically.'**
  String get mediaGuideFolderAccessGrantedBody;

  /// No description provided for @mediaGuideFolderAccessBody.
  ///
  /// In en, this message translates to:
  /// **'Tap to pick WhatsApp\'s Media folder, so recovered files can be found and copied here.'**
  String get mediaGuideFolderAccessBody;

  /// No description provided for @mediaGuideAutoDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Media auto-download'**
  String get mediaGuideAutoDownloadTitle;

  /// No description provided for @mediaGuideAutoDownloadBody.
  ///
  /// In en, this message translates to:
  /// **'Go to WhatsApp → Settings → Storage and Data, then enable Media Auto-Download for all options. Files that are downloaded stay recoverable here even after the message is deleted -- ones WhatsApp never downloaded can\'t be.'**
  String get mediaGuideAutoDownloadBody;

  /// No description provided for @mediaGuideOpenWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Open WhatsApp'**
  String get mediaGuideOpenWhatsApp;

  /// No description provided for @mediaGuideOpenAppFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open WhatsApp -- is it installed?'**
  String get mediaGuideOpenAppFailed;

  /// No description provided for @directChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Direct Chat'**
  String get directChatTitle;

  /// No description provided for @directChatNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Input Number'**
  String get directChatNumberLabel;

  /// No description provided for @countryPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search country or code'**
  String get countryPickerSearchHint;

  /// No description provided for @countryPickerNoResults.
  ///
  /// In en, this message translates to:
  /// **'No countries match your search'**
  String get countryPickerNoResults;

  /// No description provided for @directChatMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Input Message'**
  String get directChatMessageLabel;

  /// No description provided for @directChatSendAction.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get directChatSendAction;

  /// No description provided for @directChatCopyLinkAction.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get directChatCopyLinkAction;

  /// No description provided for @directChatNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a phone number first'**
  String get directChatNumberRequired;

  /// No description provided for @directChatLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get directChatLinkCopied;

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Recover Deleted WA Messages'**
  String get paywallTitle;

  /// No description provided for @paywallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enhanced recovery success'**
  String get paywallSubtitle;

  /// No description provided for @paywallFeatureSeen.
  ///
  /// In en, this message translates to:
  /// **'View chats without being “Seen”'**
  String get paywallFeatureSeen;

  /// No description provided for @paywallFeaturePrivate.
  ///
  /// In en, this message translates to:
  /// **'100% Private - On-device only'**
  String get paywallFeaturePrivate;

  /// No description provided for @paywallFeatureAdsFree.
  ///
  /// In en, this message translates to:
  /// **'Ads-free'**
  String get paywallFeatureAdsFree;

  /// No description provided for @paywallTrialBadge.
  ///
  /// In en, this message translates to:
  /// **'3 Days Free Trial'**
  String get paywallTrialBadge;

  /// No description provided for @paywallMonthlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Monthly ₹1,050.00'**
  String get paywallMonthlyLabel;

  /// No description provided for @paywallMonthlySubLabel.
  ///
  /// In en, this message translates to:
  /// **'No Payment Now'**
  String get paywallMonthlySubLabel;

  /// No description provided for @paywallSaveBadge.
  ///
  /// In en, this message translates to:
  /// **'Save 99%'**
  String get paywallSaveBadge;

  /// No description provided for @paywallLifetimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Lifetime ₹1,500.00'**
  String get paywallLifetimeLabel;

  /// No description provided for @paywallLifetimeSubLabel.
  ///
  /// In en, this message translates to:
  /// **'One-time Payment'**
  String get paywallLifetimeSubLabel;

  /// No description provided for @paywallContinueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get paywallContinueAction;

  /// No description provided for @paywallDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Auto-renewable, cancel anytime'**
  String get paywallDisclaimer;

  /// No description provided for @paywallComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Purchases aren\'t available yet -- coming soon.'**
  String get paywallComingSoon;

  /// No description provided for @chatsEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No chats captured yet. Once a WhatsApp notification arrives, it will show up here.'**
  String get chatsEmptyState;

  /// No description provided for @welcomeChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Recover Deleted Message'**
  String get welcomeChatTitle;

  /// No description provided for @welcomeChatPreview.
  ///
  /// In en, this message translates to:
  /// **'If you want to ...'**
  String get welcomeChatPreview;

  /// No description provided for @welcomeChatGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, dear'**
  String get welcomeChatGreeting;

  /// No description provided for @welcomeChatIntro.
  ///
  /// In en, this message translates to:
  /// **'If you want to'**
  String get welcomeChatIntro;

  /// No description provided for @welcomeChatFeatureRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore deleted messages'**
  String get welcomeChatFeatureRestore;

  /// No description provided for @welcomeChatFeatureUnseen.
  ///
  /// In en, this message translates to:
  /// **'Read message without being seen'**
  String get welcomeChatFeatureUnseen;

  /// No description provided for @welcomeChatSeeHowToUse.
  ///
  /// In en, this message translates to:
  /// **'See how to use'**
  String get welcomeChatSeeHowToUse;

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

  /// No description provided for @updateReadyMessage.
  ///
  /// In en, this message translates to:
  /// **'A new update is ready to install.'**
  String get updateReadyMessage;

  /// No description provided for @updateReadyAction.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get updateReadyAction;

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

  /// No description provided for @permissionChangeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Open system settings?'**
  String get permissionChangeConfirmTitle;

  /// No description provided for @permissionChangeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" can only be changed from system settings, not directly here. Continue?'**
  String permissionChangeConfirmBody(String title);

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

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

  /// No description provided for @settingsHowItWorksDetectionTitle.
  ///
  /// In en, this message translates to:
  /// **'How detection works'**
  String get settingsHowItWorksDetectionTitle;

  /// No description provided for @settingsHowItWorksDetectionBody.
  ///
  /// In en, this message translates to:
  /// **'This app backs up incoming WhatsApp notifications locally. A message is marked \"deleted\" when its notification disappears before you\'ve opened that chat here -- a best-effort signal, not a guarantee, since WhatsApp doesn\'t publish an official \"deleted\" event.'**
  String get settingsHowItWorksDetectionBody;

  /// No description provided for @settingsHowItWorksEditedTitle.
  ///
  /// In en, this message translates to:
  /// **'Edited messages'**
  String get settingsHowItWorksEditedTitle;

  /// No description provided for @settingsHowItWorksEditedBody.
  ///
  /// In en, this message translates to:
  /// **'If WhatsApp updates a message\'s notification with new text before you\'ve seen it, the original text is kept and marked \"Edited\" so you can still see what it said before.'**
  String get settingsHowItWorksEditedBody;

  /// No description provided for @settingsHowItWorksMediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Media recovery'**
  String get settingsHowItWorksMediaTitle;

  /// No description provided for @settingsHowItWorksMediaBody.
  ///
  /// In en, this message translates to:
  /// **'Photos, videos, and voice notes are only recovered if WhatsApp attached them to the notification itself.'**
  String get settingsHowItWorksMediaBody;

  /// No description provided for @settingsHowItWorksPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'100% on this device'**
  String get settingsHowItWorksPrivacyTitle;

  /// No description provided for @settingsHowItWorksPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing is ever sent off this device -- everything stays stored locally, for your eyes only.'**
  String get settingsHowItWorksPrivacyBody;

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

  /// No description provided for @settingsBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Some phone brands kill background apps'**
  String get settingsBackgroundTitle;

  /// No description provided for @settingsBackgroundDesc.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi, Oppo, Vivo, OnePlus, Huawei and Samsung are more aggressive than stock Android, even with battery optimization already excluded above. If messages stop being captured after a while, allow this app to run in the background from your phone\'s autostart / protected apps settings.'**
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
