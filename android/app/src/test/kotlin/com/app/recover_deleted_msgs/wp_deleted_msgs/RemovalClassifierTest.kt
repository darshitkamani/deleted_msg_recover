package com.app.recover_deleted_msgs.wp_deleted_msgs

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RemovalClassifierTest {

    private fun decide(
        isAppCancel: Boolean = true,
        couldBeReadingOnThisPhone: Boolean = false,
        unread: Int = 1,
        stillShown: Boolean = false
    ) = RemovalClassifier.isLikelyDeletion(isAppCancel, couldBeReadingOnThisPhone, unread, stillShown)

    @Test
    fun `lone message cancelled by WhatsApp while user can't be reading it is a deletion`() {
        // The logged case: one message, APP_CANCEL, nothing re-posted, this app on screen.
        assertTrue(decide())
    }

    @Test
    fun `swipe or tap dismissal is never a deletion`() {
        assertFalse(decide(isAppCancel = false))
    }

    @Test
    fun `screen on and unlocked with WhatsApp possibly open is not a deletion`() {
        // Could just be the user reading the chat in WhatsApp.
        assertFalse(decide(couldBeReadingOnThisPhone = true))
    }

    @Test
    fun `several messages cancelled at once is a read or clear, not deletions`() {
        assertFalse(decide(unread = 3))
        assertFalse(decide(unread = 2))
    }

    @Test
    fun `nothing unread in the notification is not a deletion`() {
        assertFalse(decide(unread = 0))
    }

    @Test
    fun `message still shown in another notification was re-issued, not deleted`() {
        assertFalse(decide(stillShown = true))
    }
}
