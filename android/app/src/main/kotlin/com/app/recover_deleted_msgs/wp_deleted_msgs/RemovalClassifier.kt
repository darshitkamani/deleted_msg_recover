package com.app.recover_deleted_msgs.wp_deleted_msgs

/**
 * Sorts the messages of a removed WhatsApp notification into those still on screen and those
 * that are gone, and picks out a possible deletion ([loneDeletion]). Otherwise "gone" only
 * means "no longer shown in a notification" -- see NotificationListener.onNotificationRemoved.
 */
object RemovalClassifier {

    /**
     * [stillActive] maps each row that is still on screen to the key of the notification
     * showing it -- those were re-issued, not removed. [gone] is the rest.
     */
    data class RemovalDecision(
        val gone: List<RemovalResult>,
        val stillActive: Map<RemovalResult, String>
    )

    /**
     * @param results the rows [MessageStore.markRemoved] swept up for the removed key.
     * @param shownIn key of the active notification still showing the row's message, or null.
     */
    fun resolve(
        results: List<RemovalResult>,
        shownIn: (RemovalResult) -> String?
    ): RemovalDecision {
        val shown = results.associateWith(shownIn)
        val stillActive = shown.mapNotNull { (row, key) -> key?.let { row to it } }.toMap()
        val gone = results.filter { shown[it] == null }
        return RemovalDecision(gone, stillActive)
    }

    /**
     * The message a removal possibly deleted, or null. Only called for a removal by WhatsApp while
     * the user couldn't be reading it. Only a notification that showed exactly one message
     * qualifies: with several, deleting one is a re-post without it (MessageReconciler's job), so
     * their all going at once is a read or clear. The row must be that message, gone from every
     * notification, and not already recorded as deleted.
     *
     * @param gone rows no longer shown anywhere (see [resolve]).
     * @param showed what the removed notification showed at its last post (timestamp to text).
     */
    fun loneDeletion(gone: List<RemovalResult>, showed: List<Pair<Long, String>>): RemovalResult? {
        val (timestamp, text) = showed.singleOrNull() ?: return null
        if (MessageReconciler.isDeletionPlaceholder(text)) return null
        return gone.firstOrNull { it.timestamp == timestamp && it.text == text && !it.alreadyDeleted }
    }
}
