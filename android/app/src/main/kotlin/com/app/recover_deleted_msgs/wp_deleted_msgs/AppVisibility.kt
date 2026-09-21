package com.app.recover_deleted_msgs.wp_deleted_msgs

/**
 * Whether this app's own UI is on screen right now. [NotificationListener] uses it to tell
 * that the user can't be reading a message in WhatsApp at the same moment -- see
 * [RemovalClassifier]. Both live in the same process, so a plain flag is enough.
 */
object AppVisibility {
    @Volatile
    var isForeground: Boolean = false
}
