package com.dominictatakis.calendarsync.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

// Maps to the profiles table
@Serializable
data class AppUser(
    val id: String,
    val email: String,
    @SerialName("display_name") val displayName: String,
    @SerialName("avatar_url") val avatarUrl: String? = null,
)

// Maps to the friendships table
@Serializable
data class Friendship(
    val id: String,
    @SerialName("requester_id") val requesterId: String,
    @SerialName("addressee_id") val addresseeId: String,
    val status: String, // "pending" | "accepted"
)

data class Friend(
    val id: String,
    val user: AppUser,
    val groups: List<String> = emptyList(),
)

@Serializable
data class FriendGroup(
    val id: String,
    @SerialName("owner_id") val ownerId: String,
    val name: String,
) {
    companion object {
        const val CLOSE_FRIENDS_NAME = "Close Friends"
    }
}

@Serializable
data class GroupMember(
    @SerialName("group_id") val groupId: String,
    @SerialName("user_id") val userId: String,
)

enum class CalendarSource { APPLE, GOOGLE, OUTLOOK }

data class CalendarEvent(
    val id: String,
    val title: String,
    val startDate: Instant,
    val endDate: Instant,
    val isAllDay: Boolean,
    val source: CalendarSource,
    val calendarName: String,
    val color: Long, // ARGB color
)

data class AvailabilitySlot(
    val id: String,
    val ownerId: String,
    val startDate: Instant,
    val endDate: Instant,
    val title: String?,
    val isAllDay: Boolean,
)

@Serializable
data class SharedEvent(
    val id: String = "",
    @SerialName("organizer_id") val organizerId: String,
    @SerialName("organizer_name") val organizerName: String,
    val title: String,
    @SerialName("start_date") val startDate: String,
    @SerialName("end_date") val endDate: String,
    val location: String? = null,
    val notes: String? = null,
)

@Serializable
data class EventInvite(
    val id: String = "",
    @SerialName("event_id") val eventId: String,
    @SerialName("invitee_id") val inviteeId: String,
    @SerialName("invitee_email") val inviteeEmail: String? = null,
    val status: String = "pending",
)
