package com.recoverdeletedmessages.app

/** One message's identity within a WhatsApp notification's ordered window. */
data class WindowItem(val timestamp: Long, val text: String?, val sender: String?)

sealed class WindowDiffOp {
    data class Edit(val old: WindowItem, val new: WindowItem) : WindowDiffOp()
    data class Delete(val old: WindowItem) : WindowDiffOp()
    data class Insert(val new: WindowItem) : WindowDiffOp()
}

/**
 * Compares two consecutive snapshots of a chat's notification message window
 * (oldest -> newest, exactly the order WhatsApp sends them in) to recover
 * edits and deletions that plain (notif_key, timestamp) matching in
 * [MessageStore] can miss -- specifically, an edited message whose timestamp
 * WhatsApp reassigns looks like a brand new, unrelated message to that
 * simpler check, and six messages that all happen to say the same thing are
 * otherwise indistinguishable from each other by content alone.
 *
 * Unchanged items are aligned via a longest-common-subsequence match on
 * (timestamp, text) -- only messages that are identical on both sides count
 * as "the same". Whatever falls between two aligned anchors on both sides
 * (a "gap") is where real changes hide:
 *  - a single old item swapped for a single new item at the same interior
 *    slot -> the message was edited.
 *  - an old item whose slot is now simply empty -> the message was deleted.
 *  - a slot that's new on both sides -> a brand new message (already
 *    handled by the normal insert path; reported here only for completeness).
 *
 * Gaps at the very start or end of the window are deliberately ignored:
 * WhatsApp's window is capped in size, so the oldest message aging off the
 * front, or a new message simply not having arrived at the back yet, look
 * identical to a real change from either edge alone -- only an interior gap,
 * sandwiched by unchanged neighbors on both sides, is an unambiguous signal.
 */
object WindowDiff {

    fun diff(old: List<WindowItem>, new: List<WindowItem>): List<WindowDiffOp> {
        if (old.isEmpty() || new.isEmpty()) return emptyList()

        val matches = lcsMatches(old, new)
        if (matches.size < 2) return emptyList()

        val ops = mutableListOf<WindowDiffOp>()
        for (k in 0 until matches.size - 1) {
            val (oldStart, newStart) = matches[k]
            val (oldEnd, newEnd) = matches[k + 1]
            val oldGap = old.subList(oldStart + 1, oldEnd)
            val newGap = new.subList(newStart + 1, newEnd)
            ops += gapToOps(oldGap, newGap)
        }
        return ops
    }

    private fun gapToOps(oldGap: List<WindowItem>, newGap: List<WindowItem>): List<WindowDiffOp> {
        if (oldGap.isEmpty() && newGap.isEmpty()) return emptyList()
        val ops = mutableListOf<WindowDiffOp>()
        val paired = minOf(oldGap.size, newGap.size)
        for (i in 0 until paired) ops += WindowDiffOp.Edit(oldGap[i], newGap[i])
        for (i in paired until oldGap.size) ops += WindowDiffOp.Delete(oldGap[i])
        for (i in paired until newGap.size) ops += WindowDiffOp.Insert(newGap[i])
        return ops
    }

    /**
     * Returns matched (oldIndex, newIndex) pairs, strictly increasing in
     * both indices, for items that are identical on both sides -- the LCS
     * "backbone" that gaps are measured against.
     */
    private fun lcsMatches(old: List<WindowItem>, new: List<WindowItem>): List<Pair<Int, Int>> {
        val n = old.size
        val m = new.size
        val dp = Array(n + 1) { IntArray(m + 1) }
        for (i in n - 1 downTo 0) {
            for (j in m - 1 downTo 0) {
                dp[i][j] = if (sameItem(old[i], new[j])) {
                    dp[i + 1][j + 1] + 1
                } else {
                    maxOf(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }
        val result = mutableListOf<Pair<Int, Int>>()
        var i = 0
        var j = 0
        while (i < n && j < m) {
            when {
                sameItem(old[i], new[j]) -> {
                    result += i to j
                    i++
                    j++
                }
                dp[i + 1][j] >= dp[i][j + 1] -> i++
                else -> j++
            }
        }
        return result
    }

    private fun sameItem(a: WindowItem, b: WindowItem) = a.timestamp == b.timestamp && a.text == b.text
}
