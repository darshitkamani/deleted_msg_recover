import 'package:flutter/services.dart';

import 'models/chat.dart';
import 'models/edited_deleted_message.dart';
import 'models/media_folder_item.dart';
import 'models/message.dart';
import 'models/recovered_media.dart';
import 'models/status_item.dart';

/// Thin wrapper around the platform channels exposed by the Android side
/// (see android/.../MainActivity.kt, NotificationListener.kt). Every method
/// here is a no-op-safe call; UI code should guard with Platform.isAndroid
/// before using this at all.
class NativeBridge {
  NativeBridge._();

  static const MethodChannel _methodChannel = MethodChannel('recover/native');
  static const EventChannel _eventChannel = EventChannel('recover/events');

  static Stream<Map<dynamic, dynamic>>? _events;

  static Stream<Map<dynamic, dynamic>> get events {
    _events ??= _eventChannel.receiveBroadcastStream().map(
      (event) => event as Map<dynamic, dynamic>,
    );
    return _events!;
  }

  static Future<bool> isNotificationAccessGranted() async {
    final result = await _methodChannel.invokeMethod<bool>(
      'isNotificationAccessGranted',
    );
    return result ?? false;
  }

  static Future<void> openNotificationAccessSettings() {
    return _methodChannel.invokeMethod('openNotificationAccessSettings');
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    final result = await _methodChannel.invokeMethod<bool>(
      'isIgnoringBatteryOptimizations',
    );
    return result ?? false;
  }

  /// Shows the system battery-optimization dialog; completes once it's
  /// dismissed, with whether the user allowed it.
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    final result = await _methodChannel.invokeMethod<bool>(
      'requestIgnoreBatteryOptimizations',
    );
    return result ?? false;
  }

  static Future<List<Chat>> getChats() async {
    final result = await _methodChannel.invokeMethod<List<dynamic>>('getChats');
    return (result ?? [])
        .map((e) => Chat.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  static Future<List<Message>> getMessages(String chatKey) async {
    final result = await _methodChannel.invokeMethod<List<dynamic>>(
      'getMessages',
      {'chatKey': chatKey},
    );
    return (result ?? [])
        .map((e) => Message.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  /// All recovered messages carrying media of one of [mediaTypes], across
  /// every chat -- optionally narrowed to a single [package]. Backs the
  /// Recover grid's per-media-type screens (Photo, Video, Voice Message,
  /// Files, Stickers & GIFs).
  static Future<List<RecoveredMedia>> getMediaMessages(
    List<String> mediaTypes, {
    String? package,
  }) async {
    final result = await _methodChannel.invokeMethod<List<dynamic>>(
      'getMediaMessages',
      {'mediaTypes': mediaTypes, 'package': package},
    );
    return (result ?? [])
        .map((e) => RecoveredMedia.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  /// Every message that's been edited or deleted, across every chat --
  /// optionally narrowed to a single [package]. Backs the Deleted tab's
  /// user-wise view.
  static Future<List<EditedDeletedMessage>> getEditedOrDeletedMessages({
    String? package,
  }) async {
    final result = await _methodChannel.invokeMethod<List<dynamic>>(
      'getEditedOrDeletedMessages',
      {'package': package},
    );
    return (result ?? [])
        .map((e) => EditedDeletedMessage.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  static Future<void> markChatOpened(String chatKey) {
    return _methodChannel.invokeMethod('markChatOpened', {'chatKey': chatKey});
  }

  static Future<void> clearAll() {
    return _methodChannel.invokeMethod('clearAll');
  }

  static Future<Set<String>> getMonitoredApps() async {
    final result = await _methodChannel.invokeMethod<List<dynamic>>(
      'getMonitoredApps',
    );
    return (result ?? []).map((e) => e as String).toSet();
  }

  static Future<void> setMonitoredApps(Set<String> apps) {
    return _methodChannel.invokeMethod('setMonitoredApps', {
      'apps': apps.toList(),
    });
  }

  static Future<bool> openFile(String path, {String? mime}) async {
    final result = await _methodChannel.invokeMethod<bool>('openFile', {
      'path': path,
      'mime': mime,
    });
    return result ?? false;
  }

  static Future<bool> hasStatusAccess(String package) async {
    final result = await _methodChannel.invokeMethod<bool>('hasStatusAccess', {
      'package': package,
    });
    return result ?? false;
  }

  static Future<bool> requestStatusAccess(String package) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'requestStatusAccess',
      {'package': package},
    );
    return result ?? false;
  }

  static Future<List<StatusItem>> listStatuses(String package) async {
    final result = await _methodChannel.invokeMethod<List<dynamic>>(
      'listStatuses',
      {'package': package},
    );
    return (result ?? [])
        .map((e) => StatusItem.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  static Future<String> statusFolderHint(String package) async {
    final result = await _methodChannel.invokeMethod<String>(
      'statusFolderHint',
      {'package': package},
    );
    return result ?? '';
  }

  static Future<bool> downloadMedia(
    String path, {
    required bool isVideo,
    String? mime,
  }) async {
    final result = await _methodChannel.invokeMethod<bool>('downloadMedia', {
      'path': path,
      'isVideo': isVideo,
      'mime': mime,
    });
    return result ?? false;
  }

  static Future<void> openBackgroundAppSettings() {
    return _methodChannel.invokeMethod('openBackgroundAppSettings');
  }

  static Future<bool> openApp(String package) async {
    final result = await _methodChannel.invokeMethod<bool>('openApp', {
      'package': package,
    });
    return result ?? false;
  }

  /// Whether the user has already granted access to [package]'s Media
  /// folder -- one grant covers every [listMediaFolder] kind.
  static Future<bool> hasMediaFolderAccess(String package) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'hasMediaFolderAccess',
      {'package': package},
    );
    return result ?? false;
  }

  static Future<bool> requestMediaFolderAccess(String package) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'requestMediaFolderAccess',
      {'package': package},
    );
    return result ?? false;
  }

  /// Files already recovered for [kind] ('photo', 'video', 'files', or
  /// 'stickersGifs') and [package] -- a fast local listing only, so it's
  /// safe to call for a screen's first paint. Call [syncMediaFolder]
  /// separately (and re-call this after) to actually scan for new files.
  static Future<List<MediaFolderItem>> listMediaFolder(
    String kind,
    String package,
  ) async {
    final result = await _methodChannel.invokeMethod<List<dynamic>>(
      'listMediaFolder',
      {'kind': kind, 'package': package},
    );
    return (result ?? [])
        .map((e) => MediaFolderItem.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  /// Scans WhatsApp's granted Media folder for new files matching [kind]
  /// and copies them in -- the slow half of media-folder recovery. Can take
  /// a while on a large folder or slow device, so callers should run this
  /// in the background rather than blocking a screen on it.
  static Future<void> syncMediaFolder(String kind, String package) {
    return _methodChannel.invokeMethod('syncMediaFolder', {
      'kind': kind,
      'package': package,
    });
  }

  static Future<String> mediaFolderHint(String package) async {
    final result = await _methodChannel.invokeMethod<String>(
      'mediaFolderHint',
      {'package': package},
    );
    return result ?? '';
  }
}
