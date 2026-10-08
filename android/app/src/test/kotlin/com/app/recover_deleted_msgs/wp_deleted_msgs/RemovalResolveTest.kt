package com.app.recover_deleted_msgs.wp_deleted_msgs

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * How NotificationListener.resolveRemoval sorts a removed notification's rows once the grace
 * period is over: still shown in some notification (re-issued) or gone. Never "deleted" -- see
 * NotificationListener.onNotificationRemoved.
 */
class RemovalResolveTest {

    private fun row(id: Long, text: String = "msg$id") =
        RemovalResult("wa|Alice", "Alice", text, "Alice", id, 1000L + id, false)

    private fun resolve(rows: List<RemovalResult>, shownIn: Map<Long, String> = emptyMap()) =
        RemovalClassifier.resolve(rows) { shownIn[it.id] }

    @Test
    fun `lone message with nothing re-posted is gone`() {
        val a = row(1)
        val d = resolve(listOf(a))

        assertEquals(listOf(a), d.gone)
        assertTrue(d.stillActive.isEmpty())
    }

    @Test
    fun `burst of messages removed and re-posted whole stays active`() {
        val rows = listOf(row(1), row(2), row(3))
        val d = resolve(rows, shownIn = rows.associate { it.id to "key" })

        assertTrue(d.gone.isEmpty())
        assertEquals(3, d.stillActive.size)
    }

    @Test
    fun `message re-issued under a new key stays active under that key`() {
        val a = row(1)
        val d = resolve(listOf(a), shownIn = mapOf(1L to "newKey"))

        assertTrue(d.gone.isEmpty())
        assertEquals(mapOf(a to "newKey"), d.stillActive)
    }

    @Test
    fun `only the rows no longer shown are gone`() {
        val a = row(1)
        val b = row(2)
        val d = resolve(listOf(a, b), shownIn = mapOf(2L to "key"))

        assertEquals(listOf(a), d.gone)
        assertEquals(mapOf(b to "key"), d.stillActive)
    }

    @Test
    fun `lone message the notification showed is the deletion`() {
        val a = row(1)
        assertEquals(a, RemovalClassifier.loneDeletion(listOf(a), listOf(a.timestamp to a.text!!)))
    }

    @Test
    fun `notification that showed several messages has no lone deletion`() {
        val a = row(1)
        val b = row(2)
        assertNull(
            RemovalClassifier.loneDeletion(
                listOf(a, b), listOf(a.timestamp to a.text!!, b.timestamp to b.text!!)
            )
        )
    }

    @Test
    fun `lone message still shown elsewhere is not the deletion`() {
        val a = row(1)
        assertNull(RemovalClassifier.loneDeletion(emptyList(), listOf(a.timestamp to a.text!!)))
    }

    @Test
    fun `notification showing only a deleted placeholder has no lone deletion`() {
        val a = row(1)
        assertNull(RemovalClassifier.loneDeletion(listOf(a), listOf(a.timestamp to "This message was deleted")))
    }

    @Test
    fun `already deleted row is not deleted again`() {
        val a = row(1).copy(alreadyDeleted = true)
        assertNull(RemovalClassifier.loneDeletion(listOf(a), listOf(a.timestamp to a.text!!)))
    }
}
