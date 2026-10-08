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
    fun `lone message cancelled then re-posted after the grace period is restored`() {
        val key = h.post(1, listOf(a))
        h.cancel(key)
        h.advance(4500)
        assertDeleted(a) // indistinguishable from a deletion at this point

        h.post(2, listOf(a)) // WhatsApp shows it again -- it was never deleted

        assertDeleted()
        assertTrue(h.eventsOfType("updated").isNotEmpty())
    }

    @Test
    fun `lone message cancelled then re-posted with a newer one after the grace period is restored`() {
        val key = h.post(1, listOf(a))
        h.cancel(key)
        h.advance(4500)

        h.post(1, listOf(a, b))
        h.advance(4500)

        assertDeleted()
        assertEquals(listOf(a.text, b.text), h.messages().map { it.text })
    }

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
    fun `tapping the notification on the lock screen and then unlocking is not a deletion`() {
        h.screenOnLocked()
        val key = h.post(1, listOf(a))
        h.cancel(key) // WhatsApp cancels at the tap, before the unlock has finished
        h.advance(1500)
        h.unlock()
        h.advance(20_000)

        assertDeleted()
        assertTrue(h.eventsOfType("deleted").isEmpty())
    }

    @Test
    fun `lone message cancelled while the screen is on but stays locked is still a deletion`() {
        h.screenOnLocked()
        val key = h.post(1, listOf(a))
        h.cancel(key)
        h.advance(4500)
        assertDeleted() // still waiting for a possible unlock
        h.advance(16_000)

        assertDeleted(a)
    }

    @Test
    fun `cancel right after one of two messages was deleted does not delete the survivor`() {
        // Reported on a locked Pixel: "Hello", then "Hiii", then the sender deletes "Hiii".
        // WhatsApp shows the placeholder beside "Hello", then cancels the notification.
        h.screenOnLocked()
        h.post(1, listOf(a))
        h.post(1, listOf(a, b))
        val key = h.post(1, listOf(a, Msg("This message was deleted", b.timestamp)))
        h.cancel(key)
        h.advance(21_000)

        assertDeleted(b)
    }

    @Test
    fun `real edit is listed in the deleted tab with its history`() {
        h.post(1, listOf(a, b))
        h.post(1, listOf(a, Msg("B: how are you doing", b.timestamp)))

        val store = MessageStore.getInstance(org.robolectric.RuntimeEnvironment.getApplication())
        val listed = store.getEditedOrDeletedMessages(null)
        assertEquals(listOf("B: how are you doing"), listed.map { it["text"] })
        assertEquals(1, (listed.single()["editHistory"] as List<*>).size)
    }

    @Test
    fun `edit that collides with an existing message saves nothing at all`() {
        val store = MessageStore.getInstance(org.robolectric.RuntimeEnvironment.getApplication())
        h.post(1, listOf(Msg("Dbd", 2000), Msg("Dhd", 2000)))
        val dbdId = store.getWindow("com.whatsapp|Alice", 7).first { it.text == "Dbd" }.id!!

        assertNull(store.applyEdit(dbdId, "Dhd", 5000)) // "Dhd" at 2000 already exists

        assertTrue(store.getEditedOrDeletedMessages(null).isEmpty())
        assertTrue(store.getMessages("com.whatsapp|Alice").all { (it["editHistory"] as List<*>).isEmpty() })
    }

    @Test
    fun `lone deletion right after an earlier locked-screen cancel of the same chat is caught`() {
        // Pixel log 10-07 11:12: old unread messages cancelled on the lock screen (resolution
        // waits for an unlock), re-posted as just "Hello", which the sender then deletes.
        h.screenOnLocked()
        val key = h.post(1, listOf(a, b))
        h.cancel(key)
        h.screenOff()
        val again = h.post(1, listOf(c))
        h.cancel(again)
        h.advance(4500)

        assertDeleted(c)
        h.advance(20_000) // the earlier cancel resolves now and must not add anything
        assertDeleted(c)
    }

    @Test
    fun `oldest of two messages deleted while locked is recovered`() {
        h.post(1, listOf(a))
        h.post(1, listOf(a, b))
        h.post(1, listOf(b)) // WhatsApp re-posts without the deleted (older) one
        h.advance(4500)

        assertDeleted(a)
    }

    @Test
    fun `lock-screen cancel counts as opening it when the phone is unlocked by the end of the wait`() {
        // No USER_PRESENT broadcast this time -- only the keyguard state shows the unlock.
        h.screenOnLocked()
        val key = h.post(1, listOf(a))
        h.cancel(key)
        h.screenOnUnlocked()
        h.advance(21_000)

        assertDeleted()
    }

    @Test
    fun `lone deletion arriving as a group-summary cascade is recovered (Pixel log 11_27)`() {
        val key = h.post(1, listOf(a))
        h.cancelViaSummary(key)
        h.advance(4500)

        assertDeleted(a)
    }

    @Test
    fun `user swiping the whole group away is not a deletion`() {
        val key = h.post(1, listOf(a))
        h.cancelViaSummary(key, summaryReason = REASON_CANCEL)
        h.advance(4500)

        assertDeleted()
    }

    @Test
    fun `unlock seen by polling during the wait counts, even if the phone locks again`() {
        h.screenOnLocked()
        val key = h.post(1, listOf(a))
        h.cancel(key)
        h.advance(1000)
        h.screenOnUnlocked() // no USER_PRESENT broadcast
        h.advance(1000)
        h.screenOff()
        h.advance(20_000)

        assertDeleted()
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
