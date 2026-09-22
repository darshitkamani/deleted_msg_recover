package com.app.recover_deleted_msgs.wp_deleted_msgs

import com.app.recover_deleted_msgs.wp_deleted_msgs.NotificationFlowHarness.Msg
import org.junit.After
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.Random

/**
 * Random conversation histories through the real listener and database, checked against a
 * ground truth the script itself keeps. Three properties, for every script:
 *
 *  1. Never a false deletion: a message its sender did not delete is never flagged deleted.
 *  2. Every deletion that is detectable IS caught (see [Model.undetectable] for the ones that
 *     genuinely can't be, which are only allowed -- not required -- to be caught).
 *  3. A message still sitting in the live notification is never left flagged removed, and is
 *     attached to that notification's key.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], shadows = [ShadowActiveNotifications::class])
class RandomizedFlowTest {

    private lateinit var h: NotificationFlowHarness

    @Before
    fun setUp() {
        NotificationFlowHarness.resetStore()
        h = NotificationFlowHarness()
    }

    @After
    fun tearDown() = NotificationFlowHarness.resetStore()

    /** How often each kind of step actually ran, so the test can prove it isn't vacuous. */
    private val coverage = sortedMapOf<String, Int>()
    private fun covered(kind: String) { coverage[kind] = (coverage[kind] ?: 0) + 1 }

    private class Model {
        /** What WhatsApp is showing right now, oldest first. Placeholders stay in place. */
        val window = mutableListOf<Msg>()
        var liveKey: String? = null
        var nextId = 1
        var clock = 1000L
        var counter = 0

        val everDeleted = mutableSetOf<String>()      // sender deleted it
        val mustBeFlagged = mutableSetOf<String>()    // ...and we are obliged to have caught it
        var tainted = false                           // see [undetectable]

        /**
         * The oldest of several messages vanishing silently looks exactly like scrolling out or
         * being read (an information limit documented in MessageReconciler), and it also leaves
         * a stale unread row behind that hides later lone-cancel deletions. Once that has
         * happened in a window, later deletions are allowed but not required to be caught.
         */
        fun undetectable() { tainted = true }

        fun isPlaceholder(m: Msg) = m.text.startsWith("This message was deleted")
        val real get() = window.filter { !isPlaceholder(it) }
    }

    @Test
    fun `random histories never falsely delete, always catch what is catchable, and keep live rows live`() {
        val scripts = 300
        for (seed in 0 until scripts) {
            h.reset()
            runScript(seed.toLong())
        }
        println("randomized coverage over $scripts scripts: $coverage")
        for (kind in listOf(
            "arrive-newkey", "arrive-samekey", "churn", "read-clear",
            "delete-placeholder", "delete-lone", "delete-silent", "deletion-required", "deletion-allowed-only"
        )) {
            if ((coverage[kind] ?: 0) < 20) fail("test is not exercising \"$kind\" enough: $coverage")
        }
    }

    private fun runScript(seed: Long) {
        val rnd = Random(seed)
        val m = Model()
        val log = mutableListOf<String>()

        fun fail(why: String): Nothing = fail("seed=$seed: $why\nops:\n  " + log.joinToString("\n  "))

        fun repost(newKey: Boolean) {
            val old = m.liveKey
            val id = if (newKey || old == null) ++m.nextId else m.nextId
            if (newKey && old != null) h.cancel(old)
            m.liveKey = h.post(id, m.window.toList())
        }

        fun settleAndCheck(op: String) {
            h.advance(5000)
            log += op
            val rows = h.messages()
            val flagged = rows.filter { it.isDeleted }.map { it.text }.toSet()

            val falsely = flagged - m.everDeleted
            if (falsely.isNotEmpty()) fail("falsely flagged as deleted: $falsely after \"$op\"")

            val missed = m.mustBeFlagged - flagged
            if (missed.isNotEmpty()) fail("deletion not caught: $missed after \"$op\"")

            val key = m.liveKey
            if (key != null) {
                for (msg in m.real) {
                    val row = rows.singleOrNull { it.text == msg.text } ?: continue
                    if (row.isDeleted) continue
                    if (row.removedAt != null) fail("live message \"${msg.text}\" left flagged removed after \"$op\"")
                    if (row.notifKey != key) fail("live message \"${msg.text}\" on stale key ${row.notifKey} != $key after \"$op\"")
                }
            }
        }

        val steps = 6 + rnd.nextInt(8)
        repeat(steps) {
            h.screenOff()
            val real = m.real
            when (rnd.nextInt(6)) {
                // A new message arrives (the same key, or WhatsApp re-issuing under a new one).
                0, 1 -> if (m.window.size < 4) {
                    val text = "m${++m.counter}"
                    m.clock += 1000
                    m.window += Msg(text, m.clock)
                    val newKey = rnd.nextBoolean()
                    repost(newKey)
                    covered(if (newKey) "arrive-newkey" else "arrive-samekey")
                    settleAndCheck("arrive $text newKey=$newKey window=${m.window.map { it.text }}")
                }

                // Cancel-and-repost churn of an unchanged window, screen on or off.
                2 -> if (m.window.isNotEmpty() && m.liveKey != null) {
                    if (rnd.nextBoolean()) h.screenOnUnlocked()
                    val newKey = rnd.nextBoolean()
                    h.cancel(m.liveKey!!)
                    m.liveKey = null
                    repost(newKey)
                    covered("churn")
                    settleAndCheck("churn newKey=$newKey window=${m.window.map { it.text }}")
                }

                // The user reads everything on the phone: WhatsApp cancels, nothing is deleted.
                3 -> if (m.liveKey != null) {
                    h.screenOnUnlocked()
                    h.cancel(m.liveKey!!)
                    m.liveKey = null
                    m.window.clear()
                    m.tainted = false
                    covered("read-clear")
                    settleAndCheck("read-clear")
                }

                // The sender deletes a message and WhatsApp shows the placeholder in place.
                4 -> if (real.isNotEmpty() && m.liveKey != null) {
                    val victim = real[rnd.nextInt(real.size)]
                    val i = m.window.indexOf(victim)
                    m.window[i] = Msg("This message was deleted", victim.timestamp)
                    m.everDeleted += victim.text
                    m.mustBeFlagged += victim.text
                    repost(false)
                    covered("delete-placeholder"); covered("deletion-required")
                    settleAndCheck("delete-placeholder ${victim.text} window=${m.window.map { it.text }}")
                }

                // The sender deletes a message and WhatsApp just drops it, with no placeholder.
                5 -> if (real.isNotEmpty() && m.liveKey != null) {
                    val victim = real[rnd.nextInt(real.size)]
                    val i = m.window.indexOf(victim)
                    m.everDeleted += victim.text
                    if (m.window.size == 1) {
                        // Nothing left to re-post: WhatsApp cancels the notification.
                        m.window.removeAt(i)
                        h.cancel(m.liveKey!!)
                        m.liveKey = null
                        if (!m.tainted) m.mustBeFlagged += victim.text
                        covered("delete-lone"); covered(if (m.tainted) "deletion-allowed-only" else "deletion-required")
                        settleAndCheck("delete-lone ${victim.text}")
                    } else {
                        val anchored = m.window.take(i).any { !m.isPlaceholder(it) }
                        m.window.removeAt(i)
                        if (anchored) m.mustBeFlagged += victim.text else m.undetectable()
                        repost(false)
                        covered("delete-silent"); covered(if (anchored) "deletion-required" else "deletion-allowed-only")
                        settleAndCheck("delete-silent ${victim.text} anchored=$anchored window=${m.window.map { it.text }}")
                    }
                }
            }
        }
    }
}
