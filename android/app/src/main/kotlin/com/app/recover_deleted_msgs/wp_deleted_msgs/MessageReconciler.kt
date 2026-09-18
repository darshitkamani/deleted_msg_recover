package com.app.recover_deleted_msgs.wp_deleted_msgs

/**
 * One message as it appears in a WhatsApp notification's messaging-style window.
 *
 * [id] is opaque to the reconciler -- matching is purely by timestamp/sender/text, [id] is
 * never read or compared. It exists so a caller building [stored] from its own database can
 * carry the row id through untouched and read it back off the resulting action, to know
 * exactly which row to mutate even when two entries share a timestamp.
 */
data class WindowEntry(
    val timestamp: Long,
    val text: String,
    val sender: String? = null,
    val id: Long? = null
)

sealed class ReconcileAction {
    data class Insert(val entry: WindowEntry) : ReconcileAction()
    data class Edit(val previous: WindowEntry, val updated: WindowEntry) : ReconcileAction()
    /** WhatsApp replaced the message with its "this message was deleted" placeholder, in place. */
    data class DeletedWithPlaceholder(val previous: WindowEntry, val placeholder: WindowEntry) : ReconcileAction()
    /** The message vanished from the window entirely, with no placeholder -- see [MessageReconciler.reconcile]. */
    data class DeletedSilently(val previous: WindowEntry) : ReconcileAction()
    data class Noop(val entry: WindowEntry) : ReconcileAction()
}

/**
 * Reconciles the message window from a new notification against the window we stored from
 * the previous one, for a single chat.
 *
 * Matching is by timestamp *and* sender, but resolved by ordered consumption rather than a
 * plain key lookup: each incoming entry can only match the first not-yet-consumed stored
 * entry with the same timestamp and sender, scanning forward from where the previous match
 * left off. This is what keeps a burst of messages sharing a timestamp from being misread as
 * edits of each other -- the first same-timestamp message matches the first stored one, the
 * second has nothing left to match and is correctly treated as new.
 *
 * Requiring [WindowEntry.sender] to also agree matters for group chats: several members can
 * post around the same timestamp (WhatsApp's notification timestamps aren't fine-grained
 * enough to rule this out), and without a sender check one member's still-intact message
 * could be matched against a different member's incoming "this message was deleted"
 * placeholder purely because both carry the same timestamp -- flagging the wrong person's
 * message as deleted while the real deletion goes unnoticed. A `null` sender only matches
 * another `null` sender (the 1:1-chat case, where sender isn't tracked at all).
 *
 * A stored entry with no corresponding incoming entry is either a deletion or an ordinary
 * scroll-out (WhatsApp's window is a FIFO capped at [windowCap] slots, so it can only ever
 * evict from the front). We tell them apart using the same consumed/unconsumed record built
 * while matching:
 *  - If an OLDER stored entry was matched (consumed) while this one was not, that is
 *    impossible under FIFO eviction -- the older one should have been evicted first, not
 *    this one -- so this one was deleted. This case is unambiguous regardless of history.
 *  - If this entry is part of the unbroken leading (oldest) run with nothing older ever
 *    surviving past it, that alone is also consistent with ordinary scrolling. It is only
 *    treated as a deletion when [priorTotalMessageCount] shows the window had not yet
 *    reached [windowCap] -- i.e. there was no capacity reason for anything to fall off.
 *  - If NOTHING in the incoming window matches anything stored at all, no deletions are
 *    inferred, period -- regardless of [priorTotalMessageCount]. WhatsApp's window holds
 *    unread messages, not "the last N ever": reading or clearing the notification (in
 *    WhatsApp itself, not this app) resets the next one to just the new arrivals, which
 *    looks identical to "every previous message vanished." Without at least one shared
 *    message anchoring the two windows together, there is no way to tell a real mass
 *    deletion apart from an ordinary read/clear, so we don't guess.
 *  - The one case this cannot resolve even with overlap: the oldest message of an
 *    already-full window being deleted looks identical to it simply scrolling out, because
 *    there's nothing older to compare against. That's an information limit of
 *    window-sniffing, not a bug.
 *
 * Contract callers can rely on: the first `incoming.size` entries of the returned list are
 * in the same order as [incoming] -- exactly one action per incoming entry, so `actions[i]`
 * always corresponds to `incoming[i]`. Any [ReconcileAction.DeletedSilently] entries are
 * appended after that, in [stored] order.
 */
object MessageReconciler {

    const val DEFAULT_WINDOW_CAP = 7

    private val DELETION_PLACEHOLDERS = setOf(
        "this message was deleted",
        "you deleted this message"
    )

    fun reconcile(
        stored: List<WindowEntry>,
        incoming: List<WindowEntry>,
        priorTotalMessageCount: Int = Int.MAX_VALUE,
        windowCap: Int = DEFAULT_WINDOW_CAP
    ): List<ReconcileAction> {
        val consumed = BooleanArray(stored.size)
        val actions = mutableListOf<ReconcileAction>()
        var storedPtr = 0

        for (newEntry in incoming) {
            val matchIndex =
                findFirstUnconsumedMatch(stored, consumed, storedPtr, newEntry.timestamp, newEntry.sender)

            if (matchIndex == -1) {
                actions += ReconcileAction.Insert(newEntry)
                continue
            }

            consumed[matchIndex] = true
            storedPtr = matchIndex + 1
            val previous = stored[matchIndex]

            actions += when {
                previous.text == newEntry.text -> ReconcileAction.Noop(newEntry)
                isDeletionPlaceholder(newEntry.text) -> ReconcileAction.DeletedWithPlaceholder(previous, newEntry)
                else -> ReconcileAction.Edit(previous, newEntry)
            }
        }

        actions += silentlyDeletedActions(stored, consumed, priorTotalMessageCount, windowCap)

        return actions
    }

    private fun silentlyDeletedActions(
        stored: List<WindowEntry>,
        consumed: BooleanArray,
        priorTotalMessageCount: Int,
        windowCap: Int
    ): List<ReconcileAction.DeletedSilently> {
        if (!consumed.any { it }) {
            // Zero overlap with the previous window -- almost certainly a read/clear reset
            // of the notification, not every stored message being deleted at once. See the
            // class doc. Infer nothing rather than mislabel an entire chat's history.
            return emptyList()
        }

        val firstConsumedIndex = consumed.indexOfFirst { it }.let { if (it == -1) stored.size else it }
        val windowWasFull = priorTotalMessageCount >= windowCap

        val result = mutableListOf<ReconcileAction.DeletedSilently>()
        for (i in stored.indices) {
            if (consumed[i]) continue
            val isUnbrokenLeadingEdge = i < firstConsumedIndex
            if (isUnbrokenLeadingEdge && windowWasFull) continue // ordinary scroll-out, not a deletion
            result += ReconcileAction.DeletedSilently(stored[i])
        }
        return result
    }

    private fun findFirstUnconsumedMatch(
        stored: List<WindowEntry>,
        consumed: BooleanArray,
        fromIndex: Int,
        timestamp: Long,
        sender: String?
    ): Int {
        for (i in fromIndex until stored.size) {
            if (!consumed[i] && stored[i].timestamp == timestamp && stored[i].sender == sender) return i
        }
        return -1
    }

    private fun isDeletionPlaceholder(text: String): Boolean =
        text.trim().lowercase() in DELETION_PLACEHOLDERS
}
