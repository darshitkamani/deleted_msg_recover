package com.app.recover_deleted_msgs.wp_deleted_msgs

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], shadows = [ShadowActiveNotifications::class])
class NotificationFlowSmokeTest {

    private lateinit var h: NotificationFlowHarness

    @Before
    fun setUp() {
        NotificationFlowHarness.resetStore()
        h = NotificationFlowHarness()
    }

    @After
    fun tearDown() = NotificationFlowHarness.resetStore()

    @Test
    fun `a posted message is captured`() {
        h.post(1, listOf(NotificationFlowHarness.Msg("hello", 1000)))

        assertEquals(1, h.messages().size)
        assertFalse(h.message("hello").isDeleted)
    }

    @Test
    fun `lone message cancelled by WhatsApp with the screen off is recorded as deleted`() {
        val key = h.post(1, listOf(NotificationFlowHarness.Msg("secret", 1000)))
        h.cancel(key)
        h.advance(4500)

        assertTrue(h.message("secret").isDeleted)
    }
}
