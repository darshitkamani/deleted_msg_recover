/// Every place in the app a native ad can show, each with its own on/off key
/// in the hosted ad config (see AdRemoteConfig.nativePlacements) -- all on
/// unless the config says false.
enum NativePlacement {
  recover('showNativeRecover'),
  chats('showNativeChats'),
  chatDetail('showNativeChatDetail'),
  chatExitDialog('showNativeChatExitDialog'),
  appExitDialog('showNativeAppExitDialog'),
  statuses('showNativeStatuses'),
  welcomeChat('showNativeWelcomeChat'),
  directChat('showNativeDirectChat'),
  deleted('showNativeDeleted');

  /// The key in the ad config JSON.
  final String configKey;

  const NativePlacement(this.configKey);
}
