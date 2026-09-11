package com.recoverdeletedmessages.app

/**
 * Shared between [NotificationListener] (to build the right chatKey for a
 * freshly-posted notification) and [MessageStore] (to fold pre-existing
 * duplicate chat rows back together): a group with an unread backlog gets
 * its conversation title rewritten by WhatsApp/Android to e.g.
 * "TechOnTouch x WB (12 messages)" -- the count changes on every
 * notification, so treating the raw title as identity splits one real group
 * into a new "chat" per count instead.
 */
object ChatTitleUtils {
    private val unreadCountSuffix = Regex("""\s*\(\d+\s+(new\s+)?messages?\)$""", RegexOption.IGNORE_CASE)

    fun normalize(title: String): String =
        title.replace(unreadCountSuffix, "").trim().ifEmpty { title }
}
