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
     * What a cancelled notification's rows turned out to be.
     * [stillActive] maps each row that is still on screen to the key of the notification
     * showing it -- those were re-issued, not removed. [gone] is the rest. [deletion] is the
     * one message to record as deleted, if the cancel amounts to that.
     */
    data class RemovalDecision(
        val gone: List<RemovalResult>,
        val stillActive: Map<RemovalResult, String>,
        val deletion: RemovalResult?
    )

    /**
     * Turns the rows [MessageStore.markRemoved] swept up for a cancelled key into a decision.
     *
     * WhatsApp often re-posts a chat under the very same key, so a key can hold rows from two
     * moments: the notification that was cancelled, and messages that arrived after it. Only the
     * former count toward "how many messages did the cancelled notification hold" -- otherwise a
     * message deleted just before a new one arrives would look like one of two and never be
     * flagged. Whether a row was in the cancelled notification is judged by when we captured it,
     * not by its own send timestamp, which the sender's clock can skew.
     *
     * @param capturedAfterCancel true for a row we first saw after the cancel happened. An
     *   unknown capture time must answer false: counting a row that was in fact there keeps a
     *   lone-message deletion from being inferred out of several.
     * @param shownIn key of the active notification still showing the row's message, or null.
     */
    fun resolve(
        results: List<RemovalResult>,
        isAppCancel: Boolean,
        couldBeReadingOnThisPhone: Boolean,
        capturedAfterCancel: (RemovalResult) -> Boolean,
        shownIn: (RemovalResult) -> String?
    ): RemovalDecision {
        val shown = results.associateWith(shownIn)
        val stillActive = shown.mapNotNull { (row, key) -> key?.let { row to it } }.toMap()
        val gone = results.filter { shown[it] == null }

        val cancelled = results.filter { !it.alreadyDeleted && !capturedAfterCancel(it) }
        val lone = cancelled.singleOrNull()
        val deletion = lone?.takeIf {
            isLikelyDeletion(
                isAppCancel = isAppCancel,
                couldBeReadingOnThisPhone = couldBeReadingOnThisPhone,
                unreadMessagesInNotification = cancelled.size,
                stillShownInAnotherNotification = shown[it] != null
            )
        }
        return RemovalDecision(gone, stillActive, deletion)
    }

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
