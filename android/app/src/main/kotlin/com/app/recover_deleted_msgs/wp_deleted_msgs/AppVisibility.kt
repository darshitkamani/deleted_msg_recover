package com.app.recover_deleted_msgs.wp_deleted_msgs

/**
 * Whether this app's own UI is on screen right now. [AlertNotifier] uses it to skip alerts the
 * user would see in the app anyway. Both live in the same process, so a plain flag is enough.
 */
object AppVisibility {
    @Volatile
    var isForeground: Boolean = false
}
