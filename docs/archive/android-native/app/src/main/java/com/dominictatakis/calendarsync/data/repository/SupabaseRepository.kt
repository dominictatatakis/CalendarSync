package com.dominictatakis.calendarsync.data.repository

import com.dominictatakis.calendarsync.BuildConfig
import com.dominictatakis.calendarsync.data.model.*
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.gotrue.Auth
import io.github.jan.supabase.gotrue.auth
import io.github.jan.supabase.gotrue.providers.builtin.OTP
import io.github.jan.supabase.gotrue.providers.builtin.IDToken
import io.github.jan.supabase.gotrue.providers.Google
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.rpc
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseRepository @Inject constructor() {

    val client: SupabaseClient = createSupabaseClient(
        supabaseUrl = BuildConfig.SUPABASE_URL,
        supabaseKey = BuildConfig.SUPABASE_ANON_KEY,
    ) {
        install(Auth)
        install(Postgrest)
    }

    // MARK: - Auth

    suspend fun sendOTP(email: String) {
        client.auth.signInWith(OTP) {
            this.email = email
        }
    }

    suspend fun verifyOTP(email: String, token: String): AppUser {
        client.auth.verifyEmailOtp(type = io.github.jan.supabase.gotrue.OtpType.Email.EMAIL, email = email, token = token)
        val session = client.auth.currentSessionOrNull() ?: throw IllegalStateException("No session after OTP verify")
        val uid = session.user?.id ?: throw IllegalStateException("No user ID")
        val userEmail = session.user?.email ?: email
        return upsertProfile(uid, userEmail)
    }

    suspend fun signInWithGoogleIdToken(idToken: String, accessToken: String): AppUser {
        client.auth.signInWith(IDToken) {
            provider = Google
            this.idToken = idToken
            this.accessToken = accessToken
        }
        val session = client.auth.currentSessionOrNull() ?: throw IllegalStateException("No session")
        val uid = session.user?.id ?: throw IllegalStateException("No user ID")
        val email = session.user?.email ?: uid
        return upsertProfile(uid, email)
    }

    suspend fun getCurrentUser(): AppUser? {
        val session = client.auth.currentSessionOrNull() ?: return null
        val uid = session.user?.id ?: return null
        return try { fetchProfile(uid) } catch (_: Exception) { null }
    }

    suspend fun signOut() {
        client.auth.signOut()
    }

    // MARK: - Profiles

    private suspend fun upsertProfile(id: String, email: String): AppUser {
        val displayName = email.substringBefore("@")
        client.from("profiles").upsert(buildJsonObject {
            put("id", id)
            put("email", email)
            put("display_name", displayName)
        })
        return fetchProfile(id)
    }

    private suspend fun fetchProfile(id: String): AppUser {
        return client.from("profiles").select {
            filter { eq("id", id) }
        }.decodeSingle<AppUser>()
    }

    suspend fun findUserByEmail(email: String): AppUser? {
        val results = client.from("profiles").select {
            filter { eq("email", email) }
        }.decodeList<AppUser>()
        return results.firstOrNull()
    }

    suspend fun updateDisplayName(userId: String, name: String) {
        client.from("profiles").update(buildJsonObject {
            put("display_name", name)
        }) { filter { eq("id", userId) } }
    }

    // MARK: - Friendships

    suspend fun sendFriendRequest(fromId: String, toId: String) {
        client.from("friendships").insert(buildJsonObject {
            put("requester_id", fromId)
            put("addressee_id", toId)
            put("status", "pending")
        })
    }

    suspend fun acceptFriendRequest(friendshipId: String) {
        client.from("friendships").update(buildJsonObject {
            put("status", "accepted")
        }) { filter { eq("id", friendshipId) } }
    }

    suspend fun fetchFriends(userId: String): List<Friend> {
        val rows = client.from("friendships").select {
            filter {
                eq("status", "accepted")
                or {
                    eq("requester_id", userId)
                    eq("addressee_id", userId)
                }
            }
        }.decodeList<Friendship>()

        return rows.mapNotNull { row ->
            val friendId = if (row.requesterId == userId) row.addresseeId else row.requesterId
            try {
                val profile = fetchProfile(friendId)
                Friend(id = row.id, user = profile)
            } catch (_: Exception) { null }
        }
    }

    suspend fun fetchPendingRequests(userId: String): List<Friendship> {
        return client.from("friendships").select {
            filter {
                eq("addressee_id", userId)
                eq("status", "pending")
            }
        }.decodeList<Friendship>()
    }

    // MARK: - Groups

    suspend fun fetchGroups(ownerId: String): List<FriendGroup> {
        return client.from("groups").select {
            filter { eq("owner_id", ownerId) }
        }.decodeList<FriendGroup>()
    }

    suspend fun createGroup(ownerId: String, name: String): FriendGroup {
        return client.from("groups").insert(buildJsonObject {
            put("owner_id", ownerId)
            put("name", name)
        }) { select() }.decodeSingle<FriendGroup>()
    }

    // MARK: - Shared Events

    suspend fun createSharedEvent(event: SharedEvent): String {
        val result = client.from("shared_events").insert(event) {
            select()
        }.decodeSingle<SharedEvent>()
        return result.id
    }

    suspend fun sendEventInvite(eventId: String, inviteeId: String, inviteeEmail: String) {
        client.from("event_invites").insert(buildJsonObject {
            put("event_id", eventId)
            put("invitee_id", inviteeId)
            put("invitee_email", inviteeEmail)
        })
    }

    suspend fun respondToInvite(inviteId: String, accept: Boolean) {
        client.from("event_invites").update(buildJsonObject {
            put("status", if (accept) "accepted" else "declined")
        }) { filter { eq("id", inviteId) } }
    }
}
