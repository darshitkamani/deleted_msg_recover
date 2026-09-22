package com.app.recover_deleted_msgs.wp_deleted_msgs

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The decision NotificationListener.resolveRemoval makes once a cancelled notification's grace
 * period is over, driven with the same inputs the listener supplies from the notification
 * manager and its capture log.
 */
class RemovalResolveTest {

    private fun row(id: Long, text: String = "msg$id", alreadyDeleted: Boolean = false) =
        RemovalResult("wa|Alice", "Alice", text, "Alice", id, 1000L + id, alreadyDeleted)

    private fun resolve(
        rows: List<RemovalResult>,
        isAppCancel: Boolean = true,
        couldBeReading: Boolean = false,
        capturedAfterCancel: Set<Long> = emptySet(),
        shownIn: Map<Long, String> = emptyMap()
    ) = RemovalClassifier.resolve(
        results = rows,
        isAppCancel = isAppCancel,
        couldBeReadingOnThisPhone = couldBeReading,
        capturedAfterCancel = { it.id in capturedAfterCancel },
        shownIn = { shownIn[it.id] }
    )

    @Test
    fun `lone message deleted with nothing re-posted is a deletion`() {
        val a = row(1)
        val d = resolve(listOf(a))

        assertEquals(a, d.deletion)
        assertEquals(listOf(a), d.gone)
        assertTrue(d.stillActive.isEmpty())
    }

    @Test
    fun `lone message deleted, then a new one arrives under the same key, is still a deletion`() {
        val a = row(1)
        val b = row(2)
        val d = resolve(
            rows = listOf(a, b),
            capturedAfterCancel = setOf(2),
            shownIn = mapOf(2L to "key")
        )

        assertEquals(a, d.deletion)
        assertEquals(listOf(a), d.gone)
        assertEquals(mapOf(b to "key"), d.stillActive)
    }

    @Test
    fun `several messages that were all in the cancelled notification are never a deletion`() {
        // Cancelled together and re-posted as just the last one: A vanishing here is what a
        // read on another device looks like, so it must not become a deletion.
        val a = row(1)
        val b = row(2)
        val d = resolve(listOf(a, b), shownIn = mapOf(2L to "key"))

        assertNull(d.deletion)
        assertEquals(listOf(a), d.gone)
    }

    @Test
    fun `burst of messages cancelled and re-posted whole is neither removed nor deleted`() {
        val rows = listOf(row(1), row(2), row(3))
        val d = resolve(rows, shownIn = rows.associate { it.id to "key" })

        assertNull(d.deletion)
        assertTrue(d.gone.isEmpty())
        assertEquals(3, d.stillActive.size)
    }

    @Test
    fun `lone message re-issued under a new key is not a deletion`() {
        val a = row(1)
        val d = resolve(listOf(a), shownIn = mapOf(1L to "newKey"))

        assertNull(d.deletion)
        assertTrue(d.gone.isEmpty())
        assertEquals(mapOf(a to "newKey"), d.stillActive)
    }

    @Test
    fun `lone message cancelled while the user could be reading is not a deletion`() {
        assertNull(resolve(listOf(row(1)), couldBeReading = true).deletion)
    }

    @Test
    fun `swipe dismissal is not a deletion`() {
        assertNull(resolve(listOf(row(1)), isAppCancel = false).deletion)
    }

    @Test
    fun `message already marked deleted is not deleted twice`() {
        assertNull(resolve(listOf(row(1, alreadyDeleted = true))).deletion)
    }

    @Test
    fun `a new message alone under the key is not mistaken for a deletion`() {
        // Only a post-cancel arrival is left: nothing was in the cancelled notification.
        val d = resolve(listOf(row(2)), capturedAfterCancel = setOf(2), shownIn = mapOf(2L to "key"))

        assertNull(d.deletion)
    }
}
