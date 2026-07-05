package com.dominictatakis.calendarsync.data.repository

import com.dominictatakis.calendarsync.data.model.CalendarEvent
import com.dominictatakis.calendarsync.data.model.CalendarSource
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.request.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.serialization.json.*
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class GoogleCalendarRepository @Inject constructor() {

    private val httpClient = HttpClient {
        install(ContentNegotiation) { json(Json { ignoreUnknownKeys = true }) }
    }

    private val baseUrl = "https://www.googleapis.com/calendar/v3"

    suspend fun fetchEvents(accessToken: String, startDate: Instant, endDate: Instant): List<CalendarEvent> {
        // Fetch calendar list
        val listJson = httpClient.get("$baseUrl/users/me/calendarList") {
            parameter("minAccessRole", "reader")
            header("Authorization", "Bearer $accessToken")
        }.body<JsonObject>()

        val calendars = listJson["items"]?.jsonArray ?: return emptyList()

        val allEvents = mutableListOf<CalendarEvent>()
        val formatter = DateTimeFormatter.ISO_INSTANT

        for (cal in calendars) {
            val calObj = cal.jsonObject
            val calId = calObj["id"]?.jsonPrimitive?.content ?: continue
            val calName = calObj["summary"]?.jsonPrimitive?.content ?: "Calendar"
            val hexColor = calObj["backgroundColor"]?.jsonPrimitive?.content ?: "#4285F4"

            val eventsJson = httpClient.get("$baseUrl/calendars/${calId}/events") {
                parameter("timeMin", formatter.format(startDate))
                parameter("timeMax", formatter.format(endDate))
                parameter("singleEvents", "true")
                parameter("orderBy", "startTime")
                parameter("maxResults", "250")
                header("Authorization", "Bearer $accessToken")
            }.body<JsonObject>()

            val items = eventsJson["items"]?.jsonArray ?: continue

            for (item in items) {
                val obj = item.jsonObject
                val id = obj["id"]?.jsonPrimitive?.content ?: continue
                val title = obj["summary"]?.jsonPrimitive?.content ?: continue
                val startObj = obj["start"]?.jsonObject ?: continue
                val endObj = obj["end"]?.jsonObject ?: continue

                val isAllDay = startObj.containsKey("date")
                val startStr = startObj["date"]?.jsonPrimitive?.content
                    ?: startObj["dateTime"]?.jsonPrimitive?.content ?: continue
                val endStr = endObj["date"]?.jsonPrimitive?.content
                    ?: endObj["dateTime"]?.jsonPrimitive?.content ?: continue

                val start = if (isAllDay) {
                    LocalDate.parse(startStr).atStartOfDay().toInstant(ZoneOffset.UTC)
                } else {
                    Instant.parse(startStr)
                }
                val end = if (isAllDay) {
                    LocalDate.parse(endStr).atStartOfDay().toInstant(ZoneOffset.UTC)
                } else {
                    Instant.parse(endStr)
                }

                allEvents.add(
                    CalendarEvent(
                        id = "google-$id",
                        title = title,
                        startDate = start,
                        endDate = end,
                        isAllDay = isAllDay,
                        source = CalendarSource.GOOGLE,
                        calendarName = calName,
                        color = parseHexColor(hexColor),
                    )
                )
            }
        }

        return allEvents.sortedBy { it.startDate }
    }

    private fun parseHexColor(hex: String): Long {
        val cleaned = hex.removePrefix("#")
        return (0xFF000000 or cleaned.toLong(16))
    }
}
