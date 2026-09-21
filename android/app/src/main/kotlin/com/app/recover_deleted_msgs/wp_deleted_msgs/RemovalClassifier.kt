package com.app.recover_deleted_msgs.wp_deleted_msgs

/**
 * Decides whether WhatsApp cancelling a conversation notification means the message in it was
 * deleted by its sender.
 *
 * [MessageReconciler] can't see this case: it only runs when a notification is posted. When a
 * chat has several unread messages and one is deleted, WhatsApp re-posts the notification
 * without it, which the reconciler catches. When the deleted message is the only one, there's
 * nothing left to re-post, so WhatsApp just cancels the notification (`APP_CANCEL`), with no
 * placeholder text at all.
 *
 * The catch is that WhatsApp cancels with the very same reason when the message is READ --
 * opened from the launcher, or read on WhatsApp Web / another device -- so the reason alone
 * can't be trusted. Every condition below exists to keep a read message from being reported
 * as deleted, since mislabelling a message that still exists is worse than missing one.
 */
object RemovalClassifier {

    /**
     * @param isAppCancel the removal reason was the app cancelling its own notification.
     *   Swipe-dismiss and tap are the user's doing, never a deletion.
     * @param couldBeReadingOnThisPhone the screen was on and unlocked with this app NOT in the
     *   foreground -- i.e. WhatsApp itself might have been open. If the screen is off/locked, or
     *   this app is what's on screen, the user can't have been reading it in WhatsApp here.
     * @param unreadMessagesInNotification how many not-yet-removed messages the cancelled
     *   notification held. Only a lone message is treated as a deletion: cancelling several at
     *   once is overwhelmingly a read/clear, and one deletion among several arrives as a
     *   re-post instead.
     * @param stillShownInAnotherNotification the message is still visible in some active
     *   notification -- WhatsApp re-issued it under a new key, so nothing was deleted.
     */
    fun isLikelyDeletion(
        isAppCancel: Boolean,
        couldBeReadingOnThisPhone: Boolean,
        unreadMessagesInNotification: Int,
        stillShownInAnotherNotification: Boolean
    ): Boolean =
        isAppCancel &&
            !couldBeReadingOnThisPhone &&
            unreadMessagesInNotification == 1 &&
            !stillShownInAnotherNotification
}
