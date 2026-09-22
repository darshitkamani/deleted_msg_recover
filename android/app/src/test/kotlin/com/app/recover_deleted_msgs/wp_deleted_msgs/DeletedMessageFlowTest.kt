package com.app.recover_deleted_msgs.wp_deleted_msgs

import android.service.notification.NotificationListenerService.REASON_APP_CANCEL
import android.service.notification.NotificationListenerService.REASON_CANCEL
import android.service.notification.NotificationListenerService.REASON_CLICK
import com.app.recover_deleted_msgs.wp_deleted_msgs.NotificationFlowHarness.Msg
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * End-to-end scenarios through the real NotificationListener and real SQLite: what a user with
 * this app installed would actually see happen to their recovered messages.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], shadows = [ShadowActiveNotifications::class])
class DeletedMessageFlowTest {

    private lateinit var h: NotificationFlowHarness

    private val a = Msg("A: hello", 1000)
    private val b = Msg("B: how are you", 2000)
    private val c = Msg("C: call me", 3000)

    @Before
    fun setUp() {
        NotificationFlowHarness.resetStore()
        h = NotificationFlowHarness()
    }

    @After
    fun tearDown() = NotificationFlowHarness.resetStore()

    private fun assertDeleted(vararg msgs: Msg) {
        val deleted = h.messages().filter { it.isDeleted }.map { it.text }.toSet()
        assertEquals(msgs.map { it.text }.toSet(), deleted)
    }

    // ---------------------------------------------------------------- deletions that must be caught

    @Test
    fun `lone message deleted by its sender is recovered`() {
        val key = h.post(1, listOf(a))
        h.cancel(key)
        h.advance(4500)

        assertDeleted(a)
        val ev = h.eventsOfType("deleted").single()
        assertEquals("A: hello", ev["recoveredText"])
    }

    @Test
    fun `newest of two messages deleted (silently re-posted without it) is recovered`() {
        h.post(1, listOf(a, b))
        h.post(1, listOf(a))
        h.advance(4500)

        assertDeleted(b)
        assertNull(h.message(a.text).removedAt)
    }

    @Test
    fun `middle of three messages deleted is recovered`() {
        h.post(1, listOf(a, b, c))
        h.post(1, listOf(a, c))
        h.advance(4500)

        assertDeleted(b)
    }

    @Test
    fun `message replaced by a deleted placeholder is recovered and the placeholder is not stored`() {
        h.post(1, listOf(a, b))
        h.post(1, listOf(a, Msg("This message was deleted", b.timestamp)))
        h.advance(4500)

        assertDeleted(b)
        assertTrue(h.messages().none { it.text.contains("was deleted", ignoreCase = true) })
    }

    @Test
    fun `lone message deleted and a new one arriving under the same key within 4s`() {
        val key = h.post(1, listOf(a))
        h.cancel(key)
        h.advance(1000)
        h.post(1, listOf(b))
        h.advance(4500)

        assertDeleted(a)
        assertNull(h.message(b.text).removedAt)
        assertEquals("only the real deletion is announced", 1, h.eventsOfType("deleted").size)
    }

    @Test
    fun `lone message deleted and a new one arriving under a different key within 4s`() {
        val key = h.post(1, listOf(a))
        h.cancel(key)
        h.advance(1000)
        h.post(2, listOf(b))
        h.advance(4500)

        assertDeleted(a)
        assertNull(h.message(b.text).removedAt)
    }

    @Test
    fun `deleting one chat's lone message leaves another chat alone`() {
        val alice = h.post(1, listOf(a), chat = "Alice")
        h.post(2, listOf(Msg("Bob: hi", 1500)), chat = "Bob")
        h.cancel(alice)
        h.advance(4500)

        assertDeleted(a)
    }

    @Test
    fun `message re-notified then really deleted is still caught`() {
        // The regression a naive "ignore cancels when the key is live again" fix would cause:
        // the re-notify must not leave the row flagged removed, or the real cancel finds nothing.
        val key = h.post(1, listOf(a))
        h.cancel(key)
        h.post(1, listOf(a))
        h.advance(4500)
        assertDeleted()
        assertNull(h.message(a.text).removedAt)

        h.cancel(key)
        h.advance(4500)
        assertDeleted(a)
    }

    @Test
    fun `message re-issued under a new key then really deleted is still caught`() {
        val first = h.post(1, listOf(a))
        h.cancel(first)
        val second = h.post(2, listOf(a))
        h.advance(4500)
        assertDeleted()

        h.cancel(second)
        h.advance(4500)
        assertDeleted(a)
    }

    @Test
    fun `messages that re-appear long after their notification was cancelled can still be caught when deleted`() {
        // Cancelled and settled (both flagged removed), then WhatsApp shows them again under a
        // new key. Seeing them again must re-attach them to the live notification, or a later
        // deletion cancels a key that none of their rows carry.
        val first = h.post(1, listOf(a, b))
        h.cancel(first)
        h.advance(10_000)
        assertDeleted()

        h.post(2, listOf(a, b))
        h.advance(10_000)
        assertTrue("re-shown messages are live again", h.messages().all { it.removedAt == null })

        h.post(2, listOf(a)) // b is deleted by its sender
        h.advance(4500)
        assertDeleted(b)

        val key = h.post(2, listOf(a))
        h.cancel(key) // and then a is deleted too, leaving nothing to re-post
        h.advance(4500)
        assertDeleted(a, b)
    }

