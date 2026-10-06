package com.app.recover_deleted_msgs.wp_deleted_msgs

import android.app.Notification
import com.app.recover_deleted_msgs.wp_deleted_msgs.NotificationFlowHarness.Msg
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** The "message deleted / edited" alerts this app posts itself, driven through the real listener. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], shadows = [ShadowActiveNotifications::class])
class AlertNotificationTest {

    private lateinit var h: NotificationFlowHarness

    private val a = Msg("A: hello", 1000)
    private val b = Msg("B: how are you", 2000)

    @Before
    fun setUp() {
        NotificationFlowHarness.resetStore()
        h = NotificationFlowHarness()
    }

    @After
    fun tearDown() {
        AppVisibility.isForeground = false
        NotificationFlowHarness.resetStore()
    }

    private fun Notification.title() = extras.getCharSequence(Notification.EXTRA_TITLE).toString()
    private fun Notification.bigText() = extras.getCharSequence(Notification.EXTRA_BIG_TEXT).toString()

    @Test
    fun `deleted message posts an alert with its text`() {
        val key = h.post(1, listOf(a))
        h.cancel(key)
        h.advance(4500)

        val alert = h.postedAlerts().single()
        assertEquals("Alice deleted a message", alert.title())
        assertEquals(a.text, alert.bigText())
    }

    @Test
    fun `edited message posts an alert with before and after`() {
        h.post(1, listOf(a, b))
        h.post(1, listOf(a, Msg("B: how are you doing", b.timestamp)))

        val alert = h.postedAlerts().single()
        assertEquals("Alice edited a message", alert.title())
        assertEquals("Before: B: how are you\nNow: B: how are you doing", alert.bigText())
    }

    @Test
    fun `new and unchanged messages post no alert`() {
        h.post(1, listOf(a))
        h.post(1, listOf(a, b))
        h.advance(4500)

        assertTrue(h.postedAlerts().isEmpty())
    }

    @Test
    fun `no alert while the app is on screen`() {
        AppVisibility.isForeground = true
        h.post(1, listOf(a, b))
        h.post(1, listOf(a))
        h.advance(4500)

        assertEquals(1, h.eventsOfType("deleted").size)
        assertTrue(h.postedAlerts().isEmpty())
    }

    @Test
    fun `no alert when turned off in settings`() {
        h.setAlertsEnabled(false)
        val key = h.post(1, listOf(a))
        h.cancel(key)
        h.advance(4500)

        assertEquals(1, h.eventsOfType("deleted").size)
        assertTrue(h.postedAlerts().isEmpty())
    }
}
