package org.taskdroid

import android.content.ContentProviderOperation
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.provider.CalendarContract
import android.util.Log
import java.util.TimeZone

class CalendarRepository(
    private val context: Context,
) {
    private val TAG = "CalendarRepo"
    private val UUID_TAG_PREFIX = "[TaskDroid ID: "
    private val UUID_TAG_SUFFIX = "]"

    fun getDefaultCalendarId(): Long? {
        val projection =
            arrayOf(
                CalendarContract.Calendars._ID,
                CalendarContract.Calendars.IS_PRIMARY,
                CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
            )

        val selection =
            "${CalendarContract.Calendars.VISIBLE} = 1 AND " +
                "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ${CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR}"

        var cursor: Cursor? = null
        try {
            cursor =
                context.contentResolver.query(
                    CalendarContract.Calendars.CONTENT_URI,
                    projection,
                    selection,
                    null,
                    null,
                )

            if (cursor != null && cursor.moveToFirst()) {
                do {
                    val id = cursor.getLong(0)
                    val isPrimary = cursor.getInt(1) == 1
                    if (isPrimary) {
                        return id
                    }
                } while (cursor.moveToNext())

                cursor.moveToFirst()
                return cursor.getLong(0)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error finding calendar: ${e.message}")
        } finally {
            cursor?.close()
        }
        return null
    }

    private fun buildDescriptionWithTag(
        description: String,
        uuid: String,
    ): String = "$description\n\n$UUID_TAG_PREFIX$uuid$UUID_TAG_SUFFIX"

    fun saveEvent(
        uuid: String,
        title: String,
        description: String,
        startMs: Long,
        endMs: Long,
        color: Int?,
    ): Boolean {
        val calId = getDefaultCalendarId() ?: return false
        val existingEventId = getEventIdByUuid(uuid)
        val finalDescription = buildDescriptionWithTag(description, uuid)

        val values =
            ContentValues().apply {
                put(CalendarContract.Events.DTSTART, startMs)
                put(CalendarContract.Events.DTEND, endMs)
                put(CalendarContract.Events.TITLE, title)
                put(CalendarContract.Events.DESCRIPTION, finalDescription)
                put(CalendarContract.Events.CALENDAR_ID, calId)
                put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
            }

        return try {
            if (existingEventId != null) {
                val updateUri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, existingEventId)
                context.contentResolver.update(updateUri, values, null, null) > 0
            } else {
                context.contentResolver.insert(CalendarContract.Events.CONTENT_URI, values) != null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error saving event: ${e.message}")
            false
        }
    }

    fun deleteEvent(uuid: String): Boolean {
        val eventId = getEventIdByUuid(uuid) ?: return false
        val deleteUri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId)
        return try {
            context.contentResolver.delete(deleteUri, null, null) > 0
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting event: ${e.message}")
            false
        }
    }

    fun deleteAllAppEvents(): Int {
        val selection = "${CalendarContract.Events.DESCRIPTION} LIKE ?"
        val selectionArgs = arrayOf("%$UUID_TAG_PREFIX%")
        return try {
            context.contentResolver.delete(CalendarContract.Events.CONTENT_URI, selection, selectionArgs)
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting all app events: ${e.message}")
            0
        }
    }

    fun batchSync(tasks: List<Map<String, Any>>): String {
        val calId = getDefaultCalendarId() ?: return "No Calendar Found"
        val ops = ArrayList<ContentProviderOperation>()

        val existingEvents = HashMap<String, Long>()
        val projection = arrayOf(CalendarContract.Events._ID, CalendarContract.Events.DESCRIPTION)
        val selection = "${CalendarContract.Events.DESCRIPTION} LIKE ?"
        val selectionArgs = arrayOf("%$UUID_TAG_PREFIX%")

        var cursor: Cursor? = null
        try {
            cursor =
                context.contentResolver.query(
                    CalendarContract.Events.CONTENT_URI,
                    projection,
                    selection,
                    selectionArgs,
                    null,
                )
            if (cursor != null) {
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(0)
                    val desc = cursor.getString(1) ?: ""
                    val uuid = extractUuidFromDescription(desc)
                    if (uuid != null) {
                        existingEvents[uuid] = id
                    }
                }
            }
        } catch (e: Exception) {
            return "Error querying calendar: ${e.message}"
        } finally {
            cursor?.close()
        }

        val incomingUuids = HashSet<String>()

        for (task in tasks) {
            val uuid = task["uuid"] as? String ?: continue
            val title = task["title"] as? String ?: "Task"
            val rawDesc = task["description"] as? String ?: ""
            val startMs = (task["start"] as? Number)?.toLong() ?: continue
            val endMs = (task["end"] as? Number)?.toLong() ?: (startMs + 3600000)

            incomingUuids.add(uuid)
            val finalDesc = buildDescriptionWithTag(rawDesc, uuid)

            if (existingEvents.containsKey(uuid)) {
                val eventId = existingEvents[uuid]!!
                val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId)

                ops.add(
                    ContentProviderOperation
                        .newUpdate(uri)
                        .withValue(CalendarContract.Events.DTSTART, startMs)
                        .withValue(CalendarContract.Events.DTEND, endMs)
                        .withValue(CalendarContract.Events.TITLE, title)
                        .withValue(CalendarContract.Events.DESCRIPTION, finalDesc)
                        .build(),
                )
            } else {
                ops.add(
                    ContentProviderOperation
                        .newInsert(CalendarContract.Events.CONTENT_URI)
                        .withValue(CalendarContract.Events.CALENDAR_ID, calId)
                        .withValue(CalendarContract.Events.DTSTART, startMs)
                        .withValue(CalendarContract.Events.DTEND, endMs)
                        .withValue(CalendarContract.Events.TITLE, title)
                        .withValue(CalendarContract.Events.DESCRIPTION, finalDesc)
                        .withValue(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
                        .build(),
                )
            }
        }

        // orphans
        for ((uuid, eventId) in existingEvents) {
            if (!incomingUuids.contains(uuid)) {
                val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId)
                ops.add(ContentProviderOperation.newDelete(uri).build())
            }
        }

        return try {
            if (ops.isNotEmpty()) {
                context.contentResolver.applyBatch(CalendarContract.AUTHORITY, ops)
                "Synced ${ops.size} operations"
            } else {
                "No changes needed"
            }
        } catch (e: Exception) {
            Log.e(TAG, "Batch failed", e)
            "Batch failed: ${e.message}"
        }
    }

    private fun getEventIdByUuid(uuid: String): Long? {
        val projection = arrayOf(CalendarContract.Events._ID)
        val selection = "${CalendarContract.Events.DESCRIPTION} LIKE ?"
        val selectionArgs = arrayOf("%$UUID_TAG_PREFIX$uuid$UUID_TAG_SUFFIX%")

        var cursor: Cursor? = null
        try {
            cursor =
                context.contentResolver.query(
                    CalendarContract.Events.CONTENT_URI,
                    projection,
                    selection,
                    selectionArgs,
                    null,
                )
            if (cursor != null && cursor.moveToFirst()) {
                return cursor.getLong(0)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Query failed for UUID $uuid: ${e.message}")
        } finally {
            cursor?.close()
        }
        return null
    }

    private fun extractUuidFromDescription(description: String): String? {
        try {
            val startIndex = description.lastIndexOf(UUID_TAG_PREFIX)
            if (startIndex == -1) return null
            val afterPrefix = description.substring(startIndex + UUID_TAG_PREFIX.length)
            val endIndex = afterPrefix.indexOf(UUID_TAG_SUFFIX)
            if (endIndex == -1) return null
            return afterPrefix.substring(0, endIndex)
        } catch (e: Exception) {
            return null
        }
    }
}
