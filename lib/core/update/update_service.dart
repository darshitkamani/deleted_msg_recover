import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Thin wrapper around the Play Store In-App Updates API -- checks once per
/// process (mirrors AdsService's own idempotent-init pattern) and starts
/// whichever update flow Play allows and the release's own priority calls
/// for:
///  - immediate (a full-screen, blocking flow entirely handled by Play)
///    when the update is marked urgent in the Play Console and Play allows
///    it for this device/state, or
///  - flexible (silent background download; the app decides when to
///    prompt for restart) otherwise.
///
/// This is a Play Store-only API -- Android only, and only meaningful for
/// a build actually installed through Play. It must never affect app
/// startup: any failure (no Play Store, sideloaded/debug build, offline,
/// emulator without Play services, etc.) is swallowed silently.
class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  Future<void>? _checkFuture;

  /// The Play Console's own updatePriority field is a developer-set 0-5
  /// value per release; treated as urgent enough to block the user at this
  /// threshold and above, per Google's guidance for that field.
  static const _immediatePriorityThreshold = 4;

  /// Checks for an update and starts whichever flow fits. [onUpdateReady]
  /// is called (possibly much later, once the background download
  /// finishes) only for a *flexible* update -- an immediate update's UI is
  /// entirely handled by Play itself, so there's nothing for the caller to
  /// react to there.
  Future<void> checkForUpdate({required VoidCallback onUpdateReady}) {
    return _checkFuture ??= _check(onUpdateReady);
  }

  Future<void> _check(VoidCallback onUpdateReady) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      final urgent = info.updatePriority >= _immediatePriorityThreshold;
      if (urgent && info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      if (!info.flexibleUpdateAllowed) return;

      // Subscribed before starting the download, not after, so a fast
      // download can't finish (and fire InstallStatus.downloaded) before
      // anything is listening for it.
      InAppUpdate.installUpdateListener.listen((status) {
        if (status == InstallStatus.downloaded) onUpdateReady();
      });
      await InAppUpdate.startFlexibleUpdate();
    } catch (_) {
      // See class doc -- a failed update check must never affect the rest
      // of the app.
    }
  }

  /// Installs a flexible update that's already finished downloading (i.e.
  /// after [onUpdateReady] fired) -- restarts the app to apply it.
  Future<void> completeFlexibleUpdate() {
    return InAppUpdate.completeFlexibleUpdate();
  }
}