    @Test
    fun `an earlier message that was read does not stop a later lone deletion`() {
        h.screenOnUnlocked()
        val first = h.post(1, listOf(a))
        h.cancel(first) // read in WhatsApp
        h.advance(4500)
        assertDeleted()

        h.screenOff()
        val second = h.post(1, listOf(b))
        h.cancel(second)
        h.advance(4500)
        assertDeleted(b)
    }

    @Test
    fun `duplicate removal events for one deletion record it once`() {
        val key = h.post(1, listOf(a))
        h.cancel(key)
        h.advance(4500)
        h.post(1, listOf(a)) // never happens for a deleted message, but must not double-count
        assertEquals(1, h.eventsOfType("deleted").size)
    }

    // ---------------------------------------------------------------- must NEVER be flagged as deleted

    @Test
    fun `message read on the phone is not a deletion`() {
        h.screenOnUnlocked()
        val key = h.post(1, listOf(a))
        h.cancel(key)
        h.advance(4500)

        assertDeleted()
        assertTrue(h.eventsOfType("deleted").isEmpty())
    }

    @Test
    fun `swipe dismissal is not a deletion`() {
        val key = h.post(1, listOf(a))
        h.cancel(key, REASON_CANCEL)
        h.advance(4500)

        assertDeleted()
    }

    @Test
    fun `tapping the notification is not a deletion`() {
        val key = h.post(1, listOf(a))
        h.cancel(key, REASON_CLICK)
        h.advance(4500)

        assertDeleted()
    }

    @Test
    fun `several unread messages cleared together are not deletions`() {
        val key = h.post(1, listOf(a, b, c))
        h.cancel(key, REASON_APP_CANCEL)
        h.advance(4500)

        assertDeleted()
    }

    @Test
    fun `two messages cancelled and re-posted as only the newer one is not a deletion`() {
        // What reading the older message on another device looks like from here.
        val key = h.post(1, listOf(a, b))
        h.cancel(key)
        h.post(1, listOf(b))
        h.advance(4500)

        assertDeleted()
    }

    @Test
    fun `burst of messages with cancel and re-post on the same key deletes nothing`() {
        var key = h.post(1, listOf(a))
        h.cancel(key); key = h.post(1, listOf(a, b))
        h.cancel(key); key = h.post(1, listOf(a, b, c))
        h.advance(4500)

        assertDeleted()
        assertTrue("live messages must not be left flagged removed", h.messages().all { it.removedAt == null })
        assertTrue(h.eventsOfType("removed").isEmpty())
        assertTrue(h.eventsOfType("deleted").isEmpty())
    }

    @Test
    fun `burst of messages re-posted under a new key each time deletes nothing`() {
        var key = h.post(1, listOf(a))
        h.cancel(key); key = h.post(2, listOf(a, b))
        h.cancel(key); key = h.post(3, listOf(a, b, c))
        h.advance(4500)

        assertDeleted()
        assertTrue(h.messages().all { it.removedAt == null })
        assertTrue(h.messages().all { it.notifKey == key })
        assertTrue(h.eventsOfType("removed").isEmpty())
    }

    @Test
    fun `cancelling a chain that grew across re-posts is then cleared, not deleted`() {
        // Regression: rows carried an old key, so clearing the final notification looked like
        // it held only the newest message -- a lone message, i.e. a deletion.
        var key = h.post(1, listOf(a))
        h.cancel(key); key = h.post(2, listOf(a, b))
        h.cancel(key); key = h.post(3, listOf(a, b, c))
        h.advance(4500)
        h.cancel(key)
        h.advance(4500)

        assertDeleted()
    }

    @Test
    fun `message re-issued under a new key is not a deletion`() {
        val first = h.post(1, listOf(a))
        h.cancel(first)
        h.post(2, listOf(a))
        h.advance(4500)

        assertDeleted()
        assertTrue(h.eventsOfType("removed").isEmpty())
    }

    @Test
    fun `edit is recorded as an edit, not a deletion`() {
        h.post(1, listOf(a))
        h.post(1, listOf(Msg("A: hello (edited)", a.timestamp)))
        h.advance(4500)

        assertDeleted()
        assertEquals(1, h.eventsOfType("edited").size)
    }

    @Test
    fun `unknown notification being cancelled changes nothing`() {
        h.post(1, listOf(a))
        h.advance(4500)

        assertDeleted()
        assertNull(h.message(a.text).removedAt)
    }

    @Test
    fun `plain capture of a growing conversation records every message once`() {
        h.post(1, listOf(a))
        h.post(1, listOf(a, b))
        h.post(1, listOf(a, b, c))
        h.advance(4500)

        assertEquals(listOf(a.text, b.text, c.text), h.messages().map { it.text })
        assertFalse(h.messages().any { it.isDeleted })
    }
}
