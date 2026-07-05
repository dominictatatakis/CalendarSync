package com.dominictatakis.calendarsync.data.repository

import android.content.ContentResolver
import android.database.Cursor
import android.provider.CalendarContract
import com.dominictatakis.calendarsync.data.model.CalendarEvent
import com.dominictatakis.calendarsync.data.model.CalendarSource
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Reads events from the Android system calendar (CalendarProvider).
 * Requires READ_CALENDAR permission.
 */
@Singleton
class AndroidCalendarRepository @Inject constructor() {

    fun fetchEvents(
        contentResolver: ContentResolver,
        startMillis: Long,
        endMillis: Long,
    ): List<CalendarEvent> {
        val events = mutableListOf<CalendarEvent>()

        // Build the instances query for the date range
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon()
            .appendPath(startMillis.toString())
            .appendPath(endMillis.toString())
            .build()

        val projection = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.ALL_DAY,
            CalendarContract.Instances.CALENDAR_DISPLAY_NAME,
            CalendarContract.Instances.CALENDAR_COLOR,
        )

        val cursor: Cursor? = contentResolver.query(uri, projection, null, null, "${CalendarContract.Instances.BEGIN} ASC")

        cursor?.use {
            while (it.moveToNext()) {
                val eventId = it.getLong(0)
                val title = it.getString(1) ?: "No Title"
                val begin = it.getLong(2)
                val end = it.getLong(3)
                val allDay = it.getInt(4) == 1
                val calName = it.getString(5) ?: "Calendar"
                val calColor = it.getInt(6).toLong() or 0xFF000000

                events.add(
                    CalendarEvent(
                        id = "android-$eventId",
                        title = title,
                        startDate = Instant.ofEpochMilli(begin),
                        endDate = Instant.ofEpochMilli(end),
                        isAllDay = allDay,
                        source = CalendarSource.GOOGLE, // Android calendar provider
                        calendarName = calName,
                        color = calColor,
                    )
                )
            }
        }

        return events
    }
}
