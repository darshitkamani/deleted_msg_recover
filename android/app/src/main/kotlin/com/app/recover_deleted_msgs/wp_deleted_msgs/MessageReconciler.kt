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
    /** Unchanged. When it matched a stored row, [entry] carries that row's [WindowEntry.id]. */
    data class Noop(val entry: WindowEntry) : ReconcileAction()
}

/**
 * Reconciles the message window from a new notification against the window we stored from
 * the previous one, for a single chat.
 *
 * Matching is in two passes. First, entries that are exactly unchanged (timestamp, sender and
 * text) pair up in order. Only what's left can be an edit or a placeholder replacement, and
 * only against a stored entry with the same timestamp and sender lying between the exact
 * matches around it. WhatsApp's notification timestamps have one-second resolution, so a fast
 * burst puts several messages on the same second; matching on timestamp alone would pair a
 * message with a different one from that second once the oldest scrolls out of the window.
 * Likewise a burst of new same-second messages has nothing left to pair with and is
 * correctly treated as new rather than as edits of each other.
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
 *    surviving past it, that is indistinguishable from ordinary scrolling -- and from the
 *    user dismissing/reading the notification in WhatsApp, which also drops the oldest
 *    entries while the newer ones stay. It is never treated as a deletion: mislabelling a
 *    message that still exists as "deleted" is worse than missing the rare oldest-message
 *    deletion (a real deletion normally arrives as an in-place placeholder anyway).
 *  - If NOTHING in the incoming window matches anything stored at all, no deletions are
 *    inferred, period -- regardless of [priorTotalMessageCount]. WhatsApp's window holds
 *    unread messages, not "the last N ever": reading or clearing the notification (in
 *    WhatsApp itself, not this app) resets the next one to just the new arrivals, which
 *    looks identical to "every previous message vanished." Without at least one shared
 *    message anchoring the two windows together, there is no way to tell a real mass
 *    deletion apart from an ordinary read/clear, so we don't guess.
 *  - The one case this cannot resolve even with overlap: the oldest message of the window
 *    being deleted looks identical to it simply scrolling out, because there's nothing older
 *    to compare against. That's an information limit of window-sniffing, not a bug.
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

    /**
     * @param previousShown what this same notification showed on its previous post (timestamp to
     *   text), or null if unknown. Lets a vanished OLDEST message be told apart from a scroll-out:
     *   a message only scrolls out when a new one pushes it, so if it was in the previous post
     *   and this re-post adds nothing new, it was deleted.
     */
    fun reconcile(
        stored: List<WindowEntry>,
        incoming: List<WindowEntry>,
        previousShown: List<Pair<Long, String>>? = null
    ): List<ReconcileAction> {
        val consumed = BooleanArray(stored.size)
        val matchOf = IntArray(incoming.size) { -1 }

        // Pass 1: messages that are still exactly the same (timestamp, sender AND text), in
        // order. WhatsApp's timestamps only have one-second resolution, so a fast burst puts
        // several messages on the same second; pairing by timestamp first would match a message
        // against a *different* one from that second as soon as the oldest scrolls out of the
        // window -- reporting an edit that never happened and a deletion of the real one.
        var ptr = 0
        for ((i, entry) in incoming.withIndex()) {
            val m = (ptr until stored.size).firstOrNull { j ->
                !consumed[j] && stored[j].timestamp == entry.timestamp &&
                    stored[j].sender == entry.sender && stored[j].text == entry.text
            } ?: continue
            consumed[m] = true
            matchOf[i] = m
            ptr = m + 1
        }

        // Pass 2: what's left is new, edited, or replaced by a deletion placeholder. A changed
        // message can only sit between the exact matches around it (the "gap"); within a gap,
        // stored and incoming entries with the same timestamp and sender pair up in order --
        // but only when there are as many of each. Otherwise it's ambiguous which stored
        // message changed (e.g. one scrolled out AND one was edited in the same second), and
        // guessing wrong reports a false edit plus a false deletion, so nothing is paired and
        // the incoming ones are treated as new.
        val unmatched = incoming.indices.filter { matchOf[it] == -1 }
        val gaps = unmatched.groupBy { i ->
            val lower = (i - 1 downTo 0).firstOrNull { matchOf[it] != -1 }?.let { matchOf[it] + 1 } ?: 0
            val upper = (i + 1 until incoming.size).firstOrNull { matchOf[it] != -1 }?.let { matchOf[it] } ?: stored.size
            lower to upper
        }
        for ((bounds, indices) in gaps) {
            val (lower, upper) = bounds
            val gapStored = (lower until upper).filter { !consumed[it] }
            for ((_, group) in indices.groupBy { incoming[it].timestamp to incoming[it].sender }) {
                val first = incoming[group.first()]
                val candidates = gapStored.filter {
                    !consumed[it] && stored[it].timestamp == first.timestamp && stored[it].sender == first.sender
                }
                if (candidates.isEmpty() || candidates.size != group.size) continue
                for ((k, i) in group.withIndex()) {
                    consumed[candidates[k]] = true
                    matchOf[i] = candidates[k]
                }
            }
            // A deletion placeholder's Person can come through without a name (or a different
            // one) than the original message had, so requiring the sender to agree would make
            // it miss the very message it replaces. Fall back to the timestamp alone, but only
            // when exactly one stored message could be meant -- that keeps the group-chat
            // protection (sender must agree) from being thrown away.
            for (i in indices) {
                if (matchOf[i] != -1 || !isDeletionPlaceholder(incoming[i].text)) continue
                val candidates = gapStored.filter { !consumed[it] && stored[it].timestamp == incoming[i].timestamp }
                if (candidates.size != 1) continue
                consumed[candidates[0]] = true
                matchOf[i] = candidates[0]
            }
        }

        val actions = mutableListOf<ReconcileAction>()
        for ((i, newEntry) in incoming.withIndex()) {
            val m = matchOf[i]
            if (m == -1) {
                // A placeholder that matches nothing is never a real message: recording it
                // would put "This message was deleted" in the chat as if someone had typed it.
                // The message it replaced is simply left unconsumed, so the gap check below
                // still flags that one as deleted when there's overlap to anchor on.
                actions += if (isDeletionPlaceholder(newEntry.text)) ReconcileAction.Noop(newEntry)
                else ReconcileAction.Insert(newEntry)
                continue
            }
            val previous = stored[m]
            actions += when {
                previous.text == newEntry.text -> ReconcileAction.Noop(newEntry.copy(id = previous.id))
                isDeletionPlaceholder(newEntry.text) -> ReconcileAction.DeletedWithPlaceholder(previous, newEntry)
                else -> ReconcileAction.Edit(previous, newEntry)
            }
        }

        val nothingNew = actions.none { it is ReconcileAction.Insert }
        val leadingDeletable = { e: WindowEntry ->
            nothingNew && previousShown != null &&
                previousShown.any { it.first == e.timestamp && it.second == e.text }
        }
        actions += silentlyDeletedActions(stored, consumed, leadingDeletable)

        return actions
    }

    private fun silentlyDeletedActions(
        stored: List<WindowEntry>,
        consumed: BooleanArray,
        leadingDeletable: (WindowEntry) -> Boolean
    ): List<ReconcileAction.DeletedSilently> {
        if (!consumed.any { it }) {
            // Zero overlap with the previous window -- almost certainly a read/clear reset
            // of the notification, not every stored message being deleted at once. See the
            // class doc. Infer nothing rather than mislabel an entire chat's history.
            return emptyList()
        }

        val firstConsumedIndex = consumed.indexOfFirst { it }

        val result = mutableListOf<ReconcileAction.DeletedSilently>()
        for (i in stored.indices) {
            if (consumed[i]) continue
            // Leading edge: normally scroll-out/dismissal, not a deletion -- unless it was in the
            // previous post and nothing new arrived that could have pushed it out.
            if (i < firstConsumedIndex && !leadingDeletable(stored[i])) continue
            result += ReconcileAction.DeletedSilently(stored[i])
        }
        return result
    }

    /**
     * Compared after stripping everything that isn't a letter, digit or space, so a leading
     * emoji ("🚫 This message was deleted") or trailing punctuation doesn't stop it matching.
     */
    fun isDeletionPlaceholder(text: String): Boolean {
        val normalized = text.lowercase()
            .filter { it.isLetterOrDigit() || it.isWhitespace() }
            .trim()
            .replace(Regex("\\s+"), " ")
        return normalized in DELETION_PLACEHOLDERS
    }
}
