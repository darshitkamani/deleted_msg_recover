package com.app.recover_deleted_msgs.wp_deleted_msgs

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MessageReconcilerTest {

    @Test
    fun `new message into empty window is an insert`() {
        val actions = MessageReconciler.reconcile(
            stored = emptyList(),
            incoming = listOf(WindowEntry(1000, "hey"))
        )

        assertEquals(1, actions.size)
        assertTrue(actions[0] is ReconcileAction.Insert)
    }

    @Test
    fun `unchanged message is a noop`() {
        val entry = WindowEntry(1000, "hey")
        val actions = MessageReconciler.reconcile(
            stored = listOf(entry),
            incoming = listOf(entry)
        )

        assertEquals(1, actions.size)
        assertTrue(actions[0] is ReconcileAction.Noop)
    }

    @Test
    fun `same timestamp different text is an edit`() {
        val actions = MessageReconciler.reconcile(
            stored = listOf(WindowEntry(1000, "Duhr")),
            incoming = listOf(WindowEntry(1000, "Duhr0000"))
        )

        assertEquals(1, actions.size)
        val edit = actions[0] as ReconcileAction.Edit
        assertEquals("Duhr", edit.previous.text)
        assertEquals("Duhr0000", edit.updated.text)
    }

    @Test
    fun `deletion placeholder at same timestamp is a delete, not an edit`() {
        val actions = MessageReconciler.reconcile(
            stored = listOf(WindowEntry(1000, "see you at 5")),
            incoming = listOf(WindowEntry(1000, "This message was deleted"))
        )

        assertEquals(1, actions.size)
        val delete = actions[0] as ReconcileAction.DeletedWithPlaceholder
        assertEquals("see you at 5", delete.previous.text)
    }

    @Test
    fun `message vanishing from the middle of the window is a silent delete`() {
        // msg 3 and msg 5 are gone with no placeholder; msg 2, 4, 6, 7 remain matched --
        // an older entry (2) surviving past a missing one (3) is impossible under FIFO
        // eviction, so it must have been deleted, not scrolled out.
        val actions = MessageReconciler.reconcile(
            stored = listOf(
                WindowEntry(1000, "one"),
                WindowEntry(2000, "two"),
                WindowEntry(3000, "three"),
                WindowEntry(4000, "four"),
                WindowEntry(5000, "five"),
                WindowEntry(6000, "six"),
                WindowEntry(7000, "seven")
            ),
            incoming = listOf(
                WindowEntry(1000, "one"),
                WindowEntry(2000, "two"),
                WindowEntry(4000, "four"),
                WindowEntry(6000, "six"),
                WindowEntry(7000, "seven")
            )
        )

        val silentDeletes = actions.filterIsInstance<ReconcileAction.DeletedSilently>()
        assertEquals(2, silentDeletes.size)
        assertEquals(setOf("three", "five"), silentDeletes.map { it.previous.text }.toSet())
    }

    @Test
    fun `oldest message falling off a full window is scroll-out, not a delete`() {
        val actions = MessageReconciler.reconcile(
            stored = (1..7).map { WindowEntry(it * 1000L, "msg$it") },
            incoming = (2..8).map { WindowEntry(it * 1000L, "msg$it") }
        )

        assertTrue(actions.none { it is ReconcileAction.DeletedSilently })
        val insert = actions.filterIsInstance<ReconcileAction.Insert>().single()
        assertEquals("msg8", insert.entry.text)
    }

    @Test
    fun `leading message missing from a short chat is not a delete`() {
        // The user dismissed/read the notification after msg 1, so the next window starts at
        // msg 2 -- indistinguishable from msg 1 being deleted, and mislabelling a message that
        // still exists as "deleted" is the worse mistake, so nothing is inferred.
        val actions = MessageReconciler.reconcile(
            stored = listOf(
                WindowEntry(1000, "one"),
                WindowEntry(2000, "two"),
                WindowEntry(3000, "three")
            ),
            incoming = listOf(
                WindowEntry(2000, "two"),
                WindowEntry(3000, "three"),
                WindowEntry(4000, "four")
            )
        )

        assertTrue(actions.none { it is ReconcileAction.DeletedSilently })
    }

    @Test
    fun `notification read-clear reset with zero overlap infers no deletions`() {
        // The user read/cleared WhatsApp's notification for this chat (in WhatsApp itself).
        // The next notification's window resets to just the new unread message -- none of
        // the previously stored messages appear at all, even though none of them were
        // actually deleted.
        val actions = MessageReconciler.reconcile(
            stored = (1..7).map { WindowEntry(it * 1000L, "msg$it") },
            incoming = listOf(WindowEntry(9000L, "brand new message"))
        )

        assertTrue(actions.none { it is ReconcileAction.DeletedSilently })
        val insert = actions.filterIsInstance<ReconcileAction.Insert>().single()
        assertEquals("brand new message", insert.entry.text)
    }

    @Test
    fun `zero overlap infers no deletions even when the chat never filled the window`() {
        // Same read-clear reset, but for a short chat that never reached the window cap.
        val actions = MessageReconciler.reconcile(
            stored = listOf(WindowEntry(1000, "one"), WindowEntry(2000, "two")),
            incoming = listOf(WindowEntry(5000, "three"))
        )

        assertTrue(actions.none { it is ReconcileAction.DeletedSilently })
    }

    @Test
    fun `scroll-out and a mid-window delete can be detected together`() {
        val actions = MessageReconciler.reconcile(
            stored = (1..7).map { WindowEntry(it * 1000L, "msg$it") },
            // msg1 scrolls out normally, msg3 is deleted, msg8 is new
            incoming = listOf(2, 4, 5, 6, 7, 8).map { WindowEntry(it * 1000L, "msg$it") }
        )

        val silentDeletes = actions.filterIsInstance<ReconcileAction.DeletedSilently>()
        assertEquals(1, silentDeletes.size)
        assertEquals("msg3", silentDeletes[0].previous.text)
        assertTrue(actions.filterIsInstance<ReconcileAction.Insert>().any { it.entry.text == "msg8" })
    }

    @Test
    fun `burst of two messages sharing a timestamp is not read as an edit`() {
        // stored window already has t2="omw" from a previous notification.
        // A fast second message arrives with the SAME timestamp resolution as t2.
        val actions = MessageReconciler.reconcile(
            stored = listOf(
                WindowEntry(1000, "hey"),
                WindowEntry(2000, "omw")
            ),
            incoming = listOf(
                WindowEntry(1000, "hey"),
                WindowEntry(2000, "omw"),
                WindowEntry(2000, "be there in 5")
            )
        )

        assertEquals(3, actions.size)
        assertTrue(actions[0] is ReconcileAction.Noop)
        assertTrue(actions[1] is ReconcileAction.Noop)
        // second t2 has nothing left to match against -> insert, never an edit
        val insert = actions[2] as ReconcileAction.Insert
        assertEquals("be there in 5", insert.entry.text)
    }

    @Test
    fun `two genuinely distinct same-timestamp messages both match in order when unchanged`() {
        val actions = MessageReconciler.reconcile(
            stored = listOf(
                WindowEntry(2000, "one"),
                WindowEntry(2000, "two")
            ),
            incoming = listOf(
                WindowEntry(2000, "one"),
                WindowEntry(2000, "two")
            )
        )

        assertEquals(2, actions.size)
        assertTrue(actions[0] is ReconcileAction.Noop)
        assertTrue(actions[1] is ReconcileAction.Noop)
        assertEquals("one", (actions[0] as ReconcileAction.Noop).entry.text)
        assertEquals("two", (actions[1] as ReconcileAction.Noop).entry.text)
    }

    @Test
    fun `entry that scrolled out of the window produces no action`() {
        // stored had 3 messages, window cap means the oldest fell off in the new notification.
        val actions = MessageReconciler.reconcile(
            stored = listOf(
                WindowEntry(1000, "hey"),
                WindowEntry(2000, "omw"),
                WindowEntry(3000, "here")
            ),
            incoming = listOf(
                WindowEntry(2000, "omw"),
                WindowEntry(3000, "here"),
                WindowEntry(4000, "at the door")
            )
        )

        assertEquals(3, actions.size)
        assertTrue(actions[0] is ReconcileAction.Noop)
        assertTrue(actions[1] is ReconcileAction.Noop)
        assertTrue(actions[2] is ReconcileAction.Insert)
    }

    @Test
    fun `group chat- same-timestamp placeholder from one sender does not delete another sender's message`() {
        // Two different group members post at the same notification timestamp. Sender B's
        // message then gets genuinely deleted (replaced with the placeholder) -- sender A's
        // still-intact message at the same timestamp must not be the one flagged as deleted.
        val actions = MessageReconciler.reconcile(
            stored = listOf(
                WindowEntry(1000, "koi google ads expert hai kia", sender = "Bmonetizeads.in"),
                WindowEntry(1000, "hi there", sender = "MD Ziarul Haque")
            ),
            incoming = listOf(
                WindowEntry(1000, "koi google ads expert hai kia", sender = "Bmonetizeads.in"),
                WindowEntry(1000, "This message was deleted", sender = "MD Ziarul Haque")
            )
        )

        assertEquals(2, actions.size)
        assertTrue(actions[0] is ReconcileAction.Noop)
        assertEquals("koi google ads expert hai kia", (actions[0] as ReconcileAction.Noop).entry.text)

        val delete = actions[1] as ReconcileAction.DeletedWithPlaceholder
        assertEquals("MD Ziarul Haque", delete.previous.sender)
        assertEquals("hi there", delete.previous.text)
    }

    @Test
    fun `multiple edits in the same window are each detected independently`() {
        val actions = MessageReconciler.reconcile(
            stored = listOf(
                WindowEntry(1000, "Duhr"),
                WindowEntry(2000, "Urur"),
                WindowEntry(3000, "Rurur")
            ),
            incoming = listOf(
                WindowEntry(1000, "Duhr0000"),
                WindowEntry(2000, "Urur hhh"),
                WindowEntry(3000, "Rurur")
            )
        )

        assertEquals(3, actions.size)
        assertTrue(actions[0] is ReconcileAction.Edit)
        assertTrue(actions[1] is ReconcileAction.Edit)
        assertTrue(actions[2] is ReconcileAction.Noop)
    }

    @Test
    fun `noop carries the stored row id so the caller can refresh that row`() {
        val actions = MessageReconciler.reconcile(
            stored = listOf(WindowEntry(1000, "hey", sender = "Alice", id = 7)),
            incoming = listOf(WindowEntry(1000, "hey", sender = "Alice"))
        )

        assertEquals(7L, (actions[0] as ReconcileAction.Noop).entry.id)
    }

    @Test
    fun `scroll-out within a same-second burst is not an edit or a delete (Pixel log 10-07 10_46)`() {
        val s = "Bhavdip"
        fun e(ts: Long, text: String, id: Long? = null) = WindowEntry(ts, text, s, id)
        val stored = listOf(
            e(202, "Dbd", 1), e(202, "Dhd", 2), e(204, "Dbdd d", 3), e(204, "Dbd", 4),
            e(205, "Bd", 5), e(205, "Dbd", 6), e(206, "Fbd", 7)
        )
        val incoming = listOf(
            e(202, "Dhd"), e(204, "Dbdd d"), e(204, "Dbd"), e(205, "Bd"),
            e(205, "Dbd"), e(206, "Fbd"), e(206, "Bd")
        )

        val actions = MessageReconciler.reconcile(stored, incoming)

        assertEquals(7, actions.size) // no DeletedSilently appended
        assertTrue(actions.take(6).all { it is ReconcileAction.Noop })
        assertEquals(listOf(2L, 3L, 4L, 5L, 6L, 7L), actions.take(6).map { (it as ReconcileAction.Noop).entry.id })
        assertTrue(actions[6] is ReconcileAction.Insert)
    }

    @Test
    fun `two edits in the same second pair up in order`() {
        val actions = MessageReconciler.reconcile(
            stored = listOf(WindowEntry(1, "a"), WindowEntry(1, "b"), WindowEntry(2, "c")),
            incoming = listOf(WindowEntry(1, "a2"), WindowEntry(1, "b2"), WindowEntry(2, "c"))
        )

        assertEquals(3, actions.size)
        assertEquals("a", (actions[0] as ReconcileAction.Edit).previous.text)
        assertEquals("b", (actions[1] as ReconcileAction.Edit).previous.text)
    }

    @Test
    fun `scroll-out plus an edit in the same second is ambiguous - no false edit, no delete`() {
        // "x" scrolled out and "a" was edited to "a2", both on second 1: can't tell which of the
        // two stored messages "a2" replaced, so nothing is paired and nothing is deleted.
        val actions = MessageReconciler.reconcile(
            stored = listOf(WindowEntry(1, "x"), WindowEntry(1, "a"), WindowEntry(2, "c")),
            incoming = listOf(WindowEntry(1, "a2"), WindowEntry(2, "c"))
        )

        assertEquals(2, actions.size)
        assertTrue(actions[0] is ReconcileAction.Insert)
        assertTrue(actions[1] is ReconcileAction.Noop)
    }

    @Test
    fun `placeholder in a same-second burst replaces the right message`() {
        val actions = MessageReconciler.reconcile(
            stored = listOf(WindowEntry(1, "a"), WindowEntry(1, "b"), WindowEntry(1, "c")),
            incoming = listOf(WindowEntry(1, "a"), WindowEntry(1, "This message was deleted"), WindowEntry(1, "c"))
        )

        assertEquals(3, actions.size)
        assertEquals("b", (actions[1] as ReconcileAction.DeletedWithPlaceholder).previous.text)
    }

    @Test
    fun `oldest message vanishing from a re-post that adds nothing new is a delete (Pixel log 11_20)`() {
        val heiil = WindowEntry(224, "Heiil", id = 1)
        val hello = WindowEntry(228, "Hello", id = 2)
        val actions = MessageReconciler.reconcile(
            stored = listOf(heiil, hello),
            incoming = listOf(WindowEntry(228, "Hello")),
            previousShown = listOf(224L to "Heiil", 228L to "Hello")
        )

        assertEquals(2, actions.size)
        assertEquals("Heiil", (actions[1] as ReconcileAction.DeletedSilently).previous.text)
    }

    @Test
    fun `oldest message pushed out by a new one is still scroll-out`() {
        val actions = MessageReconciler.reconcile(
            stored = listOf(WindowEntry(1, "a"), WindowEntry(2, "b")),
            incoming = listOf(WindowEntry(2, "b"), WindowEntry(3, "c")),
            previousShown = listOf(1L to "a", 2L to "b")
        )

        assertTrue(actions.none { it is ReconcileAction.DeletedSilently })
    }

    @Test
    fun `older read message not in the previous post is never a delete`() {
        // "old" was read earlier (not in the notification's previous post), so its absence
        // says nothing.
        val actions = MessageReconciler.reconcile(
            stored = listOf(WindowEntry(1, "old"), WindowEntry(5, "x")),
            incoming = listOf(WindowEntry(5, "x")),
            previousShown = listOf(5L to "x")
        )

        assertTrue(actions.none { it is ReconcileAction.DeletedSilently })
    }
}
