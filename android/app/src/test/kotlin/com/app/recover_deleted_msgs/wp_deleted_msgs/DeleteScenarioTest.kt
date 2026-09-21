package com.app.recover_deleted_msgs.wp_deleted_msgs

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Diagnostic scenarios for sender-side "delete for everyone", written as the behaviour we
 * WANT -- a failure here is a confirmed defect in the delete path.
 */
class DeleteScenarioTest {

    private val stored = listOf(
        WindowEntry(1000, "hey", sender = "Alice", id = 1),
        WindowEntry(2000, "see you at 5", sender = "Alice", id = 2)
    )

    private fun deletedInPlace(placeholderText: String, sender: String? = "Alice", ts: Long = 2000) =
        MessageReconciler.reconcile(
            stored = stored,
            incoming = listOf(
                WindowEntry(1000, "hey", sender = "Alice"),
                WindowEntry(ts, placeholderText, sender = sender)
            )
        )

    @Test
    fun `plain placeholder in place is a delete`() {
        assertTrue(deletedInPlace("This message was deleted")[1] is ReconcileAction.DeletedWithPlaceholder)
    }

    @Test
    fun `placeholder with a leading emoji is a delete`() {
        assertTrue(deletedInPlace("🚫 This message was deleted")[1] is ReconcileAction.DeletedWithPlaceholder)
    }

    @Test
    fun `placeholder with trailing punctuation is a delete`() {
        assertTrue(deletedInPlace("This message was deleted.")[1] is ReconcileAction.DeletedWithPlaceholder)
    }

    @Test
    fun `placeholder is never recorded as a brand new message`() {
        // Timestamp WhatsApp posts for the placeholder differs from the original message's.
        val actions = deletedInPlace("This message was deleted", ts = 2500)
        assertTrue(
            "placeholder text must not be inserted as a real chat message",
            actions.none { it is ReconcileAction.Insert && it.entry.text.contains("deleted", ignoreCase = true) }
        )
    }

    @Test
    fun `placeholder whose sender is not reported still deletes the right message`() {
        // Group chat: the placeholder's Person can come through without a name.
        val actions = deletedInPlace("This message was deleted", sender = null)
        assertEquals(
            "the 'see you at 5' row should be the one flagged",
            2L,
            actions.filterIsInstance<ReconcileAction.DeletedWithPlaceholder>().singleOrNull()?.previous?.id
        )
    }

    @Test
    fun `deleting the newest message while older ones remain is a silent delete`() {
        val actions = MessageReconciler.reconcile(
            stored = stored,
            incoming = listOf(WindowEntry(1000, "hey", sender = "Alice"))
        )
        assertEquals(2L, actions.filterIsInstance<ReconcileAction.DeletedSilently>().singleOrNull()?.previous?.id)
    }
}
